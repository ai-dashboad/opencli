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

    let params = message.get("params").cloned().unwrap_or(json!({}));
    let result = match method {
        "locale/list" => Ok(json!({ "data": added(opencli_home), "directory": dir(opencli_home) })),
        "locale/add" => add_one(opencli_home, &params),
        "locale/remove" => remove_one(opencli_home, &params),
        _ => Err(format!("unknown method `{method}`")),
    };

    Some(match result {
        Ok(value) => json!({ "id": id, "result": value }).to_string(),
        Err(message) => {
            json!({ "id": id, "error": { "code": -32602, "message": message } }).to_string()
        }
    })
}

/// Take a language somebody handed over, and keep it.
///
/// Dropping a file into a directory works and is not a way to offer a feature:
/// it asks somebody to know the path, the filename convention and the shape of
/// the contents before anything happens. This takes the same file through the
/// interface and puts it in the same place, so what is uploaded can afterwards
/// be found, edited by hand, and copied to another machine.
fn add_one(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let code = params
        .get("code")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|code| !code.is_empty())
        .ok_or("a language code is required")?;

    // The code becomes a filename, so it may not reach outside the directory
    // it is written to. Letters, digits and a hyphen is the whole of what a
    // language tag needs — `pt-BR`, `zh-Hant` — and nothing else is allowed
    // through.
    if !code
        .chars()
        .all(|each| each.is_ascii_alphanumeric() || each == '-')
    {
        return Err(format!(
            "`{code}` is not a language code — letters, digits and hyphens only, like `pt-BR`"
        ));
    }

    let strings = params
        .get("strings")
        .filter(|value| value.is_object())
        .ok_or("`strings` must be an object of sentences")?;
    if strings.as_object().is_some_and(serde_json::Map::is_empty) {
        return Err("that file has no sentences in it".to_string());
    }
    let name = params
        .get("name")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|name| !name.is_empty())
        .unwrap_or(code);

    let directory = opencli_home.join("locales");
    std::fs::create_dir_all(&directory)
        .map_err(|err| format!("could not make the locales directory: {err}"))?;
    let body = json!({ "name": name, "strings": strings });
    std::fs::write(
        directory.join(format!("{code}.json")),
        serde_json::to_string_pretty(&body).map_err(|err| format!("could not encode: {err}"))?,
    )
    .map_err(|err| format!("could not save: {err}"))?;

    Ok(json!({
        "code": code,
        "name": name,
        "count": strings.as_object().map(serde_json::Map::len).unwrap_or(0),
    }))
}

/// Take one back out. Only added languages live here, so nothing shipped can
/// be deleted by this — at worst a correction to a shipped one is undone.
fn remove_one(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let code = params
        .get("code")
        .and_then(Value::as_str)
        .filter(|code| {
            !code.is_empty()
                && code
                    .chars()
                    .all(|each| each.is_ascii_alphanumeric() || each == '-')
        })
        .ok_or("a language code is required")?;
    let path = opencli_home.join("locales").join(format!("{code}.json"));
    match std::fs::remove_file(&path) {
        Ok(()) => Ok(json!({ "removed": code })),
        Err(err) if err.kind() == std::io::ErrorKind::NotFound => {
            Err(format!("no added language `{code}`"))
        }
        Err(err) => Err(format!("could not remove it: {err}")),
    }
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
    fn should_keep_a_language_that_was_handed_over() {
        // Uploaded through the interface, and afterwards an ordinary file in
        // the directory — which is the point: it can be edited by hand or
        // copied to another machine.
        let dir = tempdir().expect("tempdir");
        let reply = call(
            r#"{"method":"locale/add","id":1,"params":
                {"code":"de","name":"Deutsch","strings":{"Dispatch":"Versand"}}}"#,
            dir.path(),
        );
        assert_eq!(reply["result"]["code"], "de");
        assert_eq!(reply["result"]["count"], 1);

        let listed = call(r#"{"method":"locale/list","id":2}"#, dir.path());
        assert_eq!(listed["result"]["data"][0]["strings"]["Dispatch"], "Versand");
    }

    #[test]
    fn should_refuse_a_code_that_would_write_outside_the_directory() {
        // The code becomes a filename. `../../config.toml` is not a language.
        let dir = tempdir().expect("tempdir");
        let reply = call(
            r#"{"method":"locale/add","id":1,"params":
                {"code":"../../config","strings":{"a":"b"}}}"#,
            dir.path(),
        );
        assert!(
            reply["error"]["message"]
                .as_str()
                .is_some_and(|message| message.contains("language code")),
            "{reply}"
        );
        assert!(!dir.path().join("locales").exists());
    }

    #[test]
    fn should_refuse_a_file_with_no_sentences() {
        let dir = tempdir().expect("tempdir");
        let reply = call(
            r#"{"method":"locale/add","id":1,"params":{"code":"de","strings":{}}}"#,
            dir.path(),
        );
        assert!(reply["error"]["message"].as_str().is_some_and(|m| m.contains("no sentences")));
    }

    #[test]
    fn should_name_a_language_after_its_code_when_none_is_given() {
        let dir = tempdir().expect("tempdir");
        let reply = call(
            r#"{"method":"locale/add","id":1,"params":{"code":"de","strings":{"a":"b"}}}"#,
            dir.path(),
        );
        assert_eq!(reply["result"]["name"], "de");
    }

    #[test]
    fn should_take_a_language_back_out() {
        let dir = tempdir().expect("tempdir");
        call(
            r#"{"method":"locale/add","id":1,"params":{"code":"de","strings":{"a":"b"}}}"#,
            dir.path(),
        );
        let removed = call(r#"{"method":"locale/remove","id":2,"params":{"code":"de"}}"#, dir.path());
        assert_eq!(removed["result"]["removed"], "de");

        let listed = call(r#"{"method":"locale/list","id":3}"#, dir.path());
        assert_eq!(listed["result"]["data"].as_array().map(Vec::len), Some(0));
    }

    #[test]
    fn should_report_removing_one_that_is_not_there() {
        let dir = tempdir().expect("tempdir");
        let reply = call(r#"{"method":"locale/remove","id":1,"params":{"code":"de"}}"#, dir.path());
        assert!(reply["error"]["message"].as_str().is_some_and(|m| m.contains("de")));
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
