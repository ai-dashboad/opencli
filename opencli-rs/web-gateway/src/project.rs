//! Gateway-side handling of projects.
//!
//! Like scheduling, a project outlives any one thread, so the gateway answers
//! `project/*` itself rather than relaying to the app server, which is scoped
//! to a single conversation.

use opencli_core::projects;
use serde_json::Value;
use serde_json::json;
use std::path::Path;

/// Answer a `project/*` request, or return `None` to let it pass through to
/// the app server.
pub fn handle(raw: &str, opencli_home: &Path) -> Option<String> {
    let message: Value = serde_json::from_str(raw).ok()?;
    let method = message.get("method")?.as_str()?;
    if !method.starts_with("project/") {
        return None;
    }
    let id = message.get("id").cloned().unwrap_or(Value::Null);
    let params = message.get("params").cloned().unwrap_or(json!({}));

    let result = match method {
        "project/list" => list(opencli_home),
        "project/create" => create(opencli_home, &params),
        "project/update" => update(opencli_home, &params),
        "project/delete" => delete(opencli_home, &params),
        "project/attachThread" => attach_thread(opencli_home, &params),
        _ => Err(format!("unknown method `{method}`")),
    };

    Some(match result {
        Ok(value) => json!({ "id": id, "result": value }).to_string(),
        Err(message) => {
            json!({ "id": id, "error": { "code": -32602, "message": message } }).to_string()
        }
    })
}

fn project_json(project: &projects::Project) -> Value {
    json!({
        "id": project.id,
        "name": project.name,
        "cwd": project.cwd,
        "instructions": project.instructions,
        "createdAt": project.created_at,
        "threadIds": project.thread_ids,
    })
}

fn required_id(params: &Value) -> Result<&str, String> {
    params
        .get("id")
        .and_then(Value::as_str)
        .ok_or_else(|| "id is required".to_string())
}

/// Read an optional string field, treating an explicit `null` as "not supplied"
/// so a client can omit fields it is not editing.
fn optional_text(params: &Value, key: &str) -> Option<String> {
    params.get(key).and_then(Value::as_str).map(str::to_string)
}

fn list(opencli_home: &Path) -> Result<Value, String> {
    let projects: Vec<Value> = projects::load(opencli_home)
        .iter()
        .map(project_json)
        .collect();
    Ok(json!({ "data": projects }))
}

fn create(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let name = params
        .get("name")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|name| !name.is_empty())
        .ok_or("name is required")?;
    // A project without a directory would silently run in the gateway's own
    // working directory, which is never what the user meant.
    let cwd = params
        .get("cwd")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|cwd| !cwd.is_empty())
        .ok_or("cwd is required")?;
    let instructions = optional_text(params, "instructions").unwrap_or_default();

    let project = projects::create(
        opencli_home,
        name.to_string(),
        cwd.to_string(),
        instructions,
    )
    .map_err(|err| format!("could not save the project: {err}"))?;
    Ok(project_json(&project))
}

fn update(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let id = required_id(params)?;
    let updated = projects::update(
        opencli_home,
        id,
        optional_text(params, "name"),
        optional_text(params, "cwd"),
        optional_text(params, "instructions"),
    )
    .map_err(|err| format!("could not save: {err}"))?;
    match updated {
        Some(project) => Ok(project_json(&project)),
        None => Err(format!("no project with id `{id}`")),
    }
}

fn delete(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let id = required_id(params)?;
    let removed =
        projects::delete(opencli_home, id).map_err(|err| format!("could not save: {err}"))?;
    if !removed {
        return Err(format!("no project with id `{id}`"));
    }
    Ok(json!({}))
}

fn attach_thread(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let id = required_id(params)?;
    let thread_id = params
        .get("threadId")
        .and_then(Value::as_str)
        .ok_or("threadId is required")?;
    let found = projects::attach_thread(opencli_home, id, thread_id)
        .map_err(|err| format!("could not save: {err}"))?;
    if !found {
        return Err(format!("no project with id `{id}`"));
    }
    Ok(json!({}))
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    fn call(raw: &str, home: &Path) -> Value {
        let reply = handle(raw, home).expect("project methods are handled locally");
        serde_json::from_str(&reply).expect("valid JSON reply")
    }

    fn create_one(home: &Path) -> String {
        let created = call(
            r#"{"method":"project/create","id":1,"params":
                {"name":"Site","cwd":"/srv/site","instructions":"be careful"}}"#,
            home,
        );
        created["result"]["id"].as_str().expect("id").to_string()
    }

    #[test]
    fn should_pass_non_project_methods_through_to_the_agent() {
        let dir = tempdir().expect("tempdir");
        assert!(handle(r#"{"method":"turn/start","id":1}"#, dir.path()).is_none());
        assert!(handle("not json", dir.path()).is_none());
    }

    #[test]
    fn should_create_then_list_a_project() {
        let dir = tempdir().expect("tempdir");
        create_one(dir.path());

        let listed = call(r#"{"method":"project/list","id":2}"#, dir.path());
        let rows = listed["result"]["data"].as_array().expect("data");
        assert_eq!(rows.len(), 1);
        assert_eq!(rows[0]["name"], "Site");
        assert_eq!(rows[0]["cwd"], "/srv/site");
        assert_eq!(rows[0]["instructions"], "be careful");
    }

    #[test]
    fn should_reject_a_project_without_a_directory() {
        let dir = tempdir().expect("tempdir");
        // Without a cwd the project's threads would run wherever the gateway
        // happens to have been started.
        let reply = call(
            r#"{"method":"project/create","id":1,"params":{"name":"x"}}"#,
            dir.path(),
        );
        assert!(reply["error"]["message"]
            .as_str()
            .is_some_and(|message| message.contains("cwd")));
    }

    #[test]
    fn should_edit_one_field_without_clearing_the_others() {
        let dir = tempdir().expect("tempdir");
        let id = create_one(dir.path());

        let updated = call(
            &format!(
                r#"{{"method":"project/update","id":2,"params":{{"id":"{id}","name":"Renamed"}}}}"#
            ),
            dir.path(),
        );
        assert_eq!(updated["result"]["name"], "Renamed");
        assert_eq!(updated["result"]["instructions"], "be careful");
    }

    #[test]
    fn should_attach_a_thread_and_report_it_in_the_list() {
        let dir = tempdir().expect("tempdir");
        let id = create_one(dir.path());

        call(
            &format!(
                r#"{{"method":"project/attachThread","id":2,"params":{{"id":"{id}","threadId":"t1"}}}}"#
            ),
            dir.path(),
        );

        let listed = call(r#"{"method":"project/list","id":3}"#, dir.path());
        assert_eq!(listed["result"]["data"][0]["threadIds"][0], "t1");
    }

    #[test]
    fn should_report_an_unknown_id_as_an_error() {
        let dir = tempdir().expect("tempdir");
        for method in ["project/update", "project/delete"] {
            let reply = call(
                &format!(r#"{{"method":"{method}","id":1,"params":{{"id":"nope"}}}}"#),
                dir.path(),
            );
            assert!(reply["error"].is_object(), "{method} should report an error");
        }
    }

    #[test]
    fn should_delete_a_project() {
        let dir = tempdir().expect("tempdir");
        let id = create_one(dir.path());

        let deleted = call(
            &format!(r#"{{"method":"project/delete","id":2,"params":{{"id":"{id}"}}}}"#),
            dir.path(),
        );
        assert!(deleted["result"].is_object());

        let listed = call(r#"{"method":"project/list","id":3}"#, dir.path());
        assert!(listed["result"]["data"].as_array().expect("data").is_empty());
    }
}
