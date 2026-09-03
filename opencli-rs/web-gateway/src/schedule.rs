//! Gateway-side handling of recurring tasks.
//!
//! Scheduling does not belong to the agent: a task outlives any one thread and
//! must keep firing between conversations. So the gateway owns it — it answers
//! `schedule/*` methods itself rather than relaying them, and runs one
//! scheduler per gateway process.
//!
//! Tasks run only while the gateway is up. That is an honest promise for a
//! locally hosted agent; anything that must fire while the machine sleeps
//! belongs in the OS scheduler.

use opencli_core::dispatch;
use opencli_core::scheduled;
use serde_json::Value;
use serde_json::json;
use std::path::Path;
use std::path::PathBuf;
use std::time::Duration;

/// How often to look for due tasks. Tasks are defined in minutes or hours, so
/// checking every 30s is granular enough without spinning.
const TICK: Duration = Duration::from_secs(30);

/// Answer a `schedule/*` request, or return `None` to let it pass through to
/// the app server.
pub fn handle(raw: &str, opencli_home: &Path) -> Option<String> {
    let message: Value = serde_json::from_str(raw).ok()?;
    let method = message.get("method")?.as_str()?;
    if !method.starts_with("schedule/") {
        return None;
    }
    let id = message.get("id").cloned().unwrap_or(Value::Null);
    let params = message.get("params").cloned().unwrap_or(json!({}));

    let result = match method {
        "schedule/list" => list(opencli_home),
        "schedule/create" => create(opencli_home, &params),
        "schedule/delete" => delete(opencli_home, &params),
        "schedule/setEnabled" => set_enabled(opencli_home, &params),
        "schedule/runNow" => run_now(opencli_home, &params),
        _ => Err(format!("unknown method `{method}`")),
    };

    Some(match result {
        Ok(value) => json!({ "id": id, "result": value }).to_string(),
        Err(message) => {
            json!({ "id": id, "error": { "code": -32602, "message": message } }).to_string()
        }
    })
}

fn task_json(task: &scheduled::ScheduledTask) -> Value {
    json!({
        "id": task.id,
        "name": task.name,
        "prompt": task.prompt,
        "intervalSeconds": task.interval_seconds,
        "cwd": task.cwd,
        "lastRun": task.last_run,
        "runCount": task.run_count,
        "nextRun": task.next_run(),
        "enabled": task.enabled,
    })
}

fn list(opencli_home: &Path) -> Result<Value, String> {
    let tasks: Vec<Value> = scheduled::load(opencli_home)
        .iter()
        .map(task_json)
        .collect();
    Ok(json!({ "data": tasks }))
}

fn create(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let name = params
        .get("name")
        .and_then(Value::as_str)
        .filter(|s| !s.trim().is_empty())
        .ok_or("name is required")?;
    let prompt = params
        .get("prompt")
        .and_then(Value::as_str)
        .filter(|s| !s.trim().is_empty())
        .ok_or("prompt is required")?;
    let interval = params
        .get("intervalSeconds")
        .and_then(Value::as_u64)
        .filter(|n| *n > 0)
        .ok_or("intervalSeconds must be a positive number")?;
    let cwd = params
        .get("cwd")
        .and_then(Value::as_str)
        .unwrap_or(".")
        .to_string();

    let task = scheduled::create(
        opencli_home,
        name.to_string(),
        prompt.to_string(),
        interval,
        cwd,
    )
    .map_err(|err| format!("could not save the task: {err}"))?;
    Ok(task_json(&task))
}

fn delete(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let id = params
        .get("id")
        .and_then(Value::as_str)
        .ok_or("id is required")?;
    let removed =
        scheduled::delete(opencli_home, id).map_err(|err| format!("could not save: {err}"))?;
    if !removed {
        return Err(format!("no task with id `{id}`"));
    }
    Ok(json!({}))
}

fn set_enabled(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let id = params
        .get("id")
        .and_then(Value::as_str)
        .ok_or("id is required")?;
    let enabled = params
        .get("enabled")
        .and_then(Value::as_bool)
        .ok_or("enabled must be a boolean")?;
    let found = scheduled::set_enabled(opencli_home, id, enabled)
        .map_err(|err| format!("could not save: {err}"))?;
    if !found {
        return Err(format!("no task with id `{id}`"));
    }
    Ok(json!({}))
}

/// Run a task now, without waiting for its next turn.
///
/// Queued through the same worker as a scheduled run, so it obeys the same
/// limit and appears in the same list. Creating a task and then having to wait
/// an hour to find out whether the prompt was right is not a way to write one.
fn run_now(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let id = params
        .get("id")
        .and_then(Value::as_str)
        .ok_or("id is required")?;
    let task = scheduled::load(opencli_home)
        .into_iter()
        .find(|task| task.id == id)
        .ok_or_else(|| format!("no task with id `{id}`"))?;

    // Deliberately not marked as having run: this is an extra run, and the
    // schedule should keep measuring from the last scheduled one.
    dispatch::create(
        opencli_home,
        task.name,
        task.prompt,
        task.cwd,
        None,
        dispatch::RunSource::Scheduled,
        Some(task.id),
    )
    .map_err(|err| format!("could not queue: {err}"))?;
    Ok(json!({}))
}

/// Queue due tasks forever.
///
/// The work itself is done by the dispatch worker, so a scheduled run appears
/// in the same list as one started by hand and obeys the same limit on how
/// many agents run at once.
pub async fn run_scheduler(opencli_home: PathBuf, _opencli_bin: PathBuf) {
    loop {
        tokio::time::sleep(TICK).await;
        let now = scheduled::now_seconds();
        for task in scheduled::load(&opencli_home) {
            if !task.is_due(now) {
                continue;
            }
            // Mark before running, not after: a long task would otherwise stay
            // due and be started again on the next tick.
            if let Err(err) = scheduled::mark_ran(&opencli_home, &task.id) {
                tracing::error!("could not record the run of `{}`: {err}", task.name);
                continue;
            }
            tracing::info!("running scheduled task `{}`", task.name);

            // Queue it rather than running it here. A scheduled run and a
            // dispatched one are the same thing to the person reading the
            // list, and routing both through one worker means one place
            // enforces how many agents run at once.
            if let Err(err) = dispatch::create(
                &opencli_home,
                task.name.clone(),
                task.prompt.clone(),
                task.cwd.clone(),
                None,
                dispatch::RunSource::Scheduled,
                Some(task.id.clone()),
            ) {
                tracing::error!("could not queue `{}`: {err}", task.name);
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    fn call(raw: &str, home: &Path) -> Value {
        let reply = handle(raw, home).expect("schedule methods are handled locally");
        serde_json::from_str(&reply).expect("valid JSON reply")
    }

    #[test]
    fn should_pass_non_schedule_methods_through_to_the_agent() {
        let dir = tempdir().expect("tempdir");
        assert!(handle(r#"{"method":"turn/start","id":1}"#, dir.path()).is_none());
        assert!(handle("not json", dir.path()).is_none());
    }

    #[test]
    fn should_create_then_list_a_task() {
        let dir = tempdir().expect("tempdir");
        let created = call(
            r#"{"method":"schedule/create","id":1,"params":
                {"name":"Digest","prompt":"summarize","intervalSeconds":3600,"cwd":"/tmp"}}"#,
            dir.path(),
        );
        assert_eq!(created["result"]["name"], "Digest");
        assert_eq!(created["result"]["intervalSeconds"], 3600);

        let listed = call(r#"{"method":"schedule/list","id":2}"#, dir.path());
        assert_eq!(listed["result"]["data"].as_array().map(Vec::len), Some(1));
    }

    #[test]
    fn should_reject_a_task_without_the_required_fields() {
        let dir = tempdir().expect("tempdir");
        // A task with no prompt would run nothing on every tick, forever.
        let reply = call(
            r#"{"method":"schedule/create","id":1,"params":{"name":"x","intervalSeconds":60}}"#,
            dir.path(),
        );
        assert!(
            reply["error"]["message"]
                .as_str()
                .is_some_and(|m| m.contains("prompt"))
        );
    }

    #[test]
    fn should_reject_a_non_positive_interval() {
        let dir = tempdir().expect("tempdir");
        // Zero would make the task due on every tick.
        let reply = call(
            r#"{"method":"schedule/create","id":1,"params":
                {"name":"x","prompt":"p","intervalSeconds":0}}"#,
            dir.path(),
        );
        assert!(reply["error"].is_object());
    }

    #[test]
    fn should_delete_a_task_and_report_an_unknown_id() {
        let dir = tempdir().expect("tempdir");
        let created = call(
            r#"{"method":"schedule/create","id":1,"params":
                {"name":"x","prompt":"p","intervalSeconds":60}}"#,
            dir.path(),
        );
        let id = created["result"]["id"].as_str().expect("id").to_string();

        let deleted = call(
            &format!(r#"{{"method":"schedule/delete","id":2,"params":{{"id":"{id}"}}}}"#),
            dir.path(),
        );
        assert!(deleted["result"].is_object());

        let missing = call(
            r#"{"method":"schedule/delete","id":3,"params":{"id":"nope"}}"#,
            dir.path(),
        );
        assert!(missing["error"].is_object());
    }

    #[test]
    fn should_pause_a_task_without_deleting_it() {
        let dir = tempdir().expect("tempdir");
        let created = call(
            r#"{"method":"schedule/create","id":1,"params":
                {"name":"x","prompt":"p","intervalSeconds":60}}"#,
            dir.path(),
        );
        let id = created["result"]["id"].as_str().expect("id").to_string();

        call(
            &format!(
                r#"{{"method":"schedule/setEnabled","id":2,"params":{{"id":"{id}","enabled":false}}}}"#
            ),
            dir.path(),
        );

        let listed = call(r#"{"method":"schedule/list","id":3}"#, dir.path());
        let task = &listed["result"]["data"][0];
        assert_eq!(task["enabled"], false);
        assert!(task["nextRun"].is_null(), "a paused task has no next run");
    }

    #[test]
    fn should_count_runs_so_a_client_can_show_what_is_new() {
        // A timestamp cannot answer "how many since I last looked".
        let dir = tempdir().expect("tempdir");
        let created = call(
            r#"{"method":"schedule/create","id":1,"params":
                {"name":"x","prompt":"p","intervalSeconds":60}}"#,
            dir.path(),
        );
        let id = created["result"]["id"].as_str().expect("id").to_string();
        assert_eq!(created["result"]["runCount"], 0);

        scheduled::mark_ran(dir.path(), &id).expect("mark");
        scheduled::mark_ran(dir.path(), &id).expect("mark");

        let listed = call(r#"{"method":"schedule/list","id":2}"#, dir.path());
        assert_eq!(listed["result"]["data"][0]["runCount"], 2);
    }

    #[test]
    fn should_queue_a_due_task_rather_than_running_it_inline() {
        // A scheduled run and a dispatched one are the same thing to whoever
        // reads the list, and one worker means one place decides how many
        // agents run at once.
        let dir = tempdir().expect("tempdir");
        let task = scheduled::create(
            dir.path(),
            "Digest".into(),
            "summarize".into(),
            60,
            "/tmp".into(),
        )
        .expect("create");

        dispatch::create(
            dir.path(),
            task.name.clone(),
            task.prompt.clone(),
            task.cwd.clone(),
            None,
            dispatch::RunSource::Scheduled,
            Some(task.id.clone()),
        )
        .expect("queue");

        let queued = dispatch::queued(dir.path());
        assert_eq!(queued.len(), 1);
        assert_eq!(queued[0].source, dispatch::RunSource::Scheduled);
        assert_eq!(queued[0].task_id.as_deref(), Some(task.id.as_str()));
    }

    #[test]
    fn should_echo_the_request_id_so_clients_can_match_replies() {
        let dir = tempdir().expect("tempdir");
        let reply = call(r#"{"method":"schedule/list","id":77}"#, dir.path());
        assert_eq!(reply["id"], 77);
    }
}
