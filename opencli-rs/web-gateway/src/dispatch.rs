//! Gateway-side background runs.
//!
//! The app server drives one conversation at a time. Work that should outlive
//! the window that started it — a dispatched task, a Cowork message, a
//! scheduled digest — is run here instead, as its own `opencli exec`, and
//! recorded so it can be read back later.

use opencli_core::dispatch;
use serde_json::Value;
use serde_json::json;
use std::path::Path;
use std::path::PathBuf;
use std::time::Duration;

/// How often to look for queued work. Runs take minutes, so a tighter loop
/// would only spin.
const TICK: Duration = Duration::from_secs(2);

/// How many runs may be in flight at once when nothing says otherwise.
///
/// Each is a full agent with its own model calls; letting an impatient click
/// start twenty would exhaust a local model's memory and finish none of them.
/// Three suits a laptop running one local model. It is a poor number for a
/// workstation talking to a hosted API, which is why it can be changed.
const DEFAULT_PARALLEL: usize = 3;

/// The ceiling on that setting.
///
/// Not a matter of taste: past this, runs stop making progress and start
/// competing for the same weights. Somebody who genuinely wants more should be
/// running a second gateway, not raising a number.
const MAX_PARALLEL: usize = 16;

/// How many runs may be in flight, as configured.
///
/// Read on each tick, like the approval policy below, so changing it takes
/// effect without a restart. A missing or nonsensical value falls back rather
/// than stopping the worker — a typo in a config file should not silently
/// stop background work.
fn parallel(opencli_home: &Path) -> usize {
    settings(opencli_home)
        .get("parallel")
        .and_then(Value::as_u64)
        .map(|value| (value as usize).clamp(1, MAX_PARALLEL))
        .unwrap_or(DEFAULT_PARALLEL)
}

const SETTINGS_FILE: &str = "dispatch-settings.json";

fn settings(opencli_home: &Path) -> Value {
    std::fs::read_to_string(opencli_home.join(SETTINGS_FILE))
        .ok()
        .and_then(|text| serde_json::from_str(&text).ok())
        .unwrap_or_else(|| json!({}))
}

/// Read the setting, for showing it.
fn read_settings(opencli_home: &Path) -> Value {
    json!({
        "parallel": parallel(opencli_home),
        "max": MAX_PARALLEL,
        "default": DEFAULT_PARALLEL,
    })
}

fn write_settings(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let wanted = params
        .get("parallel")
        .and_then(Value::as_u64)
        .ok_or("parallel must be a number")?;
    if wanted < 1 || wanted as usize > MAX_PARALLEL {
        return Err(format!("parallel must be between 1 and {MAX_PARALLEL}"));
    }
    std::fs::write(
        opencli_home.join(SETTINGS_FILE),
        serde_json::to_string_pretty(&json!({ "parallel": wanted }))
            .map_err(|err| format!("could not encode: {err}"))?,
    )
    .map_err(|err| format!("could not save: {err}"))?;
    // Raising the limit should start the work that was waiting on it, and the
    // worker looks again on its next tick — so say so now rather than leaving
    // the panel showing a queue that is about to move.
    crate::notify::runs_changed(opencli_home);
    Ok(read_settings(opencli_home))
}

/// Every write to the run store goes through one of these.
///
/// Not for their own sake — they only forward — but so that changing a run
/// and telling the open windows about it cannot come apart. The previous
/// arrangement had the panel ask again every 1.5 seconds precisely because
/// nothing announced anything; adding an announcement at each of a dozen call
/// sites would have lasted until the thirteenth.
fn set_status(
    opencli_home: &Path,
    id: &str,
    status: dispatch::RunStatus,
    code: Option<i32>,
) -> std::io::Result<bool> {
    let changed = dispatch::set_status(opencli_home, id, status, code);
    crate::notify::runs_changed(opencli_home);
    changed
}

fn set_output(opencli_home: &Path, id: &str, output: &str) -> std::io::Result<bool> {
    let changed = dispatch::set_output(opencli_home, id, output);
    crate::notify::runs_changed(opencli_home);
    changed
}

fn delete_run(opencli_home: &Path, id: &str) -> std::io::Result<bool> {
    let removed = dispatch::delete(opencli_home, id);
    crate::notify::runs_changed(opencli_home);
    removed
}

fn clear_finished(opencli_home: &Path) -> std::io::Result<usize> {
    let cleared = dispatch::clear_finished(opencli_home);
    crate::notify::runs_changed(opencli_home);
    cleared
}

#[allow(clippy::too_many_arguments)]
fn create_run(
    opencli_home: &Path,
    title: String,
    prompt: String,
    cwd: String,
    model: Option<String>,
    source: dispatch::RunSource,
    task_id: Option<String>,
) -> std::io::Result<dispatch::Run> {
    let made = dispatch::create(opencli_home, title, prompt, cwd, model, source, task_id);
    crate::notify::runs_changed(opencli_home);
    made
}

/// Answer a `dispatch/*` request, or return `None` to let it pass through.
pub fn handle(raw: &str, opencli_home: &Path) -> Option<String> {
    let message: Value = serde_json::from_str(raw).ok()?;
    let method = message.get("method")?.as_str()?;
    if !method.starts_with("dispatch/") {
        return None;
    }
    let id = message.get("id").cloned().unwrap_or(Value::Null);
    let params = message.get("params").cloned().unwrap_or(json!({}));

    let result = match method {
        "dispatch/list" => list(opencli_home, &params),
        "dispatch/create" => create(opencli_home, &params),
        "dispatch/cancel" => cancel(opencli_home, &params),
        "dispatch/delete" => delete(opencli_home, &params),
        "dispatch/clear" => clear(opencli_home),
        "dispatch/allowDirectory" => allow_directory(opencli_home, &params),
        "dispatch/directories" => Ok(directories(opencli_home)),
        "dispatch/settings" => Ok(read_settings(opencli_home)),
        "dispatch/setParallel" => write_settings(opencli_home, &params),
        _ => Err(format!("unknown method `{method}`")),
    };

    Some(match result {
        Ok(value) => json!({ "id": id, "result": value }).to_string(),
        Err(message) => {
            json!({ "id": id, "error": { "code": -32602, "message": message } }).to_string()
        }
    })
}

/// Say yes to a directory, and let anything held for it run.
///
/// Re-queuing here rather than making somebody find each held run: they said
/// yes to the place, and every run waiting on that place is what they were
/// saying yes to.
fn allow_directory(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let path = params
        .get("path")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|path| !path.is_empty())
        .ok_or("path is required")?;

    opencli_core::directories::grant(opencli_home, Path::new(path))
        .map_err(|err| format!("could not save: {err}"))?;

    let mut released = 0;
    for run in dispatch::load(opencli_home) {
        if run.status == dispatch::RunStatus::NeedsApproval
            && opencli_core::directories::allowed(opencli_home, Path::new(&run.cwd))
        {
            let _ = set_status(opencli_home, &run.id, dispatch::RunStatus::Queued, None);
            released += 1;
        }
    }
    Ok(json!({ "allowed": path, "released": released }))
}

/// The directories that have been said yes to, for showing and taking back.
fn directories(opencli_home: &Path) -> Value {
    let data: Vec<Value> = opencli_core::directories::granted(opencli_home)
        .iter()
        .map(|entry| json!({ "path": entry.path, "grantedAt": entry.granted_at }))
        .collect();
    json!({ "data": data })
}

fn run_json(run: &dispatch::Run) -> Value {
    json!({
        "id": run.id,
        "title": run.title,
        "prompt": run.prompt,
        "cwd": run.cwd,
        "model": run.model,
        "source": run.source,
        "status": run.status,
        "startedAt": run.started_at,
        "finishedAt": run.finished_at,
        "output": run.output,
        "exitCode": run.exit_code,
        "taskId": run.task_id,
    })
}

/// List runs. `activeOnly` narrows to what has not finished, which is what the
/// Active list on the landing screen shows.
fn list(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let runs = dispatch::load(opencli_home);
    let filtered: Vec<&dispatch::Run> = match params.get("activeOnly").and_then(Value::as_bool) {
        Some(true) => runs
            .iter()
            .filter(|run| !run.status.is_finished())
            .collect(),
        _ => runs.iter().collect(),
    };
    let limit = params
        .get("limit")
        .and_then(Value::as_u64)
        .unwrap_or(50)
        .clamp(1, 500) as usize;
    let data: Vec<Value> = filtered.into_iter().take(limit).map(run_json).collect();
    Ok(json!({ "data": data }))
}

fn create(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let prompt = params
        .get("prompt")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|prompt| !prompt.is_empty())
        .ok_or("prompt is required")?;
    let cwd = params
        .get("cwd")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|cwd| !cwd.is_empty())
        .ok_or("cwd is required")?;
    if !Path::new(cwd).is_dir() {
        return Err(format!("`{cwd}` is not a directory"));
    }
    // A title makes the list readable; the prompt is a reasonable fallback but
    // a whole paragraph is not, so it is cut to a line.
    let title = params
        .get("title")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|title| !title.is_empty())
        .map(str::to_string)
        .unwrap_or_else(|| summarize(prompt));
    let model = params
        .get("model")
        .and_then(Value::as_str)
        .filter(|model| !model.is_empty())
        .map(str::to_string);
    let source = match params.get("source").and_then(Value::as_str) {
        Some("cowork") => dispatch::RunSource::Cowork,
        _ => dispatch::RunSource::Dispatch,
    };

    let run = create_run(
        opencli_home,
        title,
        prompt.to_string(),
        cwd.to_string(),
        model,
        source,
        None,
    )
    .map_err(|err| format!("could not record the run: {err}"))?;
    Ok(run_json(&run))
}

/// One readable line for a list.
fn summarize(prompt: &str) -> String {
    let line: String = prompt.split_whitespace().collect::<Vec<_>>().join(" ");
    if line.chars().count() <= 60 {
        return line;
    }
    let cut: String = line.chars().take(60).collect();
    format!("{cut}…")
}

fn required_id(params: &Value) -> Result<&str, String> {
    params
        .get("id")
        .and_then(Value::as_str)
        .ok_or_else(|| "id is required".to_string())
}

/// Mark a run cancelled.
///
/// The process is not killed: `opencli exec` may be mid-write, and stopping it
/// there could leave a half-applied edit. Cancelling stops it being *started*
/// and marks it so the user knows it will not be waited on.
fn cancel(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let id = required_id(params)?;
    let found = set_status(opencli_home, id, dispatch::RunStatus::Cancelled, None)
        .map_err(|err| format!("could not save: {err}"))?;
    if !found {
        return Err(format!("no run with id `{id}`"));
    }
    Ok(json!({}))
}

fn delete(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let id = required_id(params)?;
    let removed =
        delete_run(opencli_home, id).map_err(|err| format!("could not save: {err}"))?;
    if !removed {
        return Err("that run is still going; cancel it first".to_string());
    }
    Ok(json!({}))
}

fn clear(opencli_home: &Path) -> Result<Value, String> {
    let cleared =
        clear_finished(opencli_home).map_err(|err| format!("could not save: {err}"))?;
    Ok(json!({ "cleared": cleared }))
}

/// Run queued work forever, a few at a time.
/// What the person asked to be stopped for.
///
/// Read from the file on every tick rather than held, so turning approvals off
/// takes effect on the next run instead of on the next restart — which is what
/// somebody who has just changed it is expecting.
fn approval_policy(opencli_home: &Path) -> opencli_core::protocol::AskForApproval {
    std::fs::read_to_string(opencli_home.join("config.toml"))
        .ok()
        .and_then(|text| toml::from_str::<opencli_core::config::ConfigToml>(&text).ok())
        .and_then(|parsed| parsed.approval_policy)
        .unwrap_or_default()
}

pub async fn run_worker(opencli_home: PathBuf, opencli_bin: PathBuf) {
    loop {
        tokio::time::sleep(TICK).await;

        let runs = dispatch::load(&opencli_home);
        let in_flight = runs
            .iter()
            .filter(|run| run.status == dispatch::RunStatus::Running)
            .count();
        let limit = parallel(&opencli_home);
        if in_flight >= limit {
            continue;
        }

        for run in dispatch::queued(&opencli_home)
            .into_iter()
            .take(limit - in_flight)
        {
            // Where it would run, before it runs.
            //
            // The sandbox's writable root is this directory, so one outside
            // everything this product knows about is a request to write
            // anywhere in it. A scheduled task made before departments existed
            // carried the home directory and had run forty-two times that way,
            // each run able to reach `.ssh` and `Documents`, with nobody asked.
            // Held rather than failed: running somewhere unusual is often what
            // was meant, and the answer is a prompt.
            if opencli_core::directories::must_ask(
                &opencli_home,
                std::path::Path::new(&run.cwd),
                approval_policy(&opencli_home),
            ) {
                let _ = set_output(
                    &opencli_home,
                    &run.id,
                    &format!(
                        "This would run in `{}`, which is not a department's directory or \
                         anywhere you have allowed. Allow that directory to let it run.",
                        run.cwd
                    ),
                );
                let _ = set_status(
                    &opencli_home,
                    &run.id,
                    dispatch::RunStatus::NeedsApproval,
                    None,
                );
                continue;
            }

            // Claim it before spawning: two ticks must not start the same run.
            match set_status(&opencli_home, &run.id, dispatch::RunStatus::Running, None) {
                Ok(true) => {}
                Ok(false) => continue,
                Err(err) => {
                    tracing::error!("could not claim run `{}`: {err}", run.title);
                    continue;
                }
            }
            let home = opencli_home.clone();
            let bin = opencli_bin.clone();
            tokio::spawn(async move { execute(home, bin, run).await });
        }
    }
}

/// Read one of the child's pipes line by line into the channel.
///
/// Both pipes feed the same channel, so the output reads in the order it was
/// produced rather than as two separate blocks.
fn pump<R>(stream: R, tx: tokio::sync::mpsc::UnboundedSender<String>)
where
    R: tokio::io::AsyncRead + Unpin + Send + 'static,
{
    tokio::spawn(async move {
        use tokio::io::AsyncBufReadExt;
        let mut lines = tokio::io::BufReader::new(stream).lines();
        while let Ok(Some(line)) = lines.next_line().await {
            if tx.send(line).is_err() {
                break;
            }
        }
    });
}

/// How often a running task's output is written down.
const WRITE_EVERY: std::time::Duration = std::time::Duration::from_millis(700);

/// Run one dispatched task to completion and record what it did.
async fn execute(opencli_home: PathBuf, opencli_bin: PathBuf, run: dispatch::Run) {
    tracing::info!("running dispatched task `{}`", run.title);

    let mut command = tokio::process::Command::new(&opencli_bin);
    command
        .arg("exec")
        .arg("--skip-git-repo-check")
        // Read-only would defeat the point of most background work, and nobody
        // is watching to approve anything. Scope writes to the run's own
        // directory rather than granting full access.
        .arg("--sandbox")
        .arg("workspace-write");
    if let Some(model) = &run.model {
        command.arg("-m").arg(model);
    }
    // What this run is part of, told to the process rather than to the model.
    //
    // Everything a bot can set off from inside a run is decided from these:
    // which duty it may write notes against, who it is handing work on as, and
    // how far the chain it is in has already gone. A model that could name any
    // of them could write into another department's duty, hand work on as
    // somebody else, or start a fresh chain on every hop and never reach the
    // cap. A run that is none of these things sets nothing, and the tools are
    // not offered at all.
    if let Some(task) = &run.task_id {
        if let Some(duty) = opencli_core::duties::get(&opencli_home, task) {
            command.env(opencli_core::duties::DUTY_ENV, task);
            command.env(opencli_core::bots::BOT_ENV, &duty.bot);
        } else if let Some(handoff) = opencli_core::handoffs::load(&opencli_home)
            .into_iter()
            .find(|handoff| &handoff.id == task)
        {
            command.env(opencli_core::bots::BOT_ENV, &handoff.to_bot);
            command.env(opencli_core::handoffs::CHAIN_ENV, &handoff.chain);
            command.env(opencli_core::handoffs::HOP_ENV, handoff.hop.to_string());
        }
    }

    command.arg(&run.prompt).current_dir(&run.cwd);

    // Piped and read as it arrives, rather than collected at the end. A run
    // that takes ten minutes used to show nothing at all until it finished —
    // which is the whole of what someone watching it wants to know.
    command
        .stdin(std::process::Stdio::null())
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped());

    let mut child = match command.spawn() {
        Ok(child) => child,
        Err(err) => {
            let text = format!("could not start the agent: {err}");
            let _ = set_output(&opencli_home, &run.id, &text);
            let _ = set_status(&opencli_home, &run.id, dispatch::RunStatus::Failed, None);
            return;
        }
    };

    let (chunks_tx, mut chunks_rx) = tokio::sync::mpsc::unbounded_channel::<String>();
    if let Some(out) = child.stdout.take() {
        pump(out, chunks_tx.clone());
    }
    if let Some(err) = child.stderr.take() {
        pump(err, chunks_tx.clone());
    }
    // Both readers hold a clone; this one has to go or the loop below never
    // sees the channel close.
    drop(chunks_tx);

    let mut text = String::new();
    let mut unsaved = false;
    let mut last_save = std::time::Instant::now();
    loop {
        let chunk = tokio::time::timeout(WRITE_EVERY, chunks_rx.recv()).await;
        match chunk {
            Ok(Some(line)) => {
                text.push_str(&line);
                text.push('\n');
                unsaved = true;
            }
            // The pipes are closed: the process has finished writing.
            Ok(None) => break,
            Err(_) => {}
        }
        // Written at a bounded rate rather than per line: the store is a file,
        // and a chatty run would otherwise rewrite it hundreds of times a
        // second for the sake of a reader who polls every few seconds.
        if unsaved && last_save.elapsed() >= WRITE_EVERY {
            let _ = set_output(&opencli_home, &run.id, &text);
            unsaved = false;
            last_save = std::time::Instant::now();
        }
    }

    let finished = child.wait().await;
    let (status, code) = match finished {
        Ok(exit) if exit.success() => (dispatch::RunStatus::Done, exit.code()),
        Ok(exit) => (dispatch::RunStatus::Failed, exit.code()),
        Err(err) => {
            text.push_str(&format!("\nthe agent could not be waited on: {err}\n"));
            (dispatch::RunStatus::Failed, None)
        }
    };
    let output = text;

    if let Err(err) = set_output(&opencli_home, &run.id, &output) {
        tracing::error!("could not record output for `{}`: {err}", run.title);
    }
    if let Err(err) = set_status(&opencli_home, &run.id, status, code) {
        tracing::error!("could not record status for `{}`: {err}", run.title);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    fn call(raw: &str, home: &Path) -> Value {
        let reply = handle(raw, home).expect("dispatch methods are handled locally");
        serde_json::from_str(&reply).expect("valid JSON reply")
    }

    fn create_one(home: &Path) -> String {
        let created = call(
            r#"{"method":"dispatch/create","id":1,"params":
                {"prompt":"summarise the repo","cwd":"/tmp"}}"#,
            home,
        );
        created["result"]["id"].as_str().expect("id").to_string()
    }

    #[test]
    fn should_pass_non_dispatch_methods_through_to_the_agent() {
        let dir = tempdir().expect("tempdir");
        assert!(handle(r#"{"method":"turn/start","id":1}"#, dir.path()).is_none());
        assert!(handle("not json", dir.path()).is_none());
    }

    #[test]
    fn should_create_then_list_a_run() {
        let dir = tempdir().expect("tempdir");
        create_one(dir.path());

        let listed = call(r#"{"method":"dispatch/list","id":2}"#, dir.path());
        let rows = listed["result"]["data"].as_array().expect("data");
        assert_eq!(rows.len(), 1);
        assert_eq!(rows[0]["status"], "queued");
        assert_eq!(rows[0]["source"], "dispatch");
    }

    #[test]
    fn should_title_a_run_from_its_prompt_when_none_was_given() {
        let dir = tempdir().expect("tempdir");
        create_one(dir.path());
        let listed = call(r#"{"method":"dispatch/list","id":2}"#, dir.path());
        assert_eq!(listed["result"]["data"][0]["title"], "summarise the repo");
    }

    #[test]
    fn should_cut_a_long_prompt_down_to_one_readable_line() {
        // A whole paragraph as a list row is unreadable.
        let long = "word ".repeat(40);
        let summary = summarize(&long);
        assert!(
            summary.chars().count() <= 61,
            "got {} chars",
            summary.chars().count()
        );
        assert!(summary.ends_with('…'));
    }

    #[test]
    fn should_refuse_a_run_with_nowhere_to_run() {
        let dir = tempdir().expect("tempdir");
        let reply = call(
            r#"{"method":"dispatch/create","id":1,"params":{"prompt":"go","cwd":"/no/such"}}"#,
            dir.path(),
        );
        assert!(
            reply["error"]["message"]
                .as_str()
                .is_some_and(|message| message.contains("not a directory"))
        );
    }

    #[test]
    fn should_refuse_a_run_with_no_prompt() {
        let dir = tempdir().expect("tempdir");
        let reply = call(
            r#"{"method":"dispatch/create","id":1,"params":{"cwd":"/tmp","prompt":"   "}}"#,
            dir.path(),
        );
        assert!(reply["error"].is_object());
    }

    #[test]
    fn should_list_only_unfinished_runs_when_asked_for_active() {
        let dir = tempdir().expect("tempdir");
        let id = create_one(dir.path());
        create_one(dir.path());
        dispatch::set_status(dir.path(), &id, dispatch::RunStatus::Done, Some(0)).expect("status");

        let active = call(
            r#"{"method":"dispatch/list","id":2,"params":{"activeOnly":true}}"#,
            dir.path(),
        );
        assert_eq!(active["result"]["data"].as_array().map(Vec::len), Some(1));
    }

    #[test]
    fn should_cancel_a_run_rather_than_deleting_it_mid_flight() {
        // Deleting a running task would leave a process nobody can see.
        let dir = tempdir().expect("tempdir");
        let id = create_one(dir.path());
        dispatch::set_status(dir.path(), &id, dispatch::RunStatus::Running, None).expect("status");

        let refused = call(
            &format!(r#"{{"method":"dispatch/delete","id":2,"params":{{"id":"{id}"}}}}"#),
            dir.path(),
        );
        assert!(refused["error"].is_object());

        let cancelled = call(
            &format!(r#"{{"method":"dispatch/cancel","id":3,"params":{{"id":"{id}"}}}}"#),
            dir.path(),
        );
        assert!(cancelled["result"].is_object());
        assert_eq!(
            call(r#"{"method":"dispatch/list","id":4}"#, dir.path())["result"]["data"][0]["status"],
            "cancelled"
        );
    }

    #[test]
    fn should_clear_finished_runs_and_report_how_many() {
        let dir = tempdir().expect("tempdir");
        let id = create_one(dir.path());
        create_one(dir.path());
        dispatch::set_status(dir.path(), &id, dispatch::RunStatus::Done, Some(0)).expect("status");

        let cleared = call(r#"{"method":"dispatch/clear","id":2}"#, dir.path());
        assert_eq!(cleared["result"]["cleared"], 1);
        assert_eq!(
            call(r#"{"method":"dispatch/list","id":3}"#, dir.path())["result"]["data"]
                .as_array()
                .map(Vec::len),
            Some(1)
        );
    }

    #[test]
    fn should_record_a_cowork_message_as_its_own_source() {
        // Cowork and Dispatch share the machinery but not the meaning; a list
        // that could not tell them apart would be confusing to read.
        let dir = tempdir().expect("tempdir");
        call(
            r#"{"method":"dispatch/create","id":1,"params":
                {"prompt":"go","cwd":"/tmp","source":"cowork"}}"#,
            dir.path(),
        );
        let listed = call(r#"{"method":"dispatch/list","id":2}"#, dir.path());
        assert_eq!(listed["result"]["data"][0]["source"], "cowork");
    }

    #[test]
    fn should_let_a_directory_be_allowed_and_release_what_was_waiting_on_it() {
        let dir = tempdir().expect("tempdir");
        let elsewhere = dir.path().join("elsewhere");
        std::fs::create_dir_all(&elsewhere).expect("mkdir");

        let made = opencli_core::dispatch::create(
            dir.path(),
            "somewhere else".to_string(),
            "do a thing".to_string(),
            elsewhere.to_string_lossy().into_owned(),
            None,
            opencli_core::dispatch::RunSource::Dispatch,
            None,
        )
        .expect("create");
        opencli_core::dispatch::set_status(
            dir.path(),
            &made.id,
            opencli_core::dispatch::RunStatus::NeedsApproval,
            None,
        )
        .expect("hold");

        let allowed = call(
            &format!(
                r#"{{"method":"dispatch/allowDirectory","id":1,"params":{{"path":"{}"}}}}"#,
                elsewhere.to_string_lossy()
            ),
            dir.path(),
        );
        // Saying yes to the place is saying yes to what was waiting on it;
        // making somebody find each held run would be asking twice.
        assert_eq!(allowed["result"]["released"], 1);

        let listed = call(r#"{"method":"dispatch/list","id":2}"#, dir.path());
        assert_eq!(listed["result"]["data"][0]["status"], "queued");
    }

    #[test]
    fn should_report_the_directories_that_were_allowed() {
        let dir = tempdir().expect("tempdir");
        let elsewhere = dir.path().join("elsewhere");
        std::fs::create_dir_all(&elsewhere).expect("mkdir");
        call(
            &format!(
                r#"{{"method":"dispatch/allowDirectory","id":1,"params":{{"path":"{}"}}}}"#,
                elsewhere.to_string_lossy()
            ),
            dir.path(),
        );

        let listed = call(r#"{"method":"dispatch/directories","id":2}"#, dir.path());
        let rows = listed["result"]["data"].as_array().expect("data");
        assert_eq!(rows.len(), 1);
        assert!(
            rows[0]["path"]
                .as_str()
                .is_some_and(|p| p.ends_with("elsewhere"))
        );
    }

    #[test]
    fn should_refuse_to_allow_nothing() {
        let dir = tempdir().expect("tempdir");
        let reply = call(
            r#"{"method":"dispatch/allowDirectory","id":1,"params":{}}"#,
            dir.path(),
        );
        assert!(
            reply["error"]["message"]
                .as_str()
                .is_some_and(|m| m.contains("path"))
        );
    }
}
