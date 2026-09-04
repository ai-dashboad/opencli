//! Where background work is allowed to run.
//!
//! A dispatched run is started with `--sandbox workspace-write`, and that
//! sandbox's writable root is the run's working directory. So the directory a
//! run is given is not a convenience — it is the whole of what the run may
//! change.
//!
//! Nothing checked it. A scheduled task created before departments existed
//! carried `cwd = ~`, and had run forty-two times, each of those runs able to
//! write anywhere under the home directory — `.ssh`, `Documents`, `Library` —
//! with nobody asked and nothing said. Changing the default for new
//! conversations did not touch it, because a default is not retroactive.
//!
//! So a directory is allowed when it is one this product already knows about:
//! the workspace, a department's own directory, or somewhere a person has said
//! yes to by name. Everything else stops and asks. The asking is the point —
//! running somewhere unusual is often exactly what was wanted, and the answer
//! is a prompt rather than a refusal.

use serde::Deserialize;
use serde::Serialize;
use std::path::Path;
use std::path::PathBuf;

use opencli_protocol::protocol::AskForApproval;

use crate::projects;
use crate::scheduled::now_seconds;

const STORE_FILE: &str = "allowed-directories.json";

/// A directory somebody has agreed background work may run in.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Allowed {
    pub path: String,
    pub granted_at: u64,
}

fn store_path(opencli_home: &Path) -> PathBuf {
    opencli_home.join(STORE_FILE)
}

pub fn granted(opencli_home: &Path) -> Vec<Allowed> {
    std::fs::read_to_string(store_path(opencli_home))
        .ok()
        .and_then(|contents| serde_json::from_str(&contents).ok())
        .unwrap_or_default()
}

/// Say yes to a directory, for everything that runs there afterwards.
pub fn grant(opencli_home: &Path, path: &Path) -> std::io::Result<Allowed> {
    let entry = Allowed {
        path: settle(path).to_string_lossy().into_owned(),
        granted_at: now_seconds(),
    };
    let mut all = granted(opencli_home);
    if !all.iter().any(|held| held.path == entry.path) {
        all.push(entry.clone());
        std::fs::write(
            store_path(opencli_home),
            serde_json::to_string_pretty(&all)?,
        )?;
    }
    Ok(entry)
}

/// Take it back. Work already running is unaffected; the next run is not.
pub fn revoke(opencli_home: &Path, path: &str) -> std::io::Result<bool> {
    let wanted = settle(Path::new(path)).to_string_lossy().into_owned();
    let mut all = granted(opencli_home);
    let before = all.len();
    all.retain(|held| held.path != wanted);
    let removed = all.len() != before;
    if removed {
        std::fs::write(
            store_path(opencli_home),
            serde_json::to_string_pretty(&all)?,
        )?;
    }
    Ok(removed)
}

/// The path as the filesystem sees it, so two spellings of one directory do
/// not read as two directories.
///
/// `/tmp` and `/private/tmp` are the same place on macOS, and a grant written
/// for one would not answer for the other. Canonicalising fails for a
/// directory that is not there yet, and an unresolvable path is left as it was
/// rather than being treated as allowed.
fn settle(path: &Path) -> PathBuf {
    path.canonicalize().unwrap_or_else(|_| path.to_path_buf())
}

/// Whether `child` is `parent` or sits inside it.
fn within(parent: &Path, child: &Path) -> bool {
    let parent = settle(parent);
    let child = settle(child);
    child == parent || child.starts_with(&parent)
}

/// Why a directory is allowed, for saying so on screen.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Standing {
    /// Inside the workspace every department lives under.
    Workspace,
    /// Inside a department's own directory.
    Department(String),
    /// Named by a person, once.
    Granted,
    /// Not any of those. Ask before running here.
    Unknown,
}

/// Where a directory stands.
///
/// Departments are checked before the workspace so the answer names the
/// department, which is what somebody reading it wants to know — "this runs in
/// Finance", not "this runs somewhere under the workspace".
pub fn standing(opencli_home: &Path, cwd: &Path) -> Standing {
    for department in projects::load(opencli_home) {
        if within(Path::new(&department.cwd), cwd) {
            return Standing::Department(department.name);
        }
    }
    if let Ok(workspace) = crate::config::default_workspace(opencli_home)
        && within(&workspace, cwd)
    {
        return Standing::Workspace;
    }
    if granted(opencli_home)
        .iter()
        .any(|held| within(Path::new(&held.path), cwd))
    {
        return Standing::Granted;
    }
    Standing::Unknown
}

/// Whether background work may run here without asking.
pub fn allowed(opencli_home: &Path, cwd: &Path) -> bool {
    standing(opencli_home, cwd) != Standing::Unknown
}

/// Whether a run in this directory has to stop and ask first.
///
/// `Never` means it does not. Holding a run is itself an approval, and
/// somebody who has turned approvals off has said, in as many words, that they
/// do not want to be stopped — deciding they meant something narrower would be
/// the product overruling a setting it offered.
///
/// Every other policy asks, including `OnFailure`. That one is about a command
/// that has already gone wrong; this is about how much a run could reach
/// before anything goes wrong at all, which is a question that has to be
/// answered in advance or not at all.
pub fn must_ask(opencli_home: &Path, cwd: &Path, policy: AskForApproval) -> bool {
    if policy == AskForApproval::Never {
        return false;
    }
    !allowed(opencli_home, cwd)
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    fn department(home: &Path, name: &str, cwd: &Path) -> projects::Project {
        projects::create(
            home,
            name.to_string(),
            cwd.to_string_lossy().into_owned(),
            String::new(),
            String::new(),
        )
        .expect("department")
    }

    #[test]
    fn should_allow_a_departments_own_directory_and_say_which() {
        let dir = tempdir().expect("tempdir");
        let finance = dir.path().join("finance");
        std::fs::create_dir_all(&finance).expect("mkdir");
        department(dir.path(), "Finance", &finance);

        assert_eq!(
            standing(dir.path(), &finance),
            Standing::Department("Finance".into())
        );
        assert!(allowed(dir.path(), &finance));
    }

    #[test]
    fn should_allow_a_directory_inside_a_department() {
        let dir = tempdir().expect("tempdir");
        let finance = dir.path().join("finance");
        let inner = finance.join("2026").join("august");
        std::fs::create_dir_all(&inner).expect("mkdir");
        department(dir.path(), "Finance", &finance);

        assert!(allowed(dir.path(), &inner));
    }

    #[test]
    fn should_refuse_the_home_directory() {
        // The case this exists for: a scheduled task made before departments
        // existed carried `cwd = ~`, and every run could write anywhere under
        // it.
        let dir = tempdir().expect("tempdir");
        let home = std::env::var("HOME").expect("HOME");
        assert_eq!(standing(dir.path(), Path::new(&home)), Standing::Unknown);
        assert!(!allowed(dir.path(), Path::new(&home)));
    }

    #[test]
    fn should_allow_the_workspace_itself() {
        let dir = tempdir().expect("tempdir");
        let workspace = crate::config::default_workspace(dir.path()).expect("workspace");
        assert_eq!(standing(dir.path(), &workspace), Standing::Workspace);
    }

    #[test]
    fn should_allow_somewhere_a_person_said_yes_to() {
        // Running somewhere unusual is often exactly what was wanted. The
        // answer is a prompt, not a refusal.
        let dir = tempdir().expect("tempdir");
        let elsewhere = dir.path().join("elsewhere");
        std::fs::create_dir_all(&elsewhere).expect("mkdir");

        assert!(!allowed(dir.path(), &elsewhere));
        grant(dir.path(), &elsewhere).expect("grant");
        assert_eq!(standing(dir.path(), &elsewhere), Standing::Granted);
        assert!(allowed(dir.path(), &elsewhere));
    }

    #[test]
    fn should_cover_what_is_inside_a_directory_that_was_granted() {
        let dir = tempdir().expect("tempdir");
        let elsewhere = dir.path().join("elsewhere");
        let inner = elsewhere.join("deep");
        std::fs::create_dir_all(&inner).expect("mkdir");
        grant(dir.path(), &elsewhere).expect("grant");

        assert!(allowed(dir.path(), &inner));
    }

    #[test]
    fn should_not_let_a_grant_leak_upwards() {
        // Saying yes to `~/Projects/site` is not saying yes to `~/Projects`,
        // and certainly not to `~`.
        let dir = tempdir().expect("tempdir");
        let inner = dir.path().join("projects").join("site");
        std::fs::create_dir_all(&inner).expect("mkdir");
        grant(dir.path(), &inner).expect("grant");

        assert!(!allowed(dir.path(), &dir.path().join("projects")));
    }

    #[test]
    fn should_read_two_spellings_of_one_directory_as_one() {
        // `/tmp` and `/private/tmp` are the same place here, and a grant
        // written for one has to answer for the other.
        let dir = tempdir().expect("tempdir");
        let real = dir.path().join("real");
        std::fs::create_dir_all(&real).expect("mkdir");
        grant(dir.path(), &real).expect("grant");

        let roundabout = real.join("..").join("real");
        assert!(allowed(dir.path(), &roundabout));
    }

    #[test]
    fn should_take_a_grant_back() {
        let dir = tempdir().expect("tempdir");
        let elsewhere = dir.path().join("elsewhere");
        std::fs::create_dir_all(&elsewhere).expect("mkdir");
        grant(dir.path(), &elsewhere).expect("grant");

        assert!(revoke(dir.path(), &elsewhere.to_string_lossy()).expect("revoke"));
        assert!(!allowed(dir.path(), &elsewhere));
    }

    #[test]
    fn should_not_record_the_same_directory_twice() {
        let dir = tempdir().expect("tempdir");
        let elsewhere = dir.path().join("elsewhere");
        std::fs::create_dir_all(&elsewhere).expect("mkdir");
        grant(dir.path(), &elsewhere).expect("grant");
        grant(dir.path(), &elsewhere).expect("grant again");

        assert_eq!(granted(dir.path()).len(), 1);
    }

    #[test]
    fn should_name_the_department_rather_than_the_workspace_it_sits_in() {
        // "This runs in Finance" is what somebody reading it wants; "somewhere
        // under the workspace" is true and useless.
        let dir = tempdir().expect("tempdir");
        let workspace = crate::config::default_workspace(dir.path()).expect("workspace");
        let finance = workspace.join("finance");
        std::fs::create_dir_all(&finance).expect("mkdir");
        department(dir.path(), "Finance", &finance);

        assert_eq!(
            standing(dir.path(), &finance),
            Standing::Department("Finance".into())
        );
    }

    #[test]
    fn should_survive_a_store_that_cannot_be_read() {
        let dir = tempdir().expect("tempdir");
        std::fs::write(store_path(dir.path()), "{ not json").expect("write");
        assert!(granted(dir.path()).is_empty());
    }

    #[test]
    fn should_not_hold_anything_when_approvals_are_off() {
        // Holding a run is an approval, and somebody who turned approvals off
        // said they do not want to be stopped. Deciding they meant something
        // narrower would be overruling a setting we offered.
        let dir = tempdir().expect("tempdir");
        let home = std::env::var("HOME").expect("HOME");
        assert!(!must_ask(
            dir.path(),
            Path::new(&home),
            AskForApproval::Never
        ));
    }

    #[test]
    fn should_hold_under_every_policy_that_asks() {
        let dir = tempdir().expect("tempdir");
        let home = std::env::var("HOME").expect("HOME");
        for policy in [
            AskForApproval::UnlessTrusted,
            AskForApproval::OnRequest,
            // Including this one: it is about a command that has already gone
            // wrong, and this is about reach before anything goes wrong.
            AskForApproval::OnFailure,
        ] {
            assert!(
                must_ask(dir.path(), Path::new(&home), policy),
                "{policy:?} should still ask"
            );
        }
    }

    #[test]
    fn should_never_ask_about_a_departments_own_directory() {
        let dir = tempdir().expect("tempdir");
        let finance = dir.path().join("finance");
        std::fs::create_dir_all(&finance).expect("mkdir");
        department(dir.path(), "Finance", &finance);

        for policy in [
            AskForApproval::UnlessTrusted,
            AskForApproval::OnRequest,
            AskForApproval::OnFailure,
            AskForApproval::Never,
        ] {
            assert!(!must_ask(dir.path(), &finance, policy));
        }
    }
}
