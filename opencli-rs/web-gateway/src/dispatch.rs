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

/// How many runs may be in flight at once.
///
/// Each is a full agent with its own model calls; letting an impatient click
/// start twenty would exhaust a local model's memory and finish none of them.
const MAX_PARALLEL: usize = 3;

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
        _ => Err(format!("unknown method `{method}`")),
    };

    Some(match result {
        Ok(value) => json!({ "id": id, "result": value }).to_string(),
        Err(message) => {
            json!({ "id": id, "error": { "code": -32602, "message": message } }).to_string()
        }
    })
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

    let run = dispatch::create(
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
    let found = dispatch::set_status(opencli_home, id, dispatch::RunStatus::Cancelled, None)
        .map_err(|err| format!("could not save: {err}"))?;
    if !found {
        return Err(format!("no run with id `{id}`"));
    }
    Ok(json!({}))
}

fn delete(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let id = required_id(params)?;
    let removed =
        dispatch::delete(opencli_home, id).map_err(|err| format!("could not save: {err}"))?;
    if !removed {
        return Err("that run is still going; cancel it first".to_string());
    }
    Ok(json!({}))
}

fn clear(opencli_home: &Path) -> Result<Value, String> {
    let cleared =
        dispatch::clear_finished(opencli_home).map_err(|err| format!("could not save: {err}"))?;
    Ok(json!({ "cleared": cleared }))
}

/// Run queued work forever, a few at a time.
pub async fn run_worker(opencli_home: PathBuf, opencli_bin: PathBuf) {
    loop {
        tokio::time::sleep(TICK).await;

        let runs = dispatch::load(&opencli_home);
        let in_flight = runs
            .iter()
            .filter(|run| run.status == dispatch::RunStatus::Running)
            .count();
        if in_flight >= MAX_PARALLEL {
            continue;
        }

        for run in dispatch::queued(&opencli_home)
            .into_iter()
            .take(MAX_PARALLEL - in_flight)
        {
            // Claim it before spawning: two ticks must not start the same run.
            match dispatch::set_status(&opencli_home, &run.id, dispatch::RunStatus::Running, None) {
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
    // Which duty this is, told to the process rather than to the model.
    //
    // The duty tools read it from here, so an invented or mistyped id cannot
    // write notes into another department's duty. A run that is not a duty —
    // a dispatch, or a plain scheduled task — sets nothing, and the tools are
    // not offered at all.
    if let Some(task) = &run.task_id
        && opencli_core::duties::get(&opencli_home, task).is_some()
    {
        command.env(opencli_core::duties::DUTY_ENV, task);
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
            let _ = dispatch::set_output(&opencli_home, &run.id, &text);
            let _ = dispatch::set_status(&opencli_home, &run.id, dispatch::RunStatus::Failed, None);
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
            let _ = dispatch::set_output(&opencli_home, &run.id, &text);
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

    if let Err(err) = dispatch::set_output(&opencli_home, &run.id, &output) {
        tracing::error!("could not record output for `{}`: {err}", run.title);
    }
    if let Err(err) = dispatch::set_status(&opencli_home, &run.id, status, code) {
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
}
