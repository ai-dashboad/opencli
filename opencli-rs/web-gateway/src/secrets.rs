//! Gateway-side handling of provider API keys.
//!
//! Keys are read from environment variables, which is right for a secret and
//! impossible for an app launched from a dock icon — a window opened by Finder
//! inherits no shell. So they are also read from `$OPENCLI_HOME/.env`, and this
//! is how the interface writes to it.
//!
//! **A value is never sent back.** The panel needs to know which providers have
//! a key and which do not; it never needs to display one, and a key on screen
//! is a key in a screenshot.

use opencli_core::secrets;
use serde_json::Value;
use serde_json::json;
use std::path::Path;

/// Answer a `secret/*` request, or return `None` to let it pass through.
pub fn handle(raw: &str, opencli_home: &Path) -> Option<String> {
    let message: Value = serde_json::from_str(raw).ok()?;
    let method = message.get("method")?.as_str()?;
    if !method.starts_with("secret/") {
        return None;
    }
    let id = message.get("id").cloned().unwrap_or(Value::Null);
    let params = message.get("params").cloned().unwrap_or(json!({}));

    let result = match method {
        "secret/list" => list(opencli_home),
        "secret/write" => write(opencli_home, &params),
        _ => Err(format!("unknown method `{method}`")),
    };

    Some(match result {
        Ok(value) => json!({ "id": id, "result": value }).to_string(),
        Err(message) => {
            json!({ "id": id, "error": { "code": -32602, "message": message } }).to_string()
        }
    })
}

/// Which variables have a value, and where it came from.
///
/// Both sources are reported because they behave differently: one exported in
/// the shell wins over the file and cannot be changed from here, and saying so
/// is better than letting someone type a new key into a box that then appears
/// to do nothing.
fn list(opencli_home: &Path) -> Result<Value, String> {
    let stored = secrets::read_secrets(opencli_home).map_err(|err| err.to_string())?;
    let mut names: Vec<&String> = stored.keys().collect();
    let from_environment: Vec<String> = std::env::vars()
        .filter(|(key, value)| is_key_like(key) && !value.trim().is_empty())
        .map(|(key, _)| key)
        .collect();
    for key in &from_environment {
        if !stored.contains_key(key) {
            names.push(key);
        }
    }
    names.sort();
    names.dedup();

    Ok(json!({
        "secrets": names.iter().map(|name| json!({
            "name": name,
            "stored": stored.contains_key(*name),
            "fromEnvironment": from_environment.contains(name),
        })).collect::<Vec<_>>()
    }))
}

/// A rough guess at which of this process's variables are credentials, used
/// only to report that one is already set. Deliberately narrow: listing every
/// variable a shell happens to export would be both noise and a disclosure.
fn is_key_like(name: &str) -> bool {
    let name = name.to_ascii_uppercase();
    name.ends_with("_API_KEY") || name.ends_with("_TOKEN") || name.ends_with("_KEY")
}

fn write(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let name = params
        .get("name")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|name| !name.is_empty())
        .ok_or_else(|| "a variable name is required".to_string())?;
    if !name
        .chars()
        .all(|character| character.is_ascii_alphanumeric() || character == '_')
    {
        return Err(format!(
            "`{name}` is not a valid environment variable name: letters, digits and underscores only"
        ));
    }

    let value = params.get("value").and_then(Value::as_str);
    secrets::write_secret(opencli_home, name, value).map_err(|err| err.to_string())?;

    // Applied to this process too, so the next message works without a restart
    // — the agent runs as a child of the gateway and inherits from here.
    match value {
        Some(value) if !value.trim().is_empty() => unsafe {
            std::env::set_var(name, value.trim());
        },
        _ => unsafe { std::env::remove_var(name) },
    }

    Ok(json!({ "name": name, "stored": value.is_some_and(|v| !v.trim().is_empty()) }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn should_refuse_a_name_that_is_not_a_variable() {
        let home = tempfile::tempdir().expect("temp dir");
        let error = write(home.path(), &json!({ "name": "my key", "value": "x" }))
            .expect_err("a name with a space is not a variable");
        assert!(
            error.contains("not a valid environment variable name"),
            "{error}"
        );
    }

    #[test]
    fn should_report_that_a_key_is_stored_without_returning_it() {
        let home = tempfile::tempdir().expect("temp dir");
        write(
            home.path(),
            &json!({ "name": "SOME_API_KEY", "value": "sk-secret" }),
        )
        .expect("write");

        let listed = list(home.path()).expect("list").to_string();
        assert!(listed.contains("SOME_API_KEY"));
        // The whole point: the value does not come back.
        assert!(!listed.contains("sk-secret"), "{listed}");
    }
}
