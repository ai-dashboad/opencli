//! Recurring tasks.
//!
//! `opencli loop` runs a prompt on an interval, but only for as long as its
//! terminal stays open. A desktop or web session needs tasks that survive being
//! defined once, so they live on disk here and are executed by whichever
//! long-running process is hosting the UI.
//!
//! Deliberately not a cron daemon: tasks run while OpenCLI is running, matching
//! what a locally-hosted agent can honestly promise. A task that must fire when
//! the machine is asleep belongs in the OS scheduler.

use serde::Deserialize;
use serde::Serialize;
use std::path::Path;
use std::path::PathBuf;
use std::time::SystemTime;
use std::time::UNIX_EPOCH;

const STORE_FILE: &str = "scheduled.json";

/// A prompt to run on a fixed interval.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ScheduledTask {
    /// Stable identifier, used to delete or update the task.
    pub id: String,
    /// Short label shown in the UI.
    pub name: String,
    /// The prompt handed to the agent on each run.
    pub prompt: String,
    /// How often to run, in seconds.
    pub interval_seconds: u64,
    /// Directory the task runs in.
    pub cwd: String,
    /// Unix seconds of the last completed run; `None` until it first runs.
    #[serde(default)]
    pub last_run: Option<u64>,
    /// How many times the task has run.
    ///
    /// A timestamp alone cannot answer "how many since I last looked", which
    /// is what a count beside the task in a sidebar is claiming to say.
    #[serde(default)]
    pub run_count: u64,
    /// A paused task is kept but never becomes due.
    #[serde(default = "default_enabled")]
    pub enabled: bool,
}

fn default_enabled() -> bool {
    true
}

pub fn now_seconds() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

impl ScheduledTask {
    /// Whether this task should run at `now`.
    ///
    /// A task that has never run is due immediately, which makes a newly-created
    /// task visibly do something rather than sitting idle for its whole first
    /// interval.
    pub fn is_due(&self, now: u64) -> bool {
        if !self.enabled {
            return false;
        }
        match self.last_run {
            None => true,
            Some(last) => now.saturating_sub(last) >= self.interval_seconds,
        }
    }

    /// Unix seconds when this task next becomes due, for display.
    pub fn next_run(&self) -> Option<u64> {
        if !self.enabled {
            return None;
        }
        Some(match self.last_run {
            None => now_seconds(),
            Some(last) => last.saturating_add(self.interval_seconds),
        })
    }
}

fn store_path(opencli_home: &Path) -> PathBuf {
    opencli_home.join(STORE_FILE)
}

/// Read every stored task. A missing or corrupt file yields an empty list
/// rather than an error: losing the schedule should not stop the app from
/// starting.
pub fn load(opencli_home: &Path) -> Vec<ScheduledTask> {
    std::fs::read_to_string(store_path(opencli_home))
        .ok()
        .and_then(|contents| serde_json::from_str(&contents).ok())
        .unwrap_or_default()
}

pub fn save(opencli_home: &Path, tasks: &[ScheduledTask]) -> std::io::Result<()> {
    let contents = serde_json::to_string_pretty(tasks)?;
    std::fs::write(store_path(opencli_home), contents)
}

/// Add a task, returning it with its generated id.
pub fn create(
    opencli_home: &Path,
    name: String,
    prompt: String,
    interval_seconds: u64,
    cwd: String,
) -> std::io::Result<ScheduledTask> {
    let task = ScheduledTask {
        id: format!("task-{}-{}", now_seconds(), rand_suffix()),
        name,
        prompt,
        interval_seconds,
        cwd,
        last_run: None,
        run_count: 0,
        enabled: true,
    };
    let mut tasks = load(opencli_home);
    tasks.push(task.clone());
    save(opencli_home, &tasks)?;
    Ok(task)
}

/// Remove a task. Returns whether anything was removed.
pub fn delete(opencli_home: &Path, id: &str) -> std::io::Result<bool> {
    let mut tasks = load(opencli_home);
    let before = tasks.len();
    tasks.retain(|task| task.id != id);
    let removed = tasks.len() != before;
    if removed {
        save(opencli_home, &tasks)?;
    }
    Ok(removed)
}

/// A change to an existing task. Every field is optional, and `None` means
/// leave it alone — so a caller who only wants to move a task to a different
/// directory does not have to resend a prompt it never read.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct TaskEdit {
    pub name: Option<String>,
    pub prompt: Option<String>,
    pub interval_seconds: Option<u64>,
    pub cwd: Option<String>,
}

/// Change a stored task, returning it as it now stands.
///
/// This exists because the directory a task runs in was captured when the task
/// was created and there was no way to change it afterwards. Tasks made before
/// the default directory was fixed still carry a home directory, and telling
/// somebody their only options are "delete it and build it again" or "widen
/// what it may touch" is not a real choice.
///
/// `last_run` and `run_count` are deliberately not editable: they are a record
/// of what happened, not settings.
pub fn update(
    opencli_home: &Path,
    id: &str,
    edit: TaskEdit,
) -> std::io::Result<Option<ScheduledTask>> {
    let mut tasks = load(opencli_home);
    let Some(task) = tasks.iter_mut().find(|task| task.id == id) else {
        return Ok(None);
    };
    if let Some(name) = edit.name {
        task.name = name;
    }
    if let Some(prompt) = edit.prompt {
        task.prompt = prompt;
    }
    // A zero interval would make the task due on every tick forever, so it is
    // refused here rather than at each of the several call sites.
    if let Some(interval) = edit.interval_seconds.filter(|each| *each > 0) {
        task.interval_seconds = interval;
    }
    if let Some(cwd) = edit.cwd.filter(|each| !each.trim().is_empty()) {
        task.cwd = cwd;
    }
    let updated = task.clone();
    save(opencli_home, &tasks)?;
    Ok(Some(updated))
}

/// Turn a task on or off without deleting it.
pub fn set_enabled(opencli_home: &Path, id: &str, enabled: bool) -> std::io::Result<bool> {
    let mut tasks = load(opencli_home);
    let Some(task) = tasks.iter_mut().find(|task| task.id == id) else {
        return Ok(false);
    };
    task.enabled = enabled;
    save(opencli_home, &tasks)?;
    Ok(true)
}

/// Record that a task just ran, so the interval is measured from completion.
pub fn mark_ran(opencli_home: &Path, id: &str) -> std::io::Result<()> {
    let mut tasks = load(opencli_home);
    if let Some(task) = tasks.iter_mut().find(|task| task.id == id) {
        task.last_run = Some(now_seconds());
        task.run_count = task.run_count.saturating_add(1);
        save(opencli_home, &tasks)?;
    }
    Ok(())
}

/// Short random suffix so two tasks created in the same second differ.
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

    fn task(interval: u64, last_run: Option<u64>) -> ScheduledTask {
        ScheduledTask {
            id: "t".into(),
            name: "n".into(),
            prompt: "p".into(),
            interval_seconds: interval,
            cwd: "/tmp".into(),
            last_run,
            run_count: 0,
            enabled: true,
        }
    }

    #[test]
    fn should_treat_a_never_run_task_as_due() {
        // Otherwise a new task looks broken for its whole first interval.
        assert!(task(3600, None).is_due(now_seconds()));
    }

    #[test]
    fn should_become_due_only_after_the_interval_elapses() {
        let now = 10_000;
        assert!(!task(600, Some(now - 599)).is_due(now));
        assert!(task(600, Some(now - 600)).is_due(now));
    }

    #[test]
    fn should_never_run_a_disabled_task() {
        let mut disabled = task(1, None);
        disabled.enabled = false;
        assert!(!disabled.is_due(now_seconds()));
        assert_eq!(disabled.next_run(), None);
    }

    #[test]
    fn should_move_a_task_to_another_directory() {
        // The case this was written for: a task created back when new chats
        // started in the home directory.
        let dir = tempdir().expect("tempdir");
        let created = create(dir.path(), "5555".into(), "5555".into(), 3600, "/Users/cw".into())
            .expect("create");

        let moved = update(
            dir.path(),
            &created.id,
            TaskEdit {
                cwd: Some("/Users/cw/.opencli/workspace/finance".into()),
                ..TaskEdit::default()
            },
        )
        .expect("update")
        .expect("the task exists");

        assert_eq!(moved.cwd, "/Users/cw/.opencli/workspace/finance");
        assert_eq!(load(dir.path())[0].cwd, moved.cwd);
    }

    #[test]
    fn should_leave_untouched_fields_alone() {
        let dir = tempdir().expect("tempdir");
        let created =
            create(dir.path(), "Digest".into(), "summarize".into(), 3600, "/tmp".into())
                .expect("create");

        let edited = update(
            dir.path(),
            &created.id,
            TaskEdit {
                cwd: Some("/srv".into()),
                ..TaskEdit::default()
            },
        )
        .expect("update")
        .expect("the task exists");

        assert_eq!(edited.name, "Digest");
        assert_eq!(edited.prompt, "summarize");
        assert_eq!(edited.interval_seconds, 3600);
    }

    #[test]
    fn should_keep_the_record_of_what_already_ran() {
        // Editing is about settings. How many times it ran is history, and an
        // edit that reset the count would quietly erase it.
        let dir = tempdir().expect("tempdir");
        let created =
            create(dir.path(), "n".into(), "p".into(), 60, "/tmp".into()).expect("create");
        mark_ran(dir.path(), &created.id).expect("mark_ran");

        let edited = update(
            dir.path(),
            &created.id,
            TaskEdit {
                name: Some("renamed".into()),
                ..TaskEdit::default()
            },
        )
        .expect("update")
        .expect("the task exists");

        assert_eq!(edited.run_count, 1);
        assert!(edited.last_run.is_some());
    }

    #[test]
    fn should_refuse_an_interval_of_zero() {
        // It would be due on every tick, forever.
        let dir = tempdir().expect("tempdir");
        let created =
            create(dir.path(), "n".into(), "p".into(), 3600, "/tmp".into()).expect("create");

        let edited = update(
            dir.path(),
            &created.id,
            TaskEdit {
                interval_seconds: Some(0),
                ..TaskEdit::default()
            },
        )
        .expect("update")
        .expect("the task exists");

        assert_eq!(edited.interval_seconds, 3600);
    }

    #[test]
    fn should_report_an_unknown_task_rather_than_inventing_one() {
        let dir = tempdir().expect("tempdir");
        let missing = update(dir.path(), "no-such-task", TaskEdit::default()).expect("update");
        assert!(missing.is_none());
    }

    #[test]
    fn should_round_trip_tasks_through_disk() {
        let dir = tempdir().expect("tempdir");
        assert!(load(dir.path()).is_empty());

        let created = create(
            dir.path(),
            "Daily digest".into(),
            "summarize the day".into(),
            86_400,
            "/tmp".into(),
        )
        .expect("create");

        let loaded = load(dir.path());
        assert_eq!(loaded.len(), 1);
        assert_eq!(loaded[0], created);
    }

    #[test]
    fn should_give_tasks_distinct_ids() {
        let dir = tempdir().expect("tempdir");
        let a = create(dir.path(), "a".into(), "p".into(), 60, "/tmp".into()).expect("a");
        let b = create(dir.path(), "b".into(), "p".into(), 60, "/tmp".into()).expect("b");
        assert_ne!(a.id, b.id, "same-second creates must not collide");
        assert_eq!(load(dir.path()).len(), 2);
    }

    #[test]
    fn should_delete_only_the_named_task() {
        let dir = tempdir().expect("tempdir");
        let a = create(dir.path(), "a".into(), "p".into(), 60, "/tmp".into()).expect("a");
        create(dir.path(), "b".into(), "p".into(), 60, "/tmp".into()).expect("b");

        assert!(delete(dir.path(), &a.id).expect("delete"));
        assert!(!delete(dir.path(), "missing").expect("delete missing"));

        let remaining = load(dir.path());
        assert_eq!(remaining.len(), 1);
        assert_eq!(remaining[0].name, "b");
    }

    #[test]
    fn should_measure_the_interval_from_the_last_run() {
        let dir = tempdir().expect("tempdir");
        let created = create(dir.path(), "a".into(), "p".into(), 60, "/tmp".into()).expect("a");
        assert!(created.is_due(now_seconds()));

        mark_ran(dir.path(), &created.id).expect("mark");

        let after = load(dir.path());
        assert!(after[0].last_run.is_some());
        assert!(
            !after[0].is_due(now_seconds()),
            "just ran, so not due again"
        );
    }

    #[test]
    fn should_survive_a_corrupt_store() {
        let dir = tempdir().expect("tempdir");
        std::fs::write(dir.path().join(STORE_FILE), "not json").expect("write");
        // Failing to start because the schedule is unreadable would be worse
        // than losing the schedule.
        assert!(load(dir.path()).is_empty());
    }
}
