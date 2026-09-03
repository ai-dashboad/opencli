//! Projects: a named directory, standing instructions, and the threads that
//! belong to it.
//!
//! A thread already knows the directory it runs in, but nothing carries across
//! threads. Anyone working on the same codebase daily ends up retyping the same
//! context — what the project is, how to build it, what not to touch. A project
//! stores that once and makes it the starting point of every thread opened
//! under it.
//!
//! Threads are referenced by id rather than owned. A project is a grouping over
//! the existing thread store, so deleting a project loses the grouping and none
//! of the conversations.

use serde::Deserialize;
use serde::Serialize;
use std::path::Path;
use std::path::PathBuf;

use crate::scheduled::now_seconds;

const STORE_FILE: &str = "projects.json";

/// A workspace: where work happens, and what the agent should always know
/// about it.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Project {
    /// Stable identifier, used to open, rename, or delete the project.
    pub id: String,
    /// Short label shown in the UI.
    pub name: String,
    /// Directory every thread in this project runs in.
    pub cwd: String,
    /// One line saying what the project is, for the card that lists it.
    ///
    /// Separate from `instructions`: that is what the agent is told, this is
    /// what the user reads. Conflating them would put operating rules on a
    /// card and a human summary into the model's context.
    #[serde(default)]
    pub description: String,
    /// Standing instructions prepended to each thread's context. Empty means
    /// the project only groups threads.
    #[serde(default)]
    pub instructions: String,
    /// Unix seconds the project was created.
    #[serde(default)]
    pub created_at: u64,
    /// Unix seconds it was last changed or opened, for ordering by recency.
    #[serde(default)]
    pub updated_at: u64,
    /// Kept at the top of the list.
    #[serde(default)]
    pub pinned: bool,
    /// Threads opened under this project, oldest first.
    #[serde(default)]
    pub thread_ids: Vec<String>,
    /// Connectors this department's bots may use, by name.
    ///
    /// Empty means every configured connector, which is what every project
    /// created before this field existed gets. That is the permissive reading
    /// and it is the right one for an upgrade: a department that suddenly lost
    /// access to the servers its work depends on would look broken, where one
    /// that keeps it looks unchanged.
    #[serde(default)]
    pub connectors: Vec<String>,
    /// Departments allowed to send messages to this one, by id.
    ///
    /// Empty — the default — means none: a bot may hand work to a bot beside
    /// it and not to one in another department. Isolating the finance
    /// directory from the engineering one and then letting either
    /// department's bots drive the other's would be isolation in name only.
    #[serde(default)]
    pub accepts_from: Vec<String>,
}

/// Turn a department's name into something usable as a directory.
///
/// Departments are named by the person who creates them, in whatever language
/// they think in, and that name becomes a path. Anything not plainly safe in a
/// path is replaced rather than stripped, so two departments cannot collapse
/// into one directory by having their punctuation removed.
pub fn directory_slug(name: &str) -> String {
    let mut slug = String::with_capacity(name.len());
    for character in name.chars() {
        if character.is_ascii_alphanumeric() {
            slug.push(character.to_ascii_lowercase());
        } else if character.is_alphanumeric() {
            // Kept as it is: a department called 财务 should have a directory
            // it can be recognised by, and every filesystem this runs on takes
            // it.
            slug.push(character);
        } else {
            slug.push('-');
        }
    }
    let trimmed = slug.trim_matches('-').to_string();
    if trimmed.is_empty() {
        "department".to_string()
    } else {
        trimmed
    }
}

fn store_path(opencli_home: &Path) -> PathBuf {
    opencli_home.join(STORE_FILE)
}

/// Read every stored project. A missing or corrupt file yields an empty list
/// rather than an error: losing the grouping should not stop the app starting,
/// and the underlying threads are still intact.
pub fn load(opencli_home: &Path) -> Vec<Project> {
    std::fs::read_to_string(store_path(opencli_home))
        .ok()
        .and_then(|contents| serde_json::from_str(&contents).ok())
        .unwrap_or_default()
}

pub fn save(opencli_home: &Path, projects: &[Project]) -> std::io::Result<()> {
    let contents = serde_json::to_string_pretty(projects)?;
    std::fs::write(store_path(opencli_home), contents)
}

/// Add a project, returning it with its generated id.
pub fn create(
    opencli_home: &Path,
    name: String,
    cwd: String,
    instructions: String,
    description: String,
) -> std::io::Result<Project> {
    let now = now_seconds();
    let project = Project {
        id: format!("proj-{}-{}", now, rand_suffix()),
        name,
        cwd,
        description,
        instructions,
        created_at: now,
        updated_at: now,
        pinned: false,
        thread_ids: Vec::new(),
        connectors: Vec::new(),
        accepts_from: Vec::new(),
    };
    let mut projects = load(opencli_home);
    projects.push(project.clone());
    save(opencli_home, &projects)?;
    Ok(project)
}

/// Look up one project.
pub fn get(opencli_home: &Path, id: &str) -> Option<Project> {
    load(opencli_home).into_iter().find(|p| p.id == id)
}

/// Remove a project. Returns whether anything was removed.
///
/// The threads it grouped are left alone — they remain openable from the full
/// chat list.
pub fn delete(opencli_home: &Path, id: &str) -> std::io::Result<bool> {
    let mut projects = load(opencli_home);
    let before = projects.len();
    projects.retain(|project| project.id != id);
    let removed = projects.len() != before;
    if removed {
        save(opencli_home, &projects)?;
    }
    Ok(removed)
}

/// Change a project's name, directory, or standing instructions. Each field is
/// left as-is when `None`, so a UI can save one field without sending the rest.
pub fn update(
    opencli_home: &Path,
    id: &str,
    name: Option<String>,
    cwd: Option<String>,
    instructions: Option<String>,
    description: Option<String>,
    pinned: Option<bool>,
) -> std::io::Result<Option<Project>> {
    let mut projects = load(opencli_home);
    let Some(project) = projects.iter_mut().find(|project| project.id == id) else {
        return Ok(None);
    };
    if let Some(name) = name {
        project.name = name;
    }
    if let Some(cwd) = cwd {
        project.cwd = cwd;
    }
    if let Some(instructions) = instructions {
        project.instructions = instructions;
    }
    if let Some(description) = description {
        project.description = description;
    }
    if let Some(pinned) = pinned {
        project.pinned = pinned;
    }
    project.updated_at = now_seconds();
    let updated = project.clone();
    save(opencli_home, &projects)?;
    Ok(Some(updated))
}

/// Change what a department may reach and who may reach it.
///
/// Separate from `update` rather than two more of its arguments. Renaming a
/// department and changing who may drive its bots are not the same kind of
/// edit: one is a label, the other is the boundary, and the boundary deserves
/// its own call — and its own place to audit — rather than riding along with
/// nine positional parameters.
pub fn set_access(
    opencli_home: &Path,
    id: &str,
    connectors: Option<Vec<String>>,
    accepts_from: Option<Vec<String>>,
) -> std::io::Result<Option<Project>> {
    let mut projects = load(opencli_home);
    let Some(project) = projects.iter_mut().find(|project| project.id == id) else {
        return Ok(None);
    };
    if let Some(connectors) = connectors {
        project.connectors = connectors;
    }
    if let Some(accepts_from) = accepts_from {
        // A department listing itself is harmless and confusing; bots beside
        // each other never needed permission.
        project.accepts_from = accepts_from.into_iter().filter(|from| from != id).collect();
    }
    project.updated_at = now_seconds();
    let updated = project.clone();
    save(opencli_home, &projects)?;
    Ok(Some(updated))
}

/// Whether this department's bots may use a connector.
///
/// An empty list means all of them, which is what every department created
/// before the list existed has. Read the other way — empty meaning none — an
/// upgrade would take away the servers each department's work depends on and
/// look like a product that had broken.
pub fn allows_connector(project: &Project, name: &str) -> bool {
    project.connectors.is_empty()
        || project
            .connectors
            .iter()
            .any(|allowed| allowed.eq_ignore_ascii_case(name))
}

/// Whether a bot in `from_department` may send work into this one.
///
/// Same department, always: handing work to the bot beside you is the ordinary
/// case and asking permission for it would make the feature tiresome enough to
/// be turned off wholesale.
///
/// Another department, only when this one has said so. Isolating finance's
/// directory from engineering's and then letting either department's bots
/// drive the other's would be isolation in name only — and the direction
/// matters: finance deciding to accept work from engineering says nothing
/// about engineering accepting work from finance.
pub fn accepts_message_from(into: &Project, from_department: &str) -> bool {
    into.id == from_department
        || into
            .accepts_from
            .iter()
            .any(|allowed| allowed == from_department)
}

/// Record that a thread belongs to a project.
///
/// Idempotent: a client that re-attaches on every reconnect must not grow the
/// list. Returns whether the project exists.
pub fn attach_thread(opencli_home: &Path, id: &str, thread_id: &str) -> std::io::Result<bool> {
    let mut projects = load(opencli_home);
    let Some(project) = projects.iter_mut().find(|project| project.id == id) else {
        return Ok(false);
    };
    if project
        .thread_ids
        .iter()
        .any(|existing| existing == thread_id)
    {
        return Ok(true);
    }
    project.thread_ids.push(thread_id.to_string());
    // Opening a chat in a project is the commonest way of using one, so it is
    // what "last updated" should mostly reflect.
    project.updated_at = now_seconds();
    save(opencli_home, &projects)?;
    Ok(true)
}

/// Short random suffix so two projects created in the same second differ.
fn rand_suffix() -> String {
    use std::collections::hash_map::RandomState;
    use std::hash::BuildHasher;
    format!(
        "{:x}",
        RandomState::new().hash_one(now_seconds()) & 0xffffff
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    fn make(home: &Path, name: &str) -> Project {
        create(
            home,
            name.into(),
            "/tmp".into(),
            String::new(),
            String::new(),
        )
        .expect("create")
    }

    #[test]
    fn should_return_an_empty_list_when_nothing_is_stored() {
        let dir = tempdir().expect("tempdir");
        assert!(load(dir.path()).is_empty());
    }

    #[test]
    fn should_round_trip_a_project_through_disk() {
        let dir = tempdir().expect("tempdir");
        let created = create(
            dir.path(),
            "Site".into(),
            "/srv/site".into(),
            "Never edit generated files.".into(),
            "The public website.".into(),
        )
        .expect("create");

        let loaded = load(dir.path());
        assert_eq!(loaded, vec![created]);
    }

    #[test]
    fn should_give_each_project_a_distinct_id() {
        let dir = tempdir().expect("tempdir");
        let first = make(dir.path(), "a");
        let second = make(dir.path(), "b");
        assert_ne!(first.id, second.id);
    }

    #[test]
    fn should_update_only_the_fields_that_were_supplied() {
        let dir = tempdir().expect("tempdir");
        let created = create(
            dir.path(),
            "Old".into(),
            "/a".into(),
            "keep me".into(),
            "also keep me".into(),
        )
        .expect("create");

        let updated = update(
            dir.path(),
            &created.id,
            Some("New".into()),
            None,
            None,
            None,
            None,
        )
        .expect("update")
        .expect("the project exists");

        assert_eq!(updated.name, "New");
        assert_eq!(updated.cwd, "/a", "an omitted field is left alone");
        assert_eq!(updated.instructions, "keep me");
        assert_eq!(updated.description, "also keep me");
    }

    #[test]
    fn should_report_an_unknown_id_rather_than_creating_one() {
        let dir = tempdir().expect("tempdir");
        assert!(
            update(dir.path(), "nope", Some("x".into()), None, None, None, None)
                .expect("update")
                .is_none()
        );
        assert!(!delete(dir.path(), "nope").expect("delete"));
        assert!(!attach_thread(dir.path(), "nope", "t1").expect("attach"));
    }

    #[test]
    fn should_attach_a_thread_once_however_often_it_is_re_attached() {
        let dir = tempdir().expect("tempdir");
        let created = make(dir.path(), "p");

        assert!(attach_thread(dir.path(), &created.id, "t1").expect("attach"));
        assert!(attach_thread(dir.path(), &created.id, "t1").expect("attach again"));
        assert!(attach_thread(dir.path(), &created.id, "t2").expect("attach other"));

        let stored = get(dir.path(), &created.id).expect("the project exists");
        assert_eq!(stored.thread_ids, vec!["t1", "t2"]);
    }

    #[test]
    fn should_keep_the_other_projects_when_one_is_deleted() {
        let dir = tempdir().expect("tempdir");
        let first = make(dir.path(), "a");
        let second = make(dir.path(), "b");

        assert!(delete(dir.path(), &first.id).expect("delete"));

        let remaining = load(dir.path());
        assert_eq!(remaining.len(), 1);
        assert_eq!(remaining[0].id, second.id);
    }

    #[test]
    fn should_move_a_project_up_the_list_when_a_chat_is_opened_in_it() {
        // Opening a chat is the commonest way of using a project, so it is
        // what ordering by recency should mostly reflect.
        let dir = tempdir().expect("tempdir");
        let created = make(dir.path(), "p");

        let mut stored = load(dir.path());
        stored[0].updated_at = 0;
        save(dir.path(), &stored).expect("save");

        attach_thread(dir.path(), &created.id, "t1").expect("attach");
        assert!(get(dir.path(), &created.id).expect("exists").updated_at > 0);
    }

    #[test]
    fn should_pin_a_project_without_touching_anything_else() {
        let dir = tempdir().expect("tempdir");
        let created = make(dir.path(), "p");

        let pinned = update(dir.path(), &created.id, None, None, None, None, Some(true))
            .expect("update")
            .expect("the project exists");
        assert!(pinned.pinned);
        assert_eq!(pinned.name, "p");
    }

    #[test]
    fn should_ignore_a_corrupt_store_instead_of_failing_to_start() {
        let dir = tempdir().expect("tempdir");
        std::fs::write(store_path(dir.path()), "{ not json").expect("write");
        assert!(load(dir.path()).is_empty());
    }

    fn department(home: &std::path::Path, name: &str) -> Project {
        create(
            home,
            name.to_string(),
            home.to_string_lossy().into_owned(),
            String::new(),
            String::new(),
        )
        .expect("create")
    }

    #[test]
    fn should_let_a_department_use_every_connector_until_it_says_otherwise() {
        // What every department created before the list existed has. Reading
        // an empty list as "none" would take away the servers each
        // department's work depends on, on upgrade, and look like a break.
        let dir = tempdir().expect("tempdir");
        let finance = department(dir.path(), "Finance");
        assert!(allows_connector(&finance, "github"));
        assert!(allows_connector(&finance, "anything at all"));
    }

    #[test]
    fn should_hold_a_department_to_the_connectors_it_lists() {
        let dir = tempdir().expect("tempdir");
        let finance = department(dir.path(), "Finance");
        let finance = set_access(
            dir.path(),
            &finance.id,
            Some(vec!["gmail".to_string()]),
            None,
        )
        .expect("set")
        .expect("found");

        assert!(allows_connector(&finance, "gmail"));
        assert!(
            allows_connector(&finance, "Gmail"),
            "named however it was configured"
        );
        assert!(!allows_connector(&finance, "github"));
    }

    #[test]
    fn should_let_bots_beside_each_other_hand_work_over() {
        // The ordinary case. Asking permission for it would make the feature
        // tiresome enough to be switched off wholesale.
        let dir = tempdir().expect("tempdir");
        let finance = department(dir.path(), "Finance");
        assert!(accepts_message_from(&finance, &finance.id));
    }

    #[test]
    fn should_refuse_work_from_another_department_by_default() {
        // Isolating finance's directory from engineering's and then letting
        // either department's bots drive the other's would be isolation in
        // name only.
        let dir = tempdir().expect("tempdir");
        let finance = department(dir.path(), "Finance");
        let engineering = department(dir.path(), "Engineering");
        assert!(!accepts_message_from(&finance, &engineering.id));
    }

    #[test]
    fn should_accept_work_from_a_department_it_has_named() {
        let dir = tempdir().expect("tempdir");
        let finance = department(dir.path(), "Finance");
        let engineering = department(dir.path(), "Engineering");
        let finance = set_access(
            dir.path(),
            &finance.id,
            None,
            Some(vec![engineering.id.clone()]),
        )
        .expect("set")
        .expect("found");

        assert!(accepts_message_from(&finance, &engineering.id));
        // One direction only: finance accepting work from engineering says
        // nothing about engineering accepting work from finance.
        let engineering = get(dir.path(), &engineering.id).expect("found");
        assert!(!accepts_message_from(&engineering, &finance.id));
    }

    #[test]
    fn should_give_a_department_named_in_any_language_a_usable_directory() {
        assert_eq!(directory_slug("Finance"), "finance");
        assert_eq!(directory_slug("R&D / Platform"), "r-d---platform");
        assert_eq!(directory_slug("财务部"), "财务部");
        // Nothing usable left, and a department still needs somewhere to work.
        assert_eq!(directory_slug("!!!"), "department");
    }

    #[test]
    fn should_not_let_two_departments_collapse_into_one_directory() {
        // Stripping punctuation instead of replacing it would map both of
        // these to `ab`, and one department would write in the other's files.
        assert_ne!(directory_slug("a-b"), directory_slug("ab"));
    }
}
