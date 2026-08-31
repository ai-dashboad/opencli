//! Work the agent does without you watching.
//!
//! A chat turn holds the conversation open until it finishes. Some work should
//! not: a long refactor, a nightly digest, five independent questions asked at
//! once. Those run as *dispatched runs* — each its own `opencli exec` in its own
//! directory, recorded here so it can be listed, read, and cancelled after the
//! window that started it has moved on.
//!
//! Scheduled tasks record into the same store. From the user's side a run is a
//! run; splitting them would mean two lists that mean the same thing.

use serde::Deserialize;
use serde::Serialize;
use std::path::Path;
use std::path::PathBuf;

use crate::scheduled::now_seconds;

const STORE_FILE: &str = "dispatch.json";

/// How many finished runs to keep. Old output is worth little and the file is
/// rewritten on every status change, so an unbounded log would slow every run.
const KEEP_FINISHED: usize = 60;

/// Where a run came from.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum RunSource {
    /// Started by hand from the Dispatch view.
    Dispatch,
    /// Started by sending a message in Cowork mode.
    Cowork,
    /// Fired by the scheduler.
    Scheduled,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum RunStatus {
    Queued,
    Running,
    Done,
    Failed,
    Cancelled,
}

impl RunStatus {
    pub fn is_finished(self) -> bool {
        matches!(self, RunStatus::Done | RunStatus::Failed | RunStatus::Cancelled)
    }
}

/// One background run.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Run {
    pub id: String,
    /// Short label for the list; the prompt when nothing better was given.
    pub title: String,
    pub prompt: String,
    pub cwd: String,
    #[serde(default)]
    pub model: Option<String>,
    pub source: RunSource,
    pub status: RunStatus,
    pub started_at: u64,
    #[serde(default)]
    pub finished_at: Option<u64>,
    /// What the run printed. Trimmed to the tail: the end of a transcript is
    /// what says whether it worked.
    #[serde(default)]
    pub output: String,
    #[serde(default)]
    pub exit_code: Option<i32>,
    /// The scheduled task this run came from, when it came from one.
    #[serde(default)]
    pub task_id: Option<String>,
}

/// Keep the tail of long output. The end says whether it worked; the middle of
/// a build log does not.
const MAX_OUTPUT: usize = 16_000;

pub fn trim_output(output: &str) -> String {
    if output.len() <= MAX_OUTPUT {
        return output.to_string();
    }
    let tail = &output[output.len() - MAX_OUTPUT..];
    // Start at a line boundary so the first line is not a fragment.
    let start = tail.find('\n').map_or(0, |at| at + 1);
    format!("… earlier output trimmed …\n{}", &tail[start..])
}

fn store_path(opencli_home: &Path) -> PathBuf {
    opencli_home.join(STORE_FILE)
}

/// Read every recorded run, newest first.
pub fn load(opencli_home: &Path) -> Vec<Run> {
    let mut runs: Vec<Run> = std::fs::read_to_string(store_path(opencli_home))
        .ok()
        .and_then(|contents| serde_json::from_str(&contents).ok())
        .unwrap_or_default();
    runs.sort_by(|a, b| b.started_at.cmp(&a.started_at));
    runs
}

pub fn save(opencli_home: &Path, runs: &[Run]) -> std::io::Result<()> {
    std::fs::write(store_path(opencli_home), serde_json::to_string_pretty(runs)?)
}

/// Record a new run, queued and waiting to start.
pub fn create(
    opencli_home: &Path,
    title: String,
    prompt: String,
    cwd: String,
    model: Option<String>,
    source: RunSource,
    task_id: Option<String>,
) -> std::io::Result<Run> {
    let run = Run {
        id: format!("run-{}-{}", now_seconds(), rand_suffix()),
        title,
        prompt,
        cwd,
        model,
        source,
        status: RunStatus::Queued,
        started_at: now_seconds(),
        finished_at: None,
        output: String::new(),
        exit_code: None,
        task_id,
    };
    let mut runs = load(opencli_home);
    runs.push(run.clone());
    prune(&mut runs);
    save(opencli_home, &runs)?;
    Ok(run)
}

/// Drop the oldest finished runs, keeping every unfinished one.
///
/// A run still going must never be forgotten just because it is old — that
/// would leave a process nobody can see or stop.
fn prune(runs: &mut Vec<Run>) {
    let finished = runs.iter().filter(|run| run.status.is_finished()).count();
    if finished <= KEEP_FINISHED {
        return;
    }
    let mut to_drop = finished - KEEP_FINISHED;
    let mut ordered: Vec<usize> = (0..runs.len()).collect();
    ordered.sort_by_key(|&index| runs[index].started_at);
    let mut drop_at: Vec<usize> = Vec::new();
    for index in ordered {
        if to_drop == 0 {
            break;
        }
        if runs[index].status.is_finished() {
            drop_at.push(index);
            to_drop -= 1;
        }
    }
    drop_at.sort_unstable();
    for index in drop_at.into_iter().rev() {
        runs.remove(index);
    }
}

/// Move a run to a new status, stamping the finish time when it is one.
pub fn set_status(
    opencli_home: &Path,
    id: &str,
    status: RunStatus,
    exit_code: Option<i32>,
) -> std::io::Result<bool> {
    let mut runs = load(opencli_home);
    let Some(run) = runs.iter_mut().find(|run| run.id == id) else {
        return Ok(false);
    };
    run.status = status;
    run.exit_code = exit_code;
    if status.is_finished() {
        run.finished_at = Some(now_seconds());
    }
    save(opencli_home, &runs)?;
    Ok(true)
}

/// Record what a run printed.
pub fn set_output(opencli_home: &Path, id: &str, output: &str) -> std::io::Result<bool> {
    let mut runs = load(opencli_home);
    let Some(run) = runs.iter_mut().find(|run| run.id == id) else {
        return Ok(false);
    };
    run.output = trim_output(output);
    save(opencli_home, &runs)?;
    Ok(true)
}

/// The runs waiting to start, oldest first so they run in the order asked.
pub fn queued(opencli_home: &Path) -> Vec<Run> {
    let mut runs: Vec<Run> = load(opencli_home)
        .into_iter()
        .filter(|run| run.status == RunStatus::Queued)
        .collect();
    runs.sort_by_key(|run| run.started_at);
    runs
}

/// Forget one run. A run still going is cancelled rather than removed, so the
/// process it started does not become invisible.
pub fn delete(opencli_home: &Path, id: &str) -> std::io::Result<bool> {
    let mut runs = load(opencli_home);
    let before = runs.len();
    runs.retain(|run| run.id != id || !run.status.is_finished());
    let removed = runs.len() != before;
    if removed {
        save(opencli_home, &runs)?;
    }
    Ok(removed)
}

/// Forget every finished run. Returns how many were cleared.
pub fn clear_finished(opencli_home: &Path) -> std::io::Result<usize> {
    let mut runs = load(opencli_home);
    let before = runs.len();
    runs.retain(|run| !run.status.is_finished());
    let cleared = before - runs.len();
    if cleared > 0 {
        save(opencli_home, &runs)?;
    }
    Ok(cleared)
}

fn rand_suffix() -> String {
    use std::collections::hash_map::RandomState;
    use std::hash::BuildHasher;
    format!("{:x}", RandomState::new().hash_one(now_seconds()) & 0xffffff)
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    fn make(home: &Path, title: &str) -> Run {
        create(
            home,
            title.into(),
            "do the thing".into(),
            "/tmp".into(),
            None,
            RunSource::Dispatch,
            None,
        )
        .expect("create")
    }

    #[test]
    fn should_return_no_runs_when_nothing_was_dispatched() {
        let dir = tempdir().expect("tempdir");
        assert!(load(dir.path()).is_empty());
    }

    #[test]
    fn should_start_a_run_queued_so_the_scheduler_can_pick_it_up() {
        let dir = tempdir().expect("tempdir");
        let run = make(dir.path(), "first");
        assert_eq!(run.status, RunStatus::Queued);
        assert_eq!(queued(dir.path()).len(), 1);
    }

    #[test]
    fn should_list_newest_first_but_run_oldest_first() {
        // The list is for reading; the queue is for fairness. They want
        // opposite orders.
        let dir = tempdir().expect("tempdir");
        let mut first = make(dir.path(), "first");
        first.started_at -= 100;
        let mut runs = load(dir.path());
        runs.iter_mut().for_each(|run| {
            if run.id == first.id {
                run.started_at = first.started_at;
            }
        });
        save(dir.path(), &runs).expect("save");
        make(dir.path(), "second");

        assert_eq!(load(dir.path())[0].title, "second");
        assert_eq!(queued(dir.path())[0].title, "first");
    }

    #[test]
    fn should_stamp_the_finish_time_only_when_the_run_ends() {
        let dir = tempdir().expect("tempdir");
        let run = make(dir.path(), "x");

        set_status(dir.path(), &run.id, RunStatus::Running, None).expect("status");
        assert!(load(dir.path())[0].finished_at.is_none());

        set_status(dir.path(), &run.id, RunStatus::Done, Some(0)).expect("status");
        assert!(load(dir.path())[0].finished_at.is_some());
    }

    #[test]
    fn should_keep_the_tail_of_output_that_is_too_long() {
        // The end says whether it worked; the middle of a build log does not.
        let body = "line\n".repeat(8_000);
        let trimmed = trim_output(&body);
        assert!(trimmed.len() < body.len());
        assert!(trimmed.starts_with("… earlier output trimmed …"));
        assert!(trimmed.ends_with("line\n"));
    }

    #[test]
    fn should_leave_short_output_exactly_as_it_was() {
        assert_eq!(trim_output("all good\n"), "all good\n");
    }

    #[test]
    fn should_refuse_to_forget_a_run_that_is_still_going() {
        // Removing it would leave a process nobody can see or stop.
        let dir = tempdir().expect("tempdir");
        let run = make(dir.path(), "x");
        set_status(dir.path(), &run.id, RunStatus::Running, None).expect("status");

        assert!(!delete(dir.path(), &run.id).expect("delete"));
        assert_eq!(load(dir.path()).len(), 1);
    }

    #[test]
    fn should_forget_a_run_that_has_finished() {
        let dir = tempdir().expect("tempdir");
        let run = make(dir.path(), "x");
        set_status(dir.path(), &run.id, RunStatus::Done, Some(0)).expect("status");

        assert!(delete(dir.path(), &run.id).expect("delete"));
        assert!(load(dir.path()).is_empty());
    }

    #[test]
    fn should_clear_finished_runs_and_keep_the_rest() {
        let dir = tempdir().expect("tempdir");
        let done = make(dir.path(), "done");
        make(dir.path(), "still going");
        set_status(dir.path(), &done.id, RunStatus::Done, Some(0)).expect("status");

        assert_eq!(clear_finished(dir.path()).expect("clear"), 1);
        let left = load(dir.path());
        assert_eq!(left.len(), 1);
        assert_eq!(left[0].title, "still going");
    }

    #[test]
    fn should_cap_the_history_without_dropping_unfinished_runs() {
        let dir = tempdir().expect("tempdir");
        let mut runs = Vec::new();
        for index in 0..(KEEP_FINISHED + 10) {
            runs.push(Run {
                id: format!("r{index}"),
                title: format!("r{index}"),
                prompt: "p".into(),
                cwd: "/tmp".into(),
                model: None,
                source: RunSource::Dispatch,
                status: RunStatus::Done,
                started_at: index as u64,
                finished_at: Some(index as u64),
                output: String::new(),
                exit_code: Some(0),
                task_id: None,
            });
        }
        // One old run that never finished must survive the cap.
        runs[0].status = RunStatus::Running;
        runs[0].finished_at = None;
        save(dir.path(), &runs).expect("save");

        make(dir.path(), "new");

        let left = load(dir.path());
        assert!(left.iter().any(|run| run.id == "r0"), "unfinished runs are kept");
        assert!(left.iter().filter(|run| run.status.is_finished()).count() <= KEEP_FINISHED);
    }

    #[test]
    fn should_ignore_a_corrupt_store_instead_of_failing_to_start() {
        let dir = tempdir().expect("tempdir");
        std::fs::write(store_path(dir.path()), "{ not json").expect("write");
        assert!(load(dir.path()).is_empty());
    }
}
