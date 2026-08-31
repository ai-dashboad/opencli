//! Gateway-side handling of projects.
//!
//! Like scheduling, a project outlives any one thread, so the gateway answers
//! `project/*` itself rather than relaying to the app server, which is scoped
//! to a single conversation.

use opencli_core::memory;
use opencli_core::projects;
use std::path::PathBuf;
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
        "project/root" => Ok(root_json(opencli_home)),
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
        "description": project.description,
        "instructions": project.instructions,
        "createdAt": project.created_at,
        "updatedAt": project.updated_at,
        "pinned": project.pinned,
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

/// Where a new project's folder goes when the user does not choose one.
///
/// Read from `projects_root` in config.toml, falling back to `Projects` under
/// the home directory. Read from the file rather than the running session so a
/// change made a moment ago is honoured.
fn projects_root(opencli_home: &Path) -> PathBuf {
    let configured = std::fs::read_to_string(opencli_home.join("config.toml"))
        .ok()
        .and_then(|text| toml::from_str::<opencli_core::config::ConfigToml>(&text).ok())
        .and_then(|parsed| parsed.projects_root);
    if let Some(root) = configured {
        return root;
    }
    match std::env::var_os("HOME").filter(|home| !home.is_empty()) {
        Some(home) => PathBuf::from(home).join("Projects"),
        // No home to put it under; the working directory is the only place
        // left that is certainly writable.
        None => PathBuf::from("."),
    }
}

fn root_json(opencli_home: &Path) -> Value {
    let root = projects_root(opencli_home);
    json!({
        "root": root.to_string_lossy(),
        "exists": root.is_dir(),
    })
}

/// Turn a project name into a folder name.
///
/// Spaces and punctuation become dashes: a folder is typed at a shell and
/// quoted in scripts, and one named `My Project (v2)` is a nuisance in both.
pub(crate) fn folder_name(name: &str) -> String {
    let mut out = String::new();
    let mut last_dash = true;
    for character in name.chars() {
        if character.is_ascii_alphanumeric() || character == '.' || character == '_' {
            out.push(character.to_ascii_lowercase());
            last_dash = false;
        } else if !last_dash {
            out.push('-');
            last_dash = true;
        }
    }
    out.trim_matches('-').to_string()
}

/// Create a project's folder.
///
/// Under the projects root the whole path is made, including the root itself:
/// this app suggested that location, so failing there on a path the user never
/// typed would be its own fault to fix.
///
/// Anywhere else only the last component is made. A typo in a parent should
/// not silently build a tree of empty directories somewhere the user chose by
/// hand.
fn make_directory(opencli_home: &Path, path: &Path) -> Result<(), String> {
    if path.is_dir() {
        return Ok(());
    }
    if path.exists() {
        return Err(format!("`{}` is a file, not a directory", path.display()));
    }

    if path.starts_with(projects_root(opencli_home)) {
        return std::fs::create_dir_all(path)
            .map_err(|err| format!("could not create `{}`: {err}", path.display()));
    }

    let Some(parent) = path.parent() else {
        return Err(format!("`{}` has no parent directory", path.display()));
    };
    if !parent.is_dir() {
        return Err(format!("`{}` does not exist", parent.display()));
    }
    std::fs::create_dir(path).map_err(|err| format!("could not create `{}`: {err}", path.display()))
}

/// Reject a directory that does not exist.
///
/// Without this the mistake surfaces much later, as a failure to start a
/// thread, with nothing pointing back at the typo in the project's path.
fn ensure_directory(cwd: &str) -> Result<(), String> {
    let path = Path::new(cwd);
    if path.is_dir() {
        return Ok(());
    }
    Err(if path.exists() {
        format!("`{cwd}` is a file, not a directory")
    } else {
        format!("`{cwd}` does not exist")
    })
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
    let description = optional_text(params, "description").unwrap_or_default();

    // Making the folder is the common case for a new project, so it is offered
    // rather than demanded up front.
    if params.get("createDirectory").and_then(Value::as_bool) == Some(true) {
        make_directory(opencli_home, Path::new(cwd))?;
    }
    ensure_directory(cwd)?;

    let project = projects::create(
        opencli_home,
        name.to_string(),
        cwd.to_string(),
        instructions,
        description,
    )
    .map_err(|err| format!("could not save the project: {err}"))?;
    Ok(project_json(&project))
}

fn update(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let id = required_id(params)?;
    let cwd = optional_text(params, "cwd");
    if let Some(cwd) = cwd.as_deref() {
        ensure_directory(cwd)?;
    }
    let updated = projects::update(
        opencli_home,
        id,
        optional_text(params, "name"),
        cwd,
        optional_text(params, "instructions"),
        optional_text(params, "description"),
        params.get("pinned").and_then(Value::as_bool),
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
    // The project's own memories can never apply again; leaving them would
    // clutter the list with facts that read as active but never are. The
    // threads it grouped are untouched — those still stand on their own.
    let forgotten = memory::forget_project(opencli_home, id)
        .map_err(|err| format!("could not forget the project's memories: {err}"))?;
    Ok(json!({ "forgottenMemories": forgotten }))
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
                {"name":"Site","cwd":"/tmp","instructions":"be careful"}}"#,
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
        assert_eq!(rows[0]["cwd"], "/tmp");
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
    fn should_reject_a_directory_that_does_not_exist() {
        let dir = tempdir().expect("tempdir");
        let reply = call(
            r#"{"method":"project/create","id":1,"params":
                {"name":"x","cwd":"/no/such/place"}}"#,
            dir.path(),
        );
        assert!(reply["error"]["message"]
            .as_str()
            .is_some_and(|message| message.contains("does not exist")));
    }

    #[test]
    fn should_reject_moving_a_project_to_a_missing_directory() {
        let dir = tempdir().expect("tempdir");
        let id = create_one(dir.path());
        let reply = call(
            &format!(
                r#"{{"method":"project/update","id":2,"params":{{"id":"{id}","cwd":"/no/such"}}}}"#
            ),
            dir.path(),
        );
        assert!(reply["error"].is_object());
    }

    #[test]
    fn should_turn_a_project_name_into_a_usable_folder_name() {
        // A folder is typed at a shell and quoted in scripts; one named
        // `My Project (v2)` is a nuisance in both.
        assert_eq!(folder_name("My Project (v2)"), "my-project-v2");
        assert_eq!(folder_name("  spaced  out  "), "spaced-out");
        assert_eq!(folder_name("already-fine"), "already-fine");
        assert_eq!(folder_name("!!!"), "");
    }

    #[test]
    fn should_fall_back_to_a_folder_under_home_when_none_is_configured() {
        let dir = tempdir().expect("tempdir");
        let root = call(r#"{"method":"project/root","id":1}"#, dir.path());
        assert!(
            root["result"]["root"]
                .as_str()
                .is_some_and(|root| root.ends_with("Projects")),
            "got {:?}",
            root["result"]["root"]
        );
    }

    #[test]
    fn should_read_the_configured_root_from_the_file() {
        let dir = tempdir().expect("tempdir");
        std::fs::write(
            dir.path().join("config.toml"),
            "projects_root = \"/srv/work\"\n",
        )
        .expect("write");

        let root = call(r#"{"method":"project/root","id":1}"#, dir.path());
        assert_eq!(root["result"]["root"], "/srv/work");
    }

    #[test]
    fn should_create_the_folder_when_asked_to() {
        let dir = tempdir().expect("tempdir");
        let target = dir.path().join("brand-new");

        let created = call(
            &format!(
                r#"{{"method":"project/create","id":1,"params":
                   {{"name":"Brand New","cwd":"{}","createDirectory":true}}}}"#,
                target.display()
            ),
            dir.path(),
        );
        assert!(created["result"].is_object(), "got {created}");
        assert!(target.is_dir());
    }

    #[test]
    fn should_create_the_projects_root_the_first_time_it_is_used() {
        // The default location is one this app suggested, so it must work on a
        // machine that has never had it.
        let dir = tempdir().expect("tempdir");
        let root = dir.path().join("Projects");
        std::fs::write(
            dir.path().join("config.toml"),
            format!("projects_root = \"{}\"\n", root.display()),
        )
        .expect("write");

        let created = call(
            &format!(
                r#"{{"method":"project/create","id":1,"params":
                   {{"name":"First","cwd":"{}/first","createDirectory":true}}}}"#,
                root.display()
            ),
            dir.path(),
        );
        assert!(created["result"].is_object(), "got {created}");
        assert!(root.join("first").is_dir());
    }

    #[test]
    fn should_refuse_to_build_a_tree_of_directories_from_a_typo() {
        // Only the last component is created; a mistyped parent should not
        // silently produce a chain of empty folders.
        let dir = tempdir().expect("tempdir");
        let target = dir.path().join("mistyped").join("child");

        let reply = call(
            &format!(
                r#"{{"method":"project/create","id":1,"params":
                   {{"name":"x","cwd":"{}","createDirectory":true}}}}"#,
                target.display()
            ),
            dir.path(),
        );
        assert!(reply["error"].is_object());
        assert!(!dir.path().join("mistyped").exists());
    }

    #[test]
    fn should_still_refuse_a_missing_folder_when_not_asked_to_create_one() {
        let dir = tempdir().expect("tempdir");
        let reply = call(
            &format!(
                r#"{{"method":"project/create","id":1,"params":{{"name":"x","cwd":"{}/nope"}}}}"#,
                dir.path().display()
            ),
            dir.path(),
        );
        assert!(reply["error"].is_object());
    }

    #[test]
    fn should_pin_and_unpin_a_project() {
        let dir = tempdir().expect("tempdir");
        let id = create_one(dir.path());

        let pinned = call(
            &format!(
                r#"{{"method":"project/update","id":2,"params":{{"id":"{id}","pinned":true}}}}"#
            ),
            dir.path(),
        );
        assert_eq!(pinned["result"]["pinned"], true);
        assert_eq!(pinned["result"]["name"], "Site", "pinning changes nothing else");
    }

    #[test]
    fn should_report_when_a_project_was_last_used() {
        let dir = tempdir().expect("tempdir");
        create_one(dir.path());
        let listed = call(r#"{"method":"project/list","id":2}"#, dir.path());
        assert!(listed["result"]["data"][0]["updatedAt"].as_u64().is_some_and(|at| at > 0));
    }

    #[test]
    fn should_forget_a_deleted_projects_memories() {
        let dir = tempdir().expect("tempdir");
        let id = create_one(dir.path());
        memory::create(dir.path(), "scoped".into(), Some(id.clone())).expect("create");
        memory::create(dir.path(), "global".into(), None).expect("create");

        let deleted = call(
            &format!(r#"{{"method":"project/delete","id":2,"params":{{"id":"{id}"}}}}"#),
            dir.path(),
        );
        assert_eq!(deleted["result"]["forgottenMemories"], 1);

        let remaining = memory::load(dir.path());
        assert_eq!(remaining.len(), 1);
        assert_eq!(remaining[0].text, "global", "global facts must survive");
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
