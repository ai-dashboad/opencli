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
}
