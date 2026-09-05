//! Languages added by whoever is running this, not by whoever built it.
//!
//! Two translations ship in the bundle. That is fine for two and hopeless for
//! the third: adding a language meant editing a TypeScript file, rebuilding
//! the frontend, and re-signing a desktop app — so in practice nobody outside
//! this repository could add one at all, and a product whose whole point is
//! running on your own machine had a fixed list of languages chosen elsewhere.
//!
//! A file in `$OPENCLI_HOME/locales` is enough now. Named for the language it
//! is — `de.json`, `pt-BR.json` — and holding the sentences it translates,
//! keyed by the English they replace, exactly as they appear in the interface.
//!
//! A file named for a language that already ships is merged into it rather
//! than replacing it, so correcting one awkward sentence costs one line
//! instead of four hundred.

use serde_json::Value;
use serde_json::json;
use std::path::Path;

/// Answer a `locale/*` request, or return `None` to let it pass through.
pub fn handle(raw: &str, opencli_home: &Path) -> Option<String> {
    let message: Value = serde_json::from_str(raw).ok()?;
    let method = message.get("method")?.as_str()?;
    if !method.starts_with("locale/") {
        return None;
    }
    let id = message.get("id").cloned().unwrap_or(Value::Null);

    let result = match method {
        "locale/list" => Ok(json!({ "data": added(opencli_home), "directory": dir(opencli_home) })),
        _ => Err(format!("unknown method `{method}`")),
    };

    Some(match result {
        Ok(value) => json!({ "id": id, "result": value }).to_string(),
        Err(message) => {
            json!({ "id": id, "error": { "code": -32602, "message": message } }).to_string()
        }
    })
}

fn dir(opencli_home: &Path) -> String {
    opencli_home.join("locales").to_string_lossy().into_owned()
}

/// Every readable language file, as the interface wants them.
///
/// A file that will not parse is skipped rather than failing the request: one
/// bad file should cost its own language, not every other one and the panel
/// that lists them.
fn added(opencli_home: &Path) -> Vec<Value> {
    let Ok(entries) = std::fs::read_dir(opencli_home.join("locales")) else {
        return Vec::new();
    };
    let mut found: Vec<Value> = Vec::new();
    for entry in entries.flatten() {
        let path = entry.path();
        if path.extension().and_then(|ext| ext.to_str()) != Some("json") {
            continue;
        }
        let Some(code) = path.file_stem().and_then(|stem| stem.to_str()) else {
            continue;
        };
        let Ok(text) = std::fs::read_to_string(&path) else {
            continue;
        };
        let Ok(parsed) = serde_json::from_str::<Value>(&text) else {
            tracing::warn!("skipping `{}`: not valid JSON", path.display());
            continue;
        };
        // Two shapes are accepted because both are the obvious one to write:
        // an envelope naming the language, or the bare map of sentences with
        // the filename as its only name.
        let (name, strings) = match parsed.get("strings") {
            Some(strings) => (
                parsed
                    .get("name")
                    .and_then(Value::as_str)
                    .unwrap_or(code)
                    .to_string(),
                strings.clone(),
            ),
            None => (code.to_string(), parsed),
        };
        if !strings.is_object() {
            tracing::warn!("skipping `{}`: expected an object of sentences", path.display());
            continue;
        }
        found.push(json!({ "code": code, "name": name, "strings": strings }));
    }
    found.sort_by(|a, b| a["code"].as_str().cmp(&b["code"].as_str()));
    found
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    fn call(raw: &str, home: &Path) -> Value {
        let reply = handle(raw, home).expect("locale methods are handled locally");
        serde_json::from_str(&reply).expect("valid JSON reply")
    }

    fn write(home: &Path, name: &str, body: &str) {
        let dir = home.join("locales");
        std::fs::create_dir_all(&dir).expect("mkdir");
        std::fs::write(dir.join(name), body).expect("write");
    }

    #[test]
    fn should_let_other_methods_pass_through() {
        let dir = tempdir().expect("tempdir");
        assert!(handle(r#"{"method":"turn/start","id":1}"#, dir.path()).is_none());
    }

    #[test]
    fn should_find_nothing_when_no_languages_have_been_added() {
        // The ordinary case, and it must not be an error.
        let dir = tempdir().expect("tempdir");
        let reply = call(r#"{"method":"locale/list","id":1}"#, dir.path());
        assert_eq!(reply["result"]["data"].as_array().map(Vec::len), Some(0));
    }

    #[test]
    fn should_read_a_language_named_by_its_file() {
        let dir = tempdir().expect("tempdir");
        write(dir.path(), "de.json", r#"{"Dispatch":"Versand"}"#);

        let reply = call(r#"{"method":"locale/list","id":1}"#, dir.path());
        let first = &reply["result"]["data"][0];
        assert_eq!(first["code"], "de");
        assert_eq!(first["name"], "de");
        assert_eq!(first["strings"]["Dispatch"], "Versand");
    }

    #[test]
    fn should_prefer_the_name_the_file_gives_itself() {
        // So a picker can offer "Deutsch" rather than "de".
        let dir = tempdir().expect("tempdir");
        write(
            dir.path(),
            "de.json",
            r#"{"name":"Deutsch","strings":{"Dispatch":"Versand"}}"#,
        );

        let reply = call(r#"{"method":"locale/list","id":1}"#, dir.path());
        assert_eq!(reply["result"]["data"][0]["name"], "Deutsch");
        assert_eq!(reply["result"]["data"][0]["strings"]["Dispatch"], "Versand");
    }

    #[test]
    fn should_skip_a_broken_file_without_losing_the_others() {
        // One unparseable file should cost its own language and nothing else.
        let dir = tempdir().expect("tempdir");
        write(dir.path(), "broken.json", "{ this is not json");
        write(dir.path(), "de.json", r#"{"Dispatch":"Versand"}"#);

        let reply = call(r#"{"method":"locale/list","id":1}"#, dir.path());
        let data = reply["result"]["data"].as_array().expect("a list");
        assert_eq!(data.len(), 1);
        assert_eq!(data[0]["code"], "de");
    }

    #[test]
    fn should_ignore_files_that_are_not_json() {
        let dir = tempdir().expect("tempdir");
        write(dir.path(), "README.md", "how to add a language");
        let reply = call(r#"{"method":"locale/list","id":1}"#, dir.path());
        assert_eq!(reply["result"]["data"].as_array().map(Vec::len), Some(0));
    }

    #[test]
    fn should_say_where_the_files_go() {
        // The panel shows this; without it, the feature is undiscoverable.
        let dir = tempdir().expect("tempdir");
        let reply = call(r#"{"method":"locale/list","id":1}"#, dir.path());
        assert!(
            reply["result"]["directory"]
                .as_str()
                .is_some_and(|path| path.ends_with("locales"))
        );
    }
}
