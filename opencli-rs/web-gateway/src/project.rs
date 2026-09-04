//! Gateway-side handling of projects.
//!
//! Like scheduling, a project outlives any one thread, so the gateway answers
//! `project/*` itself rather than relaying to the app server, which is scoped
//! to a single conversation.

use opencli_core::memory;
use opencli_core::projects;
use serde_json::Value;
use serde_json::json;
use std::path::Path;
use std::path::PathBuf;

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
        "project/files" => files(opencli_home, &params),
        "project/setAccess" => set_access(opencli_home, &params),
        "project/templates" => Ok(templates()),
        "project/fromTemplate" => from_template(opencli_home, &params),
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
        "connectors": project.connectors,
        "acceptsFrom": project.accepts_from,
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

/// What is at the top level of a project's directory.
///
/// One level only. A project directory is a source tree; walking it would
/// mean reading thousands of files to render a page nobody asked to be
/// exhaustive.
fn files(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let id = required_id(params)?;
    let project =
        projects::get(opencli_home, id).ok_or_else(|| format!("no project with id `{id}`"))?;

    let dir = Path::new(&project.cwd);
    if !dir.is_dir() {
        return Err(format!("`{}` is no longer there", project.cwd));
    }

    let mut data = Vec::new();
    let entries = std::fs::read_dir(dir).map_err(|err| format!("could not read: {err}"))?;
    for entry in entries.flatten() {
        let name = entry.file_name().to_string_lossy().into_owned();
        // Dot files are configuration and noise on a page meant to say what a
        // project holds.
        if name.starts_with('.') {
            continue;
        }
        let is_dir = entry.file_type().map(|kind| kind.is_dir()).unwrap_or(false);
        let size = entry.metadata().ok().map(|meta| meta.len()).unwrap_or(0);
        data.push(json!({ "name": name, "isDir": is_dir, "size": size }));
    }
    // Directories first, then by name: that is how a file browser is read.
    data.sort_by(|a, b| {
        b["isDir"]
            .as_bool()
            .cmp(&a["isDir"].as_bool())
            .then_with(|| a["name"].as_str().cmp(&b["name"].as_str()))
    });
    Ok(json!({ "data": data }))
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
    // A department without a directory would silently run in the gateway's own
    // working directory, which is never what the user meant. Given none, it
    // gets one of its own under the workspace — which is also the boundary
    // `workspace-write` enforces, so finance and engineering cannot write in
    // each other's.
    let owned;
    let cwd = match params
        .get("cwd")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|cwd| !cwd.is_empty())
    {
        Some(given) => given,
        None => {
            let slug = projects::directory_slug(name);
            owned = opencli_core::config::department_workspace(opencli_home, &slug)
                .map_err(|err| format!("could not make a directory for {name}: {err}"))?;
            owned
                .to_str()
                .ok_or("the directory name is not valid UTF-8")?
        }
    };
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

/// The departments that can be created ready to work.
fn templates() -> Value {
    let data: Vec<Value> = opencli_core::templates::TEMPLATES
        .iter()
        .map(|template| {
            json!({
                "id": template.id,
                "name": template.name,
                "description": template.description,
                "bots": template.bots.iter().map(|bot| json!({
                    "name": bot.name,
                    "job": bot.job,
                    "duties": bot.duties.iter().map(|duty| json!({
                        "name": duty.name,
                        "what": duty.what,
                        "rules": duty.rules,
                        "escalateWhen": duty.escalate_when,
                        "intervalSeconds": duty.interval_seconds,
                    })).collect::<Vec<_>>(),
                })).collect::<Vec<_>>(),
                // Named so somebody can see what will appear in their
                // workspace before it does.
                "samples": template.samples.iter().map(|sample| sample.name).collect::<Vec<_>>(),
            })
        })
        .collect();
    json!({ "data": data })
}

/// Create a department from a template: its bots, their duties, and the files
/// those duties work on.
fn from_template(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let id = params
        .get("template")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|id| !id.is_empty())
        .ok_or("template is required")?;

    let applied = opencli_core::templates::apply(opencli_home, id)
        .map_err(|err| format!("could not set up `{id}`: {err}"))?;
    Ok(json!({
        "department": project_json(&applied.department),
        "bots": applied.bots.len(),
        "duties": applied.duties.len(),
    }))
}

/// Change what a department may reach and who may reach it.
///
/// A list given as `null` is left alone, so a client can set the connectors
/// without also declaring the messaging policy — and cannot wipe one by
/// forgetting to send it.
fn set_access(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let id = required_id(params)?;
    let names = |key: &str| -> Option<Vec<String>> {
        params.get(key)?.as_array().map(|items| {
            items
                .iter()
                .filter_map(Value::as_str)
                .map(str::trim)
                .filter(|name| !name.is_empty())
                .map(str::to_string)
                .collect()
        })
    };

    let updated = projects::set_access(opencli_home, id, names("connectors"), names("acceptsFrom"))
        .map_err(|err| format!("could not save: {err}"))?
        .ok_or_else(|| format!("no project with id `{id}`"))?;
    Ok(project_json(&updated))
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
    fn should_never_leave_a_department_running_wherever_the_gateway_started() {
        // This used to be an error, on the reasoning that a project without a
        // directory would run wherever the gateway happened to be started
        // from. The reasoning holds; refusing was the wrong remedy, because
        // the answer is not for the person to supply a path but for the
        // department to have one of its own — which is also the boundary
        // `workspace-write` enforces between departments.
        let dir = tempdir().expect("tempdir");
        let reply = call(
            r#"{"method":"project/create","id":1,"params":{"name":"x"}}"#,
            dir.path(),
        );
        let cwd = reply["result"]["cwd"]
            .as_str()
            .expect("a directory of its own");
        assert!(std::path::Path::new(cwd).is_dir());
        assert!(cwd.starts_with(&dir.path().to_string_lossy().to_string()));
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
            assert!(
                reply["error"].is_object(),
                "{method} should report an error"
            );
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
        assert!(
            reply["error"]["message"]
                .as_str()
                .is_some_and(|message| message.contains("does not exist"))
        );
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
    fn should_list_what_is_at_the_top_of_a_project_directory() {
        let dir = tempdir().expect("tempdir");
        let work = dir.path().join("work");
        std::fs::create_dir_all(work.join("src")).expect("mkdir");
        std::fs::write(work.join("README.md"), "hello").expect("write");
        std::fs::write(work.join(".hidden"), "x").expect("write");

        let created = call(
            &format!(
                r#"{{"method":"project/create","id":1,"params":
                   {{"name":"Work","cwd":"{}"}}}}"#,
                work.display()
            ),
            dir.path(),
        );
        let id = created["result"]["id"].as_str().expect("id").to_string();

        let listed = call(
            &format!(r#"{{"method":"project/files","id":2,"params":{{"id":"{id}"}}}}"#),
            dir.path(),
        );
        let rows = listed["result"]["data"].as_array().expect("data");
        // Directories first, and dot files left out as configuration noise.
        assert_eq!(rows[0]["name"], "src");
        assert_eq!(rows[0]["isDir"], true);
        assert_eq!(rows[1]["name"], "README.md");
        assert_eq!(rows.len(), 2);
    }

    #[test]
    fn should_say_when_a_projects_directory_has_gone_away() {
        // A project outlives its folder if the folder is moved or deleted, and
        // an empty file list would read as an empty project.
        let dir = tempdir().expect("tempdir");
        let gone = dir.path().join("gone");
        std::fs::create_dir_all(&gone).expect("mkdir");
        let created = call(
            &format!(
                r#"{{"method":"project/create","id":1,"params":{{"name":"G","cwd":"{}"}}}}"#,
                gone.display()
            ),
            dir.path(),
        );
        let id = created["result"]["id"].as_str().expect("id").to_string();
        std::fs::remove_dir_all(&gone).expect("remove");

        let listed = call(
            &format!(r#"{{"method":"project/files","id":2,"params":{{"id":"{id}"}}}}"#),
            dir.path(),
        );
        assert!(
            listed["error"]["message"]
                .as_str()
                .is_some_and(|message| message.contains("no longer there"))
        );
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
        assert_eq!(
            pinned["result"]["name"], "Site",
            "pinning changes nothing else"
        );
    }

    #[test]
    fn should_report_when_a_project_was_last_used() {
        let dir = tempdir().expect("tempdir");
        create_one(dir.path());
        let listed = call(r#"{"method":"project/list","id":2}"#, dir.path());
        assert!(
            listed["result"]["data"][0]["updatedAt"]
                .as_u64()
                .is_some_and(|at| at > 0)
        );
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
        assert!(
            listed["result"]["data"]
                .as_array()
                .expect("data")
                .is_empty()
        );
    }

    #[test]
    fn should_give_a_department_a_directory_of_its_own_when_none_was_chosen() {
        // The boundary `workspace-write` enforces. Left to default to the home
        // directory, as it used to, every department would share one.
        let dir = tempdir().expect("tempdir");
        let created = call(
            r#"{"method":"project/create","id":1,"params":{"name":"Finance"}}"#,
            dir.path(),
        );
        let cwd = created["result"]["cwd"].as_str().expect("cwd");
        assert!(cwd.ends_with("workspace/finance"), "got {cwd}");
        assert!(std::path::Path::new(cwd).is_dir());
    }

    #[test]
    fn should_keep_two_departments_out_of_each_others_directory() {
        let dir = tempdir().expect("tempdir");
        let one = call(
            r#"{"method":"project/create","id":1,"params":{"name":"Finance"}}"#,
            dir.path(),
        );
        let two = call(
            r#"{"method":"project/create","id":2,"params":{"name":"Engineering"}}"#,
            dir.path(),
        );
        assert_ne!(one["result"]["cwd"], two["result"]["cwd"]);
    }

    #[test]
    fn should_report_a_departments_access_as_it_is_set() {
        let dir = tempdir().expect("tempdir");
        let created = call(
            r#"{"method":"project/create","id":1,"params":{"name":"Finance"}}"#,
            dir.path(),
        );
        let id = created["result"]["id"].as_str().expect("id");

        // Nothing named yet: every connector, no inbound department.
        assert_eq!(created["result"]["connectors"], serde_json::json!([]));
        assert_eq!(created["result"]["acceptsFrom"], serde_json::json!([]));

        let set = call(
            &format!(
                r#"{{"method":"project/setAccess","id":2,"params":
                    {{"id":"{id}","connectors":["gmail","slack"]}}}}"#
            ),
            dir.path(),
        );
        assert_eq!(
            set["result"]["connectors"],
            serde_json::json!(["gmail", "slack"])
        );
        // Not sent, so not wiped.
        assert_eq!(set["result"]["acceptsFrom"], serde_json::json!([]));
    }

    #[test]
    fn should_offer_the_departments_that_come_ready_to_work() {
        let dir = tempdir().expect("tempdir");
        let offered = call(r#"{"method":"project/templates","id":1}"#, dir.path());
        let rows = offered["result"]["data"].as_array().expect("data");
        assert!(!rows.is_empty());
        // The files are named, so somebody can see what will land in their
        // workspace before it does.
        assert!(rows.iter().any(|row| {
            row["samples"]
                .as_array()
                .is_some_and(|samples| !samples.is_empty())
        }));
    }

    #[test]
    fn should_create_a_department_that_already_has_something_to_do() {
        let dir = tempdir().expect("tempdir");
        let made = call(
            r#"{"method":"project/fromTemplate","id":1,"params":{"template":"finance"}}"#,
            dir.path(),
        );
        assert_eq!(made["result"]["department"]["name"], "Finance");
        assert_eq!(made["result"]["bots"], 3);
        assert_eq!(made["result"]["duties"], 2);

        // And the files those duties work on are there, which is the whole
        // difference between a department that works and one that explains
        // there is no ledger.
        let cwd = made["result"]["department"]["cwd"].as_str().expect("cwd");
        assert!(std::path::Path::new(cwd).join("ledger.csv").is_file());
    }

    #[test]
    fn should_refuse_a_template_nobody_wrote() {
        let dir = tempdir().expect("tempdir");
        let reply = call(
            r#"{"method":"project/fromTemplate","id":1,"params":{"template":"no-such-department"}}"#,
            dir.path(),
        );
        assert!(
            reply["error"]["message"]
                .as_str()
                .is_some_and(|message| message.contains("no-such-department"))
        );
    }
}
