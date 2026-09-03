//! Where a conversation starts when nobody has said where.
//!
//! The desktop shell asks its own process for this; a browser has no such
//! process to ask and was falling back to `"."`, which is wherever the gateway
//! happened to be started from. That is a different answer to the same
//! question, and the whole point of the answer is that it is a boundary — the
//! working directory is what `workspace-write` makes writable.

use serde_json::Value;
use serde_json::json;
use std::path::Path;

/// Answer a `workspace/*` request, or return `None` to let it pass through.
pub fn handle(raw: &str, opencli_home: &Path) -> Option<String> {
    let message: Value = serde_json::from_str(raw).ok()?;
    let method = message.get("method")?.as_str()?;
    if method != "workspace/default" {
        return None;
    }
    let id = message.get("id").cloned().unwrap_or(Value::Null);

    Some(
        match opencli_core::config::default_workspace(opencli_home) {
            Ok(path) => {
                json!({ "id": id, "result": { "path": path.to_string_lossy() } }).to_string()
            }
            Err(err) => json!({
                "id": id,
                "error": { "code": -32603, "message": format!("could not prepare the workspace: {err}") }
            })
            .to_string(),
        },
    )
}

#[cfg(test)]
mod tests {
    use super::handle;
    use serde_json::Value;
    use tempfile::tempdir;

    fn call(raw: &str, home: &std::path::Path) -> Value {
        serde_json::from_str(&handle(raw, home).expect("handled")).expect("json")
    }

    #[test]
    fn should_answer_with_a_directory_inside_the_config_home() {
        let dir = tempdir().expect("tempdir");
        let answered = call(r#"{"method":"workspace/default","id":1}"#, dir.path());
        let path = answered["result"]["path"].as_str().expect("path");
        assert_eq!(path, dir.path().join("workspace").to_string_lossy());
    }

    #[test]
    fn should_create_the_directory_so_a_conversation_can_start_in_it() {
        let dir = tempdir().expect("tempdir");
        call(r#"{"method":"workspace/default","id":1}"#, dir.path());
        assert!(dir.path().join("workspace").is_dir());
    }

    #[test]
    fn should_never_answer_with_the_home_directory() {
        // The thing this exists to prevent: `workspace-write` makes the working
        // directory writable, and answering `~` hands over everything in it.
        let dir = tempdir().expect("tempdir");
        let answered = call(r#"{"method":"workspace/default","id":1}"#, dir.path());
        let path = answered["result"]["path"].as_str().expect("path");
        let home = std::env::var("HOME").unwrap_or_default();
        assert!(!home.is_empty() && path != home);
    }

    #[test]
    fn should_let_other_methods_pass_through() {
        let dir = tempdir().expect("tempdir");
        assert!(handle(r#"{"method":"project/list","id":1}"#, dir.path()).is_none());
    }
}
