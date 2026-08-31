//! Facts that outlive a conversation.
//!
//! A project carries instructions for one directory; a memory carries a fact
//! that should hold everywhere, or in one project. "I deploy with `just ship`",
//! "never touch the vendored directory", "my staging database is read-only" —
//! things a user would otherwise repeat until they stop bothering and accept
//! being misunderstood.
//!
//! Memories are written by the user, not by the agent. An agent that decides on
//! its own what to remember will eventually persist something wrong, and a
//! wrong permanent fact is worse than no fact: it is invisible, it applies to
//! every future conversation, and the user never agreed to it. Curating the
//! list by hand keeps it small and keeps it true.

use serde::Deserialize;
use serde::Serialize;
use std::path::Path;
use std::path::PathBuf;

use crate::scheduled::now_seconds;

const STORE_FILE: &str = "memory.json";

/// A single remembered fact.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Memory {
    /// Stable identifier, used to edit or delete the fact.
    pub id: String,
    /// The fact itself, in the user's own words.
    pub text: String,
    /// The project this applies to; `None` means every conversation.
    #[serde(default)]
    pub project_id: Option<String>,
    /// Unix seconds the fact was recorded.
    #[serde(default)]
    pub created_at: u64,
}

fn store_path(opencli_home: &Path) -> PathBuf {
    opencli_home.join(STORE_FILE)
}

/// Read every stored fact. A missing or corrupt file yields an empty list: an
/// unreadable memory should degrade the agent's context, not stop it starting.
pub fn load(opencli_home: &Path) -> Vec<Memory> {
    std::fs::read_to_string(store_path(opencli_home))
        .ok()
        .and_then(|contents| serde_json::from_str(&contents).ok())
        .unwrap_or_default()
}

pub fn save(opencli_home: &Path, memories: &[Memory]) -> std::io::Result<()> {
    let contents = serde_json::to_string_pretty(memories)?;
    std::fs::write(store_path(opencli_home), contents)
}

/// Record a fact, returning it with its generated id.
pub fn create(
    opencli_home: &Path,
    text: String,
    project_id: Option<String>,
) -> std::io::Result<Memory> {
    let memory = Memory {
        id: format!("mem-{}-{}", now_seconds(), rand_suffix()),
        text,
        project_id,
        created_at: now_seconds(),
    };
    let mut memories = load(opencli_home);
    memories.push(memory.clone());
    save(opencli_home, &memories)?;
    Ok(memory)
}

/// Reword a fact. Returns `None` when the id is unknown.
pub fn update(opencli_home: &Path, id: &str, text: String) -> std::io::Result<Option<Memory>> {
    let mut memories = load(opencli_home);
    let Some(memory) = memories.iter_mut().find(|memory| memory.id == id) else {
        return Ok(None);
    };
    memory.text = text;
    let updated = memory.clone();
    save(opencli_home, &memories)?;
    Ok(Some(updated))
}

/// Forget a fact. Returns whether anything was removed.
pub fn delete(opencli_home: &Path, id: &str) -> std::io::Result<bool> {
    let mut memories = load(opencli_home);
    let before = memories.len();
    memories.retain(|memory| memory.id != id);
    let removed = memories.len() != before;
    if removed {
        save(opencli_home, &memories)?;
    }
    Ok(removed)
}

/// Forget every fact belonging to a project. Returns how many were removed.
///
/// Called when a project is deleted: its facts can never apply again, but they
/// would still take up the list and confuse anyone reading it.
pub fn forget_project(opencli_home: &Path, project_id: &str) -> std::io::Result<usize> {
    let mut memories = load(opencli_home);
    let before = memories.len();
    memories.retain(|memory| memory.project_id.as_deref() != Some(project_id));
    let removed = before - memories.len();
    if removed > 0 {
        save(opencli_home, &memories)?;
    }
    Ok(removed)
}

/// The facts that apply to a conversation: the global ones, plus the ones
/// belonging to the project it was opened under.
pub fn applicable(opencli_home: &Path, project_id: Option<&str>) -> Vec<Memory> {
    load(opencli_home)
        .into_iter()
        .filter(|memory| match (&memory.project_id, project_id) {
            (None, _) => true,
            (Some(owner), Some(current)) => owner == current,
            (Some(_), None) => false,
        })
        .collect()
}

/// Render the applicable facts as a block to prepend to a thread's context.
///
/// Returns an empty string when there is nothing to say, so a caller can send
/// it unconditionally without adding a stray heading to every conversation.
pub fn as_instructions(memories: &[Memory]) -> String {
    if memories.is_empty() {
        return String::new();
    }
    let mut block = String::from("Things the user has asked you to remember:\n");
    for memory in memories {
        block.push_str("- ");
        block.push_str(memory.text.trim());
        block.push('\n');
    }
    block
}

/// Short random suffix so two facts recorded in the same second differ.
fn rand_suffix() -> String {
    use std::collections::hash_map::RandomState;
    use std::hash::BuildHasher;
    format!("{:x}", RandomState::new().hash_one(now_seconds()) & 0xffffff)
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn should_return_an_empty_list_when_nothing_is_stored() {
        let dir = tempdir().expect("tempdir");
        assert!(load(dir.path()).is_empty());
    }

    #[test]
    fn should_round_trip_a_fact_through_disk() {
        let dir = tempdir().expect("tempdir");
        let created = create(dir.path(), "deploy with just ship".into(), None).expect("create");
        assert_eq!(load(dir.path()), vec![created]);
    }

    #[test]
    fn should_reword_a_fact_without_changing_its_id() {
        let dir = tempdir().expect("tempdir");
        let created = create(dir.path(), "old wording".into(), None).expect("create");

        let updated = update(dir.path(), &created.id, "new wording".into())
            .expect("update")
            .expect("the fact exists");

        assert_eq!(updated.id, created.id);
        assert_eq!(updated.text, "new wording");
    }

    #[test]
    fn should_report_an_unknown_id_rather_than_creating_one() {
        let dir = tempdir().expect("tempdir");
        assert!(update(dir.path(), "nope", "x".into()).expect("update").is_none());
        assert!(!delete(dir.path(), "nope").expect("delete"));
    }

    #[test]
    fn should_forget_only_the_fact_that_was_deleted() {
        let dir = tempdir().expect("tempdir");
        let first = create(dir.path(), "a".into(), None).expect("create");
        let second = create(dir.path(), "b".into(), None).expect("create");

        assert!(delete(dir.path(), &first.id).expect("delete"));

        let remaining = load(dir.path());
        assert_eq!(remaining.len(), 1);
        assert_eq!(remaining[0].id, second.id);
    }

    #[test]
    fn should_apply_a_global_fact_to_every_conversation() {
        let dir = tempdir().expect("tempdir");
        create(dir.path(), "global".into(), None).expect("create");

        assert_eq!(applicable(dir.path(), None).len(), 1);
        assert_eq!(applicable(dir.path(), Some("proj-1")).len(), 1);
    }

    #[test]
    fn should_keep_a_project_fact_out_of_other_conversations() {
        // Leaking one project's facts into another is the failure that would
        // make the whole feature untrustworthy.
        let dir = tempdir().expect("tempdir");
        create(dir.path(), "only here".into(), Some("proj-1".into())).expect("create");

        assert!(applicable(dir.path(), Some("proj-2")).is_empty());
        assert!(applicable(dir.path(), None).is_empty());
        assert_eq!(applicable(dir.path(), Some("proj-1")).len(), 1);
    }

    #[test]
    fn should_forget_a_deleted_projects_facts_but_keep_the_global_ones() {
        // An orphaned fact can never apply again, yet would still clutter the
        // list and read as if it were active.
        let dir = tempdir().expect("tempdir");
        create(dir.path(), "global".into(), None).expect("create");
        create(dir.path(), "a1".into(), Some("proj-1".into())).expect("create");
        create(dir.path(), "a2".into(), Some("proj-1".into())).expect("create");
        create(dir.path(), "b1".into(), Some("proj-2".into())).expect("create");

        assert_eq!(forget_project(dir.path(), "proj-1").expect("forget"), 2);

        let remaining = load(dir.path());
        assert_eq!(remaining.len(), 2);
        assert!(remaining.iter().any(|memory| memory.text == "global"));
        assert!(remaining.iter().any(|memory| memory.text == "b1"));
    }

    #[test]
    fn should_report_nothing_removed_for_a_project_with_no_facts() {
        let dir = tempdir().expect("tempdir");
        create(dir.path(), "global".into(), None).expect("create");
        assert_eq!(forget_project(dir.path(), "proj-1").expect("forget"), 0);
        assert_eq!(load(dir.path()).len(), 1);
    }

    #[test]
    fn should_render_nothing_when_there_is_nothing_to_remember() {
        // An empty heading in every conversation is worse than no heading.
        assert_eq!(as_instructions(&[]), "");
    }

    #[test]
    fn should_render_each_fact_as_its_own_bullet() {
        let dir = tempdir().expect("tempdir");
        create(dir.path(), "  first  ".into(), None).expect("create");
        create(dir.path(), "second".into(), None).expect("create");

        let block = as_instructions(&load(dir.path()));
        assert!(block.contains("- first\n"), "got: {block}");
        assert!(block.contains("- second\n"), "got: {block}");
    }

    #[test]
    fn should_ignore_a_corrupt_store_instead_of_failing_to_start() {
        let dir = tempdir().expect("tempdir");
        std::fs::write(store_path(dir.path()), "{ not json").expect("write");
        assert!(load(dir.path()).is_empty());
    }
}
