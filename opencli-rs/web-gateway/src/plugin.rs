//! Gateway-side plugin management.
//!
//! A "plugin" here is a skill: a directory with a `SKILL.md` that the agent
//! reads when the task calls for it. They live under `<home>/skills/`, so
//! installing one is fetching a directory and removing one is deleting it —
//! both file operations on this machine, which is why they are answered here.
//!
//! The catalogue is deliberately small and points at real repositories. A
//! marketplace whose entries do not resolve is worse than a short list that
//! does.

use serde_json::Value;
use serde_json::json;
use std::path::Path;
use std::path::PathBuf;

/// A skill directory is identified by the file the loader looks for.
const SKILL_FILE: &str = "SKILL.md";

/// Answer a `plugin/*` request, or return `None` to let it pass through.
pub fn handle(raw: &str, opencli_home: &Path) -> Option<String> {
    let message: Value = serde_json::from_str(raw).ok()?;
    let method = message.get("method")?.as_str()?;
    if !method.starts_with("plugin/") {
        return None;
    }
    let id = message.get("id").cloned().unwrap_or(Value::Null);
    let params = message.get("params").cloned().unwrap_or(json!({}));

    let result = match method {
        "plugin/list" => list(opencli_home),
        "plugin/catalog" => Ok(catalog()),
        "plugin/install" => install(opencli_home, &params),
        "plugin/remove" => remove(opencli_home, &params),
        _ => Err(format!("unknown method `{method}`")),
    };

    Some(match result {
        Ok(value) => json!({ "id": id, "result": value }).to_string(),
        Err(message) => {
            json!({ "id": id, "error": { "code": -32602, "message": message } }).to_string()
        }
    })
}

fn skills_root(opencli_home: &Path) -> PathBuf {
    opencli_home.join("skills")
}

/// Read the first heading or description line, for a list that says what each
/// skill is rather than only what it is called.
fn describe(skill_md: &Path) -> String {
    let Ok(text) = std::fs::read_to_string(skill_md) else {
        return String::new();
    };
    // SKILL.md opens with YAML front matter carrying a description.
    for line in text.lines().take(20) {
        if let Some(rest) = line.strip_prefix("description:") {
            return rest.trim().trim_matches('"').to_string();
        }
    }
    text.lines()
        .find(|line| !line.trim().is_empty() && !line.starts_with("---"))
        .unwrap_or("")
        .trim_start_matches('#')
        .trim()
        .to_string()
}

/// How many skills a directory holds, looking one level down.
///
/// One level only: a repository puts each skill in its own folder, and walking
/// deeper would count examples and fixtures as skills.
fn count_skills(dir: &Path) -> usize {
    let Ok(entries) = std::fs::read_dir(dir) else {
        return 0;
    };
    entries
        .flatten()
        .filter(|entry| entry.path().join(SKILL_FILE).is_file())
        .count()
}

/// Every skill installed under the home directory.
fn list(opencli_home: &Path) -> Result<Value, String> {
    let root = skills_root(opencli_home);
    let mut data = Vec::new();
    if let Ok(entries) = std::fs::read_dir(&root) {
        for entry in entries.flatten() {
            let path = entry.path();
            // The loader keeps its own bundled skills under a dot directory;
            // offering to uninstall those would break the app itself.
            if entry.file_name().to_string_lossy().starts_with('.') {
                continue;
            }
            let skill_md = path.join(SKILL_FILE);
            if skill_md.is_file() {
                data.push(json!({
                    "name": entry.file_name().to_string_lossy(),
                    "description": describe(&skill_md),
                    "path": path.to_string_lossy(),
                    "contains": 1,
                }));
                continue;
            }

            // A cloned collection has no `SKILL.md` at its root. Listing only
            // loadable skills would leave what the user just installed
            // invisible — and so impossible to remove from here.
            let nested = count_skills(&path);
            if nested > 0 {
                data.push(json!({
                    "name": entry.file_name().to_string_lossy(),
                    "description": format!("A collection of {nested} skills."),
                    "path": path.to_string_lossy(),
                    "contains": nested,
                }));
            }
        }
    }
    data.sort_by(|a, b| a["name"].as_str().cmp(&b["name"].as_str()));
    Ok(json!({ "data": data }))
}

/// Skills worth offering by name.
///
/// Each entry names a repository that exists. Anything else installs from a
/// URL, which `plugin/install` also accepts.
fn catalog() -> Value {
    json!({
        "data": [
            {
                "id": "anthropic-skills",
                "name": "Anthropic example skills",
                "description": "Document handling, spreadsheets, slides and more, from Anthropic's public skills repository.",
                "source": "https://github.com/anthropics/skills",
                "note": "Installs the whole repository; each subdirectory is a skill."
            },
            {
                "id": "mcp-servers",
                "name": "Reference MCP servers",
                "description": "The reference server implementations, useful as worked examples when writing your own.",
                "source": "https://github.com/modelcontextprotocol/servers",
                "note": "A reference, not a skill the agent will load on its own."
            }
        ]
    })
}

fn required_name(params: &Value) -> Result<String, String> {
    let name = params
        .get("name")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|name| !name.is_empty())
        .ok_or("name is required")?;
    // The name becomes a directory under the skills root. Refusing separators
    // and `..` is what keeps an install inside it.
    if name.contains('/') || name.contains('\\') || name.contains("..") || name.starts_with('.') {
        return Err("name may not contain path separators or start with a dot".to_string());
    }
    Ok(name.to_string())
}

/// Install a skill by cloning it.
///
/// `git` rather than an archive download: a skill is a directory of files that
/// its author keeps updating, and a clone can be pulled again later.
fn install(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let source = params
        .get("source")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|source| !source.is_empty())
        .ok_or("source is required")?;
    if !source.starts_with("https://") && !source.starts_with("git@") {
        return Err("source must be an https:// or git@ repository".to_string());
    }
    let name = required_name(params)?;

    let root = skills_root(opencli_home);
    std::fs::create_dir_all(&root).map_err(|err| format!("could not create {root:?}: {err}"))?;
    let target = root.join(&name);
    if target.exists() {
        return Err(format!("`{name}` is already installed"));
    }

    let output = std::process::Command::new("git")
        .arg("clone")
        .arg("--depth")
        .arg("1")
        .arg(source)
        .arg(&target)
        .output()
        .map_err(|err| format!("could not run git: {err}"))?;
    if !output.status.success() {
        // Leave nothing half-cloned behind for the next attempt to trip over.
        let _ = std::fs::remove_dir_all(&target);
        let reason = String::from_utf8_lossy(&output.stderr);
        return Err(format!("could not clone: {}", reason.trim()));
    }

    Ok(json!({
        "name": name,
        "path": target.to_string_lossy(),
        // A repository of skills is not itself a skill; say so rather than
        // letting the user wonder why nothing new appeared in the menu.
        "loadable": target.join(SKILL_FILE).is_file(),
    }))
}

fn remove(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let name = required_name(params)?;
    let target = skills_root(opencli_home).join(&name);
    if !target.is_dir() {
        return Err(format!("`{name}` is not installed"));
    }
    std::fs::remove_dir_all(&target).map_err(|err| format!("could not remove: {err}"))?;
    Ok(json!({}))
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    fn call(raw: &str, home: &Path) -> Value {
        let reply = handle(raw, home).expect("plugin methods are handled locally");
        serde_json::from_str(&reply).expect("valid JSON reply")
    }

    fn place_skill(home: &Path, name: &str, description: &str) {
        let dir = skills_root(home).join(name);
        std::fs::create_dir_all(&dir).expect("mkdir");
        std::fs::write(
            dir.join(SKILL_FILE),
            format!("---\nname: {name}\ndescription: {description}\n---\n\n# {name}\n"),
        )
        .expect("write");
    }

    #[test]
    fn should_pass_non_plugin_methods_through_to_the_agent() {
        let dir = tempdir().expect("tempdir");
        assert!(handle(r#"{"method":"turn/start","id":1}"#, dir.path()).is_none());
        assert!(handle("not json", dir.path()).is_none());
    }

    #[test]
    fn should_list_nothing_when_none_are_installed() {
        let dir = tempdir().expect("tempdir");
        let listed = call(r#"{"method":"plugin/list","id":1}"#, dir.path());
        assert!(listed["result"]["data"].as_array().expect("data").is_empty());
    }

    #[test]
    fn should_list_installed_skills_with_what_they_are_for() {
        let dir = tempdir().expect("tempdir");
        place_skill(dir.path(), "design", "Make things look right.");

        let listed = call(r#"{"method":"plugin/list","id":1}"#, dir.path());
        let row = &listed["result"]["data"][0];
        assert_eq!(row["name"], "design");
        assert_eq!(row["description"], "Make things look right.");
    }

    #[test]
    fn should_ignore_a_directory_with_no_skill_file() {
        // A stray folder under `skills/` is not a skill and offering to
        // uninstall it would be confusing.
        let dir = tempdir().expect("tempdir");
        std::fs::create_dir_all(skills_root(dir.path()).join("notes")).expect("mkdir");
        let listed = call(r#"{"method":"plugin/list","id":1}"#, dir.path());
        assert!(listed["result"]["data"].as_array().expect("data").is_empty());
    }

    #[test]
    fn should_hide_the_bundled_system_skills_from_the_installed_list() {
        // Offering to uninstall those would break the app itself.
        let dir = tempdir().expect("tempdir");
        place_skill(dir.path(), ".system", "internal");
        let listed = call(r#"{"method":"plugin/list","id":1}"#, dir.path());
        assert!(listed["result"]["data"].as_array().expect("data").is_empty());
    }

    #[test]
    fn should_list_a_cloned_collection_so_it_can_be_removed() {
        // Installing a repository of skills and then not seeing it would leave
        // the user unable to undo what they just did.
        let dir = tempdir().expect("tempdir");
        let collection = skills_root(dir.path()).join("anthropic-skills");
        for name in ["docx", "pptx"] {
            let inner = collection.join(name);
            std::fs::create_dir_all(&inner).expect("mkdir");
            std::fs::write(inner.join(SKILL_FILE), "---\ndescription: x\n---\n").expect("write");
        }

        let listed = call(r#"{"method":"plugin/list","id":1}"#, dir.path());
        let row = &listed["result"]["data"][0];
        assert_eq!(row["name"], "anthropic-skills");
        assert_eq!(row["contains"], 2);
    }

    #[test]
    fn should_refuse_a_name_that_would_escape_the_skills_directory() {
        let dir = tempdir().expect("tempdir");
        for name in ["../evil", "a/b", ".hidden"] {
            let reply = call(
                &format!(
                    r#"{{"method":"plugin/install","id":1,"params":
                       {{"name":"{name}","source":"https://example.com/x.git"}}}}"#
                ),
                dir.path(),
            );
            assert!(reply["error"].is_object(), "{name} should be refused");
        }
    }

    #[test]
    fn should_refuse_a_source_that_is_not_a_repository() {
        let dir = tempdir().expect("tempdir");
        let reply = call(
            r#"{"method":"plugin/install","id":1,"params":
               {"name":"x","source":"file:///etc/passwd"}}"#,
            dir.path(),
        );
        assert!(reply["error"]["message"]
            .as_str()
            .is_some_and(|message| message.contains("repository")));
    }

    #[test]
    fn should_refuse_to_install_over_something_already_there() {
        let dir = tempdir().expect("tempdir");
        place_skill(dir.path(), "design", "x");
        let reply = call(
            r#"{"method":"plugin/install","id":1,"params":
               {"name":"design","source":"https://example.com/x.git"}}"#,
            dir.path(),
        );
        assert!(reply["error"]["message"]
            .as_str()
            .is_some_and(|message| message.contains("already installed")));
    }

    #[test]
    fn should_remove_an_installed_skill_and_report_an_unknown_one() {
        let dir = tempdir().expect("tempdir");
        place_skill(dir.path(), "design", "x");

        let removed = call(
            r#"{"method":"plugin/remove","id":1,"params":{"name":"design"}}"#,
            dir.path(),
        );
        assert!(removed["result"].is_object());
        assert!(!skills_root(dir.path()).join("design").exists());

        let missing = call(
            r#"{"method":"plugin/remove","id":2,"params":{"name":"design"}}"#,
            dir.path(),
        );
        assert!(missing["error"].is_object());
    }

    #[test]
    fn should_offer_a_catalogue_whose_entries_name_a_real_source() {
        let catalogued = call(r#"{"method":"plugin/catalog","id":1}"#, Path::new("/tmp"));
        let rows = catalogued["result"]["data"].as_array().expect("data");
        assert!(!rows.is_empty());
        assert!(
            rows.iter().all(|row| row["source"]
                .as_str()
                .is_some_and(|source| source.starts_with("https://"))),
            "an entry that does not resolve is worse than no entry"
        );
    }
}
