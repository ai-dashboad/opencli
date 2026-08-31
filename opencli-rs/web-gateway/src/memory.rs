//! Gateway-side handling of remembered facts.
//!
//! Memories outlive every thread, so like scheduling and projects they are
//! answered here rather than relayed to an app server scoped to one
//! conversation.

use opencli_core::memory;
use serde_json::Value;
use serde_json::json;
use std::path::Path;

/// Answer a `memory/*` request, or return `None` to let it pass through to the
/// app server.
pub fn handle(raw: &str, opencli_home: &Path) -> Option<String> {
    let message: Value = serde_json::from_str(raw).ok()?;
    let method = message.get("method")?.as_str()?;
    if !method.starts_with("memory/") {
        return None;
    }
    let id = message.get("id").cloned().unwrap_or(Value::Null);
    let params = message.get("params").cloned().unwrap_or(json!({}));

    let result = match method {
        "memory/list" => list(opencli_home, &params),
        "memory/create" => create(opencli_home, &params),
        "memory/update" => update(opencli_home, &params),
        "memory/delete" => delete(opencli_home, &params),
        _ => Err(format!("unknown method `{method}`")),
    };

    Some(match result {
        Ok(value) => json!({ "id": id, "result": value }).to_string(),
        Err(message) => {
            json!({ "id": id, "error": { "code": -32602, "message": message } }).to_string()
        }
    })
}

fn memory_json(memory: &memory::Memory) -> Value {
    json!({
        "id": memory.id,
        "text": memory.text,
        "projectId": memory.project_id,
        "createdAt": memory.created_at,
    })
}

fn required_id(params: &Value) -> Result<&str, String> {
    params
        .get("id")
        .and_then(Value::as_str)
        .ok_or_else(|| "id is required".to_string())
}

fn required_text(params: &Value) -> Result<&str, String> {
    params
        .get("text")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|text| !text.is_empty())
        .ok_or_else(|| "text is required".to_string())
}

/// List facts. With `projectId`, list only what applies to that project —
/// which is what a thread needs before it starts.
fn list(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let project_id = params.get("projectId").and_then(Value::as_str);
    let memories = match params.get("applicable").and_then(Value::as_bool) {
        Some(true) => memory::applicable(opencli_home, project_id),
        _ => memory::load(opencli_home),
    };
    let rows: Vec<Value> = memories.iter().map(memory_json).collect();
    Ok(json!({
        "data": rows,
        // The rendered block, so a client does not have to reproduce the
        // formatting the agent expects.
        "instructions": memory::as_instructions(&memories),
    }))
}

fn create(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let text = required_text(params)?;
    let project_id = params
        .get("projectId")
        .and_then(Value::as_str)
        .map(str::to_string);
    let memory = memory::create(opencli_home, text.to_string(), project_id)
        .map_err(|err| format!("could not save: {err}"))?;
    Ok(memory_json(&memory))
}

fn update(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let id = required_id(params)?;
    let text = required_text(params)?;
    let updated = memory::update(opencli_home, id, text.to_string())
        .map_err(|err| format!("could not save: {err}"))?;
    match updated {
        Some(memory) => Ok(memory_json(&memory)),
        None => Err(format!("no memory with id `{id}`")),
    }
}

fn delete(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let id = required_id(params)?;
    let removed =
        memory::delete(opencli_home, id).map_err(|err| format!("could not save: {err}"))?;
    if !removed {
        return Err(format!("no memory with id `{id}`"));
    }
    Ok(json!({}))
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    fn call(raw: &str, home: &Path) -> Value {
        let reply = handle(raw, home).expect("memory methods are handled locally");
        serde_json::from_str(&reply).expect("valid JSON reply")
    }

    fn create_one(home: &Path, text: &str, project: Option<&str>) -> String {
        let params = match project {
            Some(id) => format!(r#"{{"text":"{text}","projectId":"{id}"}}"#),
            None => format!(r#"{{"text":"{text}"}}"#),
        };
        let created = call(
            &format!(r#"{{"method":"memory/create","id":1,"params":{params}}}"#),
            home,
        );
        created["result"]["id"].as_str().expect("id").to_string()
    }

    #[test]
    fn should_pass_non_memory_methods_through_to_the_agent() {
        let dir = tempdir().expect("tempdir");
        assert!(handle(r#"{"method":"turn/start","id":1}"#, dir.path()).is_none());
        assert!(handle("not json", dir.path()).is_none());
    }

    #[test]
    fn should_create_then_list_a_fact() {
        let dir = tempdir().expect("tempdir");
        create_one(dir.path(), "deploy with just ship", None);

        let listed = call(r#"{"method":"memory/list","id":2}"#, dir.path());
        let rows = listed["result"]["data"].as_array().expect("data");
        assert_eq!(rows.len(), 1);
        assert_eq!(rows[0]["text"], "deploy with just ship");
    }

    #[test]
    fn should_reject_a_fact_with_no_text() {
        let dir = tempdir().expect("tempdir");
        // A blank bullet would take up context and say nothing.
        let reply = call(
            r#"{"method":"memory/create","id":1,"params":{"text":"   "}}"#,
            dir.path(),
        );
        assert!(reply["error"]["message"]
            .as_str()
            .is_some_and(|message| message.contains("text")));
    }

    #[test]
    fn should_list_only_what_applies_to_a_project_when_asked() {
        let dir = tempdir().expect("tempdir");
        create_one(dir.path(), "everywhere", None);
        create_one(dir.path(), "only here", Some("proj-1"));
        create_one(dir.path(), "somewhere else", Some("proj-2"));

        let listed = call(
            r#"{"method":"memory/list","id":2,"params":{"applicable":true,"projectId":"proj-1"}}"#,
            dir.path(),
        );
        let rows = listed["result"]["data"].as_array().expect("data");
        assert_eq!(rows.len(), 2, "the global fact and this project's only");
        assert!(
            !listed["result"]["instructions"]
                .as_str()
                .expect("instructions")
                .contains("somewhere else"),
            "another project's fact must not leak into this context"
        );
    }

    #[test]
    fn should_render_the_instruction_block_for_the_client() {
        let dir = tempdir().expect("tempdir");
        create_one(dir.path(), "never touch vendor/", None);

        let listed = call(r#"{"method":"memory/list","id":2}"#, dir.path());
        assert!(
            listed["result"]["instructions"]
                .as_str()
                .expect("instructions")
                .contains("- never touch vendor/"),
        );
    }

    #[test]
    fn should_render_no_block_when_there_is_nothing_remembered() {
        let dir = tempdir().expect("tempdir");
        let listed = call(r#"{"method":"memory/list","id":2}"#, dir.path());
        assert_eq!(listed["result"]["instructions"], "");
    }

    #[test]
    fn should_reword_a_fact() {
        let dir = tempdir().expect("tempdir");
        let id = create_one(dir.path(), "old", None);

        let updated = call(
            &format!(r#"{{"method":"memory/update","id":2,"params":{{"id":"{id}","text":"new"}}}}"#),
            dir.path(),
        );
        assert_eq!(updated["result"]["text"], "new");
    }

    #[test]
    fn should_report_an_unknown_id_as_an_error() {
        let dir = tempdir().expect("tempdir");
        for params in [r#"{"id":"nope","text":"x"}"#, r#"{"id":"nope"}"#] {
            let method = if params.contains("text") {
                "memory/update"
            } else {
                "memory/delete"
            };
            let reply = call(
                &format!(r#"{{"method":"{method}","id":1,"params":{params}}}"#),
                dir.path(),
            );
            assert!(reply["error"].is_object(), "{method} should report an error");
        }
    }

    #[test]
    fn should_forget_a_fact() {
        let dir = tempdir().expect("tempdir");
        let id = create_one(dir.path(), "temporary", None);

        let deleted = call(
            &format!(r#"{{"method":"memory/delete","id":2,"params":{{"id":"{id}"}}}}"#),
            dir.path(),
        );
        assert!(deleted["result"].is_object());

        let listed = call(r#"{"method":"memory/list","id":3}"#, dir.path());
        assert!(listed["result"]["data"].as_array().expect("data").is_empty());
    }
}
