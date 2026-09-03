//! Bots: a conversation that keeps a job.
//!
//! A chat is already almost an employee. It remembers what was said, it can be
//! reopened, it can be given standing instructions — what it lacks is a job
//! that outlives the session it was given in. Reopen a chat and the agent has
//! the transcript but no idea it is the one that reconciles the ledger every
//! morning; the instructions went in once, with `startThread`, and resuming
//! never sent them again.
//!
//! So a bot is a record beside the conversation: which department it works in,
//! what its job is, and what it is doing. The conversation stays where it is
//! and stays the thing the person talks to. This only remembers what has to be
//! true again tomorrow.
//!
//! Addresses are `department/bot`, computed from the current names rather than
//! stored, because the address *is* the name — rename the bot and the way you
//! refer to it changes, which is what anyone would expect. Resolution is
//! deliberately forgiving: one bot writing to another should not fail over a
//! capital letter.

use serde::Deserialize;
use serde::Serialize;
use std::path::Path;
use std::path::PathBuf;

use crate::projects;
use crate::scheduled::now_seconds;

const STORE_FILE: &str = "bots.json";

/// What a bot is doing, as far as anyone watching can tell.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub enum BotStatus {
    /// Not working, and nothing waiting for it.
    #[default]
    Idle,
    /// A turn is running.
    Working,
    /// Stopped and asking, and will not move until answered.
    ///
    /// Distinct from `Working` because it is the one status a person has to act
    /// on. A bot that has been waiting an hour and a bot that has been busy an
    /// hour look identical without this, and only one of them is stuck.
    WaitingForYou,
    /// Its last turn failed.
    Errored,
}

/// One bot: a job, and the conversation that holds it.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Bot {
    pub id: String,
    /// The department it works in, by project id.
    pub department: String,
    /// What it is called, in the words of whoever hired it.
    pub name: String,
    /// What it is for. Re-sent as instructions every time its conversation is
    /// opened, which is the whole reason this record exists.
    #[serde(default)]
    pub job: String,
    /// The conversation that is this bot, once it has had one.
    ///
    /// Absent until it is first spoken to: a bot can be defined — named, given
    /// a job — before anyone starts talking to it, and a record that insisted
    /// on a thread would force an empty conversation to be created just to
    /// hold a job description.
    #[serde(default)]
    pub thread_id: Option<String>,
    #[serde(default)]
    pub status: BotStatus,
    #[serde(default)]
    pub created_at: u64,
    #[serde(default)]
    pub updated_at: u64,
}

fn store_path(opencli_home: &Path) -> PathBuf {
    opencli_home.join(STORE_FILE)
}

/// Read every stored bot.
///
/// A missing or unreadable file yields an empty list rather than an error, as
/// with projects: losing the roster should not stop the app starting, and the
/// conversations themselves are on disk regardless.
pub fn load(opencli_home: &Path) -> Vec<Bot> {
    std::fs::read_to_string(store_path(opencli_home))
        .ok()
        .and_then(|contents| serde_json::from_str(&contents).ok())
        .unwrap_or_default()
}

pub fn save(opencli_home: &Path, bots: &[Bot]) -> std::io::Result<()> {
    std::fs::write(
        store_path(opencli_home),
        serde_json::to_string_pretty(bots)?,
    )
}

/// Hire a bot into a department.
pub fn create(
    opencli_home: &Path,
    department: String,
    name: String,
    job: String,
) -> std::io::Result<Bot> {
    let now = now_seconds();
    let bot = Bot {
        id: format!("bot-{now}-{}", suffix()),
        department,
        name,
        job,
        thread_id: None,
        status: BotStatus::Idle,
        created_at: now,
        updated_at: now,
    };
    let mut bots = load(opencli_home);
    bots.push(bot.clone());
    save(opencli_home, &bots)?;
    Ok(bot)
}

pub fn get(opencli_home: &Path, id: &str) -> Option<Bot> {
    load(opencli_home).into_iter().find(|bot| bot.id == id)
}

/// Change a bot's name, job, conversation or status. `None` leaves a field as
/// it is, so one can be saved without sending the rest.
pub fn update(
    opencli_home: &Path,
    id: &str,
    name: Option<String>,
    job: Option<String>,
    thread_id: Option<String>,
    status: Option<BotStatus>,
) -> std::io::Result<Option<Bot>> {
    let mut bots = load(opencli_home);
    let Some(bot) = bots.iter_mut().find(|bot| bot.id == id) else {
        return Ok(None);
    };
    if let Some(name) = name {
        bot.name = name;
    }
    if let Some(job) = job {
        bot.job = job;
    }
    if let Some(thread_id) = thread_id {
        bot.thread_id = Some(thread_id);
    }
    if let Some(status) = status {
        bot.status = status;
    }
    bot.updated_at = now_seconds();
    let updated = bot.clone();
    save(opencli_home, &bots)?;
    Ok(Some(updated))
}

/// Remove a bot. The conversation it held is left on disk.
pub fn delete(opencli_home: &Path, id: &str) -> std::io::Result<bool> {
    let mut bots = load(opencli_home);
    let before = bots.len();
    bots.retain(|bot| bot.id != id);
    let removed = bots.len() != before;
    if removed {
        save(opencli_home, &bots)?;
    }
    Ok(removed)
}

/// The bots of one department, oldest first.
pub fn in_department(opencli_home: &Path, department: &str) -> Vec<Bot> {
    load(opencli_home)
        .into_iter()
        .filter(|bot| bot.department == department)
        .collect()
}

/// How one bot refers to another: `department/bot`.
pub fn address(department_name: &str, bot_name: &str) -> String {
    format!(
        "{}/{}",
        projects::directory_slug(department_name),
        projects::directory_slug(bot_name)
    )
}

/// Find the bot an address points at.
///
/// Forgiving on purpose. This is the name one bot uses to hand work to
/// another, produced by a language model from a job description, and failing
/// over a capital letter or a missing department would turn a handoff into a
/// dead end that reads like the other bot refusing.
///
/// A bare name — `reconciler` rather than `finance/reconciler` — is looked up
/// within `from_department`, since that is the ordinary case and the one a bot
/// is most likely to write.
pub fn resolve(opencli_home: &Path, address: &str, from_department: &str) -> Option<Bot> {
    let departments = projects::load(opencli_home);
    let bots = load(opencli_home);
    let wanted = address.trim().trim_matches('/');

    let (department_part, bot_part) = match wanted.split_once('/') {
        Some((department, bot)) => (Some(projects::directory_slug(department)), bot),
        None => (None, wanted),
    };
    let bot_slug = projects::directory_slug(bot_part);

    bots.into_iter().find(|bot| {
        if projects::directory_slug(&bot.name) != bot_slug {
            return false;
        }
        match &department_part {
            // Named a department: it has to be that one.
            Some(slug) => departments
                .iter()
                .find(|department| department.id == bot.department)
                .is_some_and(|department| &projects::directory_slug(&department.name) == slug),
            // Named no department: its own.
            None => bot.department == from_department,
        }
    })
}

fn suffix() -> String {
    use std::time::SystemTime;
    use std::time::UNIX_EPOCH;
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|since| since.subsec_nanos())
        .unwrap_or(0);
    format!("{nanos:06x}")
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    fn department(home: &Path, name: &str) -> projects::Project {
        projects::create(
            home,
            name.to_string(),
            home.to_string_lossy().into_owned(),
            String::new(),
            String::new(),
        )
        .expect("department")
    }

    #[test]
    fn should_keep_a_bots_job_across_restarts() {
        // The whole reason this store exists. Instructions went in once with
        // `startThread`; reopening the conversation never sent them again, so
        // the bot had the transcript and no idea what it was for.
        let dir = tempdir().expect("tempdir");
        let finance = department(dir.path(), "Finance");
        let hired = create(
            dir.path(),
            finance.id.clone(),
            "Reconciler".to_string(),
            "Match the ledger against the bank statement every morning.".to_string(),
        )
        .expect("hire");

        let read = get(dir.path(), &hired.id).expect("still there");
        assert_eq!(read.job, hired.job);
        assert_eq!(read.status, BotStatus::Idle);
    }

    #[test]
    fn should_let_a_bot_exist_before_anyone_talks_to_it() {
        // Naming a bot and giving it a job is a decision; opening a
        // conversation is a separate one. Requiring a thread would mean
        // creating an empty conversation to hold a job description.
        let dir = tempdir().expect("tempdir");
        let finance = department(dir.path(), "Finance");
        let hired = create(dir.path(), finance.id, "Reconciler".into(), "…".into()).expect("hire");
        assert!(hired.thread_id.is_none());
    }

    #[test]
    fn should_remember_which_conversation_is_which_bot() {
        let dir = tempdir().expect("tempdir");
        let finance = department(dir.path(), "Finance");
        let hired = create(dir.path(), finance.id, "Reconciler".into(), "…".into()).expect("hire");

        let bound = update(
            dir.path(),
            &hired.id,
            None,
            None,
            Some("thread-123".to_string()),
            Some(BotStatus::Working),
        )
        .expect("update")
        .expect("found");

        assert_eq!(bound.thread_id.as_deref(), Some("thread-123"));
        assert_eq!(bound.status, BotStatus::Working);
    }

    #[test]
    fn should_tell_waiting_for_a_person_apart_from_being_busy() {
        // A bot that has been waiting an hour and one that has been busy an
        // hour look identical without this, and only one of them is stuck.
        assert_ne!(BotStatus::WaitingForYou, BotStatus::Working);
    }

    #[test]
    fn should_address_a_bot_by_department_and_name() {
        assert_eq!(address("Finance", "Reconciler"), "finance/reconciler");
        assert_eq!(address("财务部", "对账员"), "财务部/对账员");
    }

    #[test]
    fn should_resolve_a_full_address() {
        let dir = tempdir().expect("tempdir");
        let finance = department(dir.path(), "Finance");
        let hired = create(
            dir.path(),
            finance.id.clone(),
            "Reconciler".into(),
            "…".into(),
        )
        .expect("hire");

        let found = resolve(dir.path(), "finance/reconciler", &finance.id).expect("resolved");
        assert_eq!(found.id, hired.id);
    }

    #[test]
    fn should_resolve_however_the_address_was_capitalised_or_spaced() {
        // Written by a language model from a job description. Failing over a
        // capital letter turns a handoff into a dead end that reads like the
        // other bot refusing.
        let dir = tempdir().expect("tempdir");
        let finance = department(dir.path(), "Finance");
        create(
            dir.path(),
            finance.id.clone(),
            "Reconciler".into(),
            "…".into(),
        )
        .expect("hire");

        for written in [
            "Finance/Reconciler",
            " finance/reconciler ",
            "/finance/reconciler",
        ] {
            assert!(
                resolve(dir.path(), written, &finance.id).is_some(),
                "could not resolve {written:?}"
            );
        }
    }

    #[test]
    fn should_read_a_bare_name_as_a_colleague() {
        let dir = tempdir().expect("tempdir");
        let finance = department(dir.path(), "Finance");
        let engineering = department(dir.path(), "Engineering");
        create(
            dir.path(),
            finance.id.clone(),
            "Reconciler".into(),
            "…".into(),
        )
        .expect("hire");

        // Asked from inside finance, a bare name is the bot beside you.
        assert!(resolve(dir.path(), "reconciler", &finance.id).is_some());
        // Asked from engineering, that name is nobody there.
        assert!(resolve(dir.path(), "reconciler", &engineering.id).is_none());
    }

    #[test]
    fn should_not_confuse_two_bots_of_the_same_name_in_different_departments() {
        let dir = tempdir().expect("tempdir");
        let finance = department(dir.path(), "Finance");
        let engineering = department(dir.path(), "Engineering");
        let finance_bot =
            create(dir.path(), finance.id.clone(), "Watcher".into(), "…".into()).expect("hire");
        let engineering_bot = create(
            dir.path(),
            engineering.id.clone(),
            "Watcher".into(),
            "…".into(),
        )
        .expect("hire");

        assert_eq!(
            resolve(dir.path(), "finance/watcher", &engineering.id)
                .expect("resolved")
                .id,
            finance_bot.id
        );
        assert_eq!(
            resolve(dir.path(), "engineering/watcher", &finance.id)
                .expect("resolved")
                .id,
            engineering_bot.id
        );
    }

    #[test]
    fn should_list_only_one_departments_bots() {
        let dir = tempdir().expect("tempdir");
        let finance = department(dir.path(), "Finance");
        let engineering = department(dir.path(), "Engineering");
        create(dir.path(), finance.id.clone(), "A".into(), String::new()).expect("hire");
        create(
            dir.path(),
            engineering.id.clone(),
            "B".into(),
            String::new(),
        )
        .expect("hire");

        let roster = in_department(dir.path(), &finance.id);
        assert_eq!(roster.len(), 1);
        assert_eq!(roster[0].name, "A");
    }

    #[test]
    fn should_leave_the_conversation_alone_when_a_bot_is_let_go() {
        // The transcript is the person's, not the bot's. Deleting the record
        // loses the job; it must not pretend to have deleted the history.
        let dir = tempdir().expect("tempdir");
        let finance = department(dir.path(), "Finance");
        let hired = create(dir.path(), finance.id, "Reconciler".into(), "…".into()).expect("hire");
        update(
            dir.path(),
            &hired.id,
            None,
            None,
            Some("thread-123".into()),
            None,
        )
        .expect("bind");

        assert!(delete(dir.path(), &hired.id).expect("delete"));
        assert!(get(dir.path(), &hired.id).is_none());
    }

    #[test]
    fn should_survive_a_store_that_cannot_be_read() {
        let dir = tempdir().expect("tempdir");
        std::fs::write(store_path(dir.path()), "{ not json").expect("write");
        assert!(load(dir.path()).is_empty());
    }
}
