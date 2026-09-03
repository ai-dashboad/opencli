//! Making an installed model usable.
//!
//! Installing a model puts a file on a machine. Using it needs two more things
//! written down: a provider saying where that machine answers, and a `[[models]]`
//! entry saying the model is served there. Without them the model is installed
//! and invisible — the picker never offers it, and the user is left editing
//! `config.toml` by hand after a one-click install.
//!
//! Both are written from what the runtime already reported, so the context
//! window and tool support are read rather than guessed.

use opencli_core::config::edit::ConfigEditsBuilder;
use serde_json::Value;
use serde_json::json;
use std::path::Path;
use toml_edit::Item as TomlItem;

/// A provider id derived from a server's address.
///
/// Stable, so registering a second model on the same server reuses the first
/// provider rather than accumulating near-duplicates.
pub(crate) fn provider_id(base_url: &str) -> String {
    let authority = base_url
        .trim_end_matches('/')
        .trim_end_matches("/v1")
        .split("://")
        .nth(1)
        .unwrap_or(base_url);
    let mut id = String::from("ollama-");
    let mut last_dash = false;
    for character in authority.chars() {
        if character.is_ascii_alphanumeric() {
            id.push(character.to_ascii_lowercase());
            last_dash = false;
        } else if !last_dash {
            id.push('-');
            last_dash = true;
        }
    }
    id.trim_end_matches('-').to_string()
}

/// The URL a provider should use.
///
/// The OpenAI-compatible surface lives under `/v1`; the management API does
/// not. A provider pointed at the management root fails on every request.
fn provider_url(base_url: &str) -> String {
    let root = base_url.trim_end_matches('/').trim_end_matches("/v1");
    format!("{root}/v1")
}

/// Register a model so the picker offers it.
pub fn register(
    opencli_home: &Path,
    base_url: &str,
    model: &str,
    display_name: Option<&str>,
    context_window: Option<i64>,
) -> Result<Value, String> {
    let id = provider_id(base_url);
    let url = provider_url(base_url);

    let existing = read_config(opencli_home)?;
    let already = existing
        .get("models")
        .and_then(|models| models.as_array_of_tables())
        .map(|models| {
            models.iter().any(|entry| {
                entry.get("model").and_then(|value| value.as_str()) == Some(model)
                    && entry.get("provider").and_then(|value| value.as_str()) == Some(id.as_str())
            })
        })
        .unwrap_or(false);
    if already {
        return Ok(json!({ "provider": id, "model": model, "added": false }));
    }

    let mut models = existing
        .get("models")
        .and_then(|models| models.as_array_of_tables())
        .cloned()
        .unwrap_or_default();

    let mut entry = toml_edit::Table::new();
    entry["model"] = toml_edit::value(model);
    entry["provider"] = toml_edit::value(id.as_str());
    if let Some(name) = display_name.filter(|name| !name.is_empty()) {
        entry["display_name"] = toml_edit::value(name);
    }
    if let Some(window) = context_window {
        entry["context_window"] = toml_edit::value(window);
    }
    models.push(entry);

    ConfigEditsBuilder::new(opencli_home)
        .with_edits([
            opencli_core::config::edit::ConfigEdit::SetPath {
                segments: vec!["model_providers".into(), id.clone(), "name".into()],
                value: toml_edit::value(format!("Ollama at {}", host_of(base_url))),
            },
            opencli_core::config::edit::ConfigEdit::SetPath {
                segments: vec!["model_providers".into(), id.clone(), "base_url".into()],
                value: toml_edit::value(url.as_str()),
            },
            opencli_core::config::edit::ConfigEdit::SetPath {
                segments: vec!["model_providers".into(), id.clone(), "wire_api".into()],
                value: toml_edit::value("chat"),
            },
            opencli_core::config::edit::ConfigEdit::SetPath {
                segments: vec!["models".into()],
                value: TomlItem::ArrayOfTables(models),
            },
        ])
        .apply_blocking()
        .map_err(|err| format!("could not write config.toml: {err}"))?;

    Ok(json!({ "provider": id, "model": model, "added": true }))
}

/// Remove a model's entry, so uninstalling does not leave the picker offering
/// something that is no longer there.
pub fn unregister(opencli_home: &Path, base_url: &str, model: &str) -> Result<Value, String> {
    let id = provider_id(base_url);
    let existing = read_config(opencli_home)?;
    let Some(models) = existing
        .get("models")
        .and_then(|models| models.as_array_of_tables())
    else {
        return Ok(json!({ "removed": false }));
    };

    let mut kept = toml_edit::ArrayOfTables::new();
    let mut removed = false;
    for entry in models.iter() {
        let matches = entry.get("model").and_then(|value| value.as_str()) == Some(model)
            && entry.get("provider").and_then(|value| value.as_str()) == Some(id.as_str());
        if matches {
            removed = true;
        } else {
            kept.push(entry.clone());
        }
    }
    if !removed {
        return Ok(json!({ "removed": false }));
    }

    // The provider is left in place. Another model may still use it, and an
    // unused provider costs nothing but retyping it does.
    ConfigEditsBuilder::new(opencli_home)
        .with_edits([opencli_core::config::edit::ConfigEdit::SetPath {
            segments: vec!["models".into()],
            value: TomlItem::ArrayOfTables(kept),
        }])
        .apply_blocking()
        .map_err(|err| format!("could not write config.toml: {err}"))?;

    Ok(json!({ "removed": true }))
}

fn host_of(base_url: &str) -> String {
    base_url
        .trim_end_matches('/')
        .split("://")
        .nth(1)
        .unwrap_or(base_url)
        .split('/')
        .next()
        .unwrap_or(base_url)
        .to_string()
}

fn read_config(opencli_home: &Path) -> Result<toml_edit::DocumentMut, String> {
    let path = opencli_home.join("config.toml");
    if !path.exists() {
        return Ok(toml_edit::DocumentMut::new());
    }
    std::fs::read_to_string(&path)
        .map_err(|err| format!("could not read config.toml: {err}"))?
        .parse()
        .map_err(|err| format!("config.toml is not valid: {err}"))
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    fn config_of(home: &Path) -> String {
        std::fs::read_to_string(home.join("config.toml")).unwrap_or_default()
    }

    #[test]
    fn should_derive_one_provider_id_per_server() {
        // A second model on the same server must reuse the provider rather
        // than adding a near-duplicate beside it.
        assert_eq!(
            provider_id("https://llm.example.com"),
            "ollama-llm-example-com"
        );
        assert_eq!(
            provider_id("https://llm.example.com/v1"),
            provider_id("https://llm.example.com")
        );
        assert_eq!(
            provider_id("http://localhost:11434"),
            "ollama-localhost-11434"
        );
    }

    #[test]
    fn should_point_the_provider_at_the_openai_surface() {
        // The management API is at the root and the chat API under `/v1`; a
        // provider pointed at the root fails on every request.
        assert_eq!(
            provider_url("http://localhost:11434"),
            "http://localhost:11434/v1"
        );
        assert_eq!(
            provider_url("http://localhost:11434/v1"),
            "http://localhost:11434/v1"
        );
    }

    #[test]
    fn should_make_an_installed_model_selectable() {
        let dir = tempdir().expect("tempdir");
        let result = register(
            dir.path(),
            "https://llm.example.com",
            "qwen2.5-coder:7b",
            Some("Qwen Coder 7B"),
            Some(32768),
        )
        .expect("register");
        assert_eq!(result["added"], true);

        let written = config_of(dir.path());
        assert!(
            written.contains("[model_providers.ollama-llm-example-com]"),
            "got: {written}"
        );
        assert!(written.contains("qwen2.5-coder:7b"), "got: {written}");
        assert!(written.contains("context_window = 32768"), "got: {written}");
        assert!(written.contains("wire_api = \"chat\""), "got: {written}");
    }

    #[test]
    fn should_not_add_the_same_model_twice() {
        let dir = tempdir().expect("tempdir");
        register(dir.path(), "https://llm.example.com", "a:7b", None, None).expect("first");
        let again =
            register(dir.path(), "https://llm.example.com", "a:7b", None, None).expect("second");
        assert_eq!(again["added"], false);
        assert_eq!(config_of(dir.path()).matches("a:7b").count(), 1);
    }

    #[test]
    fn should_keep_a_second_model_on_the_same_server() {
        let dir = tempdir().expect("tempdir");
        register(dir.path(), "https://llm.example.com", "a:7b", None, None).expect("first");
        register(dir.path(), "https://llm.example.com", "b:7b", None, None).expect("second");

        let written = config_of(dir.path());
        assert!(
            written.contains("a:7b"),
            "the first must survive: {written}"
        );
        assert!(written.contains("b:7b"), "got: {written}");
        assert_eq!(
            written
                .matches("[model_providers.ollama-llm-example-com]")
                .count(),
            1,
            "one provider, not one per model"
        );
    }

    #[test]
    fn should_leave_the_rest_of_the_file_alone() {
        // The file is the user's, and a one-click install must not cost them
        // their comments or unrelated settings.
        let dir = tempdir().expect("tempdir");
        std::fs::write(
            dir.path().join("config.toml"),
            "# my notes\nmodel = \"something\"\n\n[[models]]\nmodel = \"kept\"\nprovider = \"p\"\n",
        )
        .expect("write");

        register(dir.path(), "http://localhost:11434", "new:7b", None, None).expect("register");

        let written = config_of(dir.path());
        assert!(written.contains("# my notes"), "got: {written}");
        assert!(written.contains("model = \"something\""), "got: {written}");
        assert!(
            written.contains("kept"),
            "an existing model must survive: {written}"
        );
        assert!(written.contains("new:7b"), "got: {written}");
    }

    #[test]
    fn should_add_models_to_a_config_that_has_plain_keys_but_no_models_yet() {
        // The commonest real file: some settings, no `[[models]]`. A provider
        // table gets written first, and a root-level key placed after a table
        // is where this silently went wrong.
        let dir = tempdir().expect("tempdir");
        std::fs::write(
            dir.path().join("config.toml"),
            "# my notes\nmodel = \"glm-5.2\"\n",
        )
        .expect("write");

        register(
            dir.path(),
            "https://llm.example.com",
            "qwen2.5:0.5b",
            None,
            Some(32768),
        )
        .expect("register");

        let written = config_of(dir.path());
        assert!(
            written.contains("qwen2.5:0.5b"),
            "the model must be written: {written}"
        );
        // And the file must still parse, which is the part that breaks when a
        // bare key lands after a table.
        let parsed: toml_edit::DocumentMut = written.parse().expect("still valid TOML");
        assert!(
            parsed
                .get("models")
                .and_then(|m| m.as_array_of_tables())
                .is_some(),
            "got: {written}"
        );
    }

    #[test]
    fn should_stop_offering_a_model_that_was_uninstalled() {
        let dir = tempdir().expect("tempdir");
        register(dir.path(), "https://llm.example.com", "a:7b", None, None).expect("register");
        register(dir.path(), "https://llm.example.com", "b:7b", None, None).expect("register");

        let removed =
            unregister(dir.path(), "https://llm.example.com", "a:7b").expect("unregister");
        assert_eq!(removed["removed"], true);

        let written = config_of(dir.path());
        assert!(!written.contains("a:7b"), "got: {written}");
        assert!(
            written.contains("b:7b"),
            "the other must survive: {written}"
        );
    }

    #[test]
    fn should_report_nothing_removed_for_a_model_never_registered() {
        let dir = tempdir().expect("tempdir");
        let result =
            unregister(dir.path(), "https://llm.example.com", "never").expect("unregister");
        assert_eq!(result["removed"], false);
    }
}
