//! Duties: work a bot keeps doing, and where it got to.
//!
//! A scheduled task is a prompt and an interval. That is enough to run
//! something repeatedly and not enough to leave anything in someone's care,
//! because it forgets between runs: asked every morning to chase overdue
//! invoices, it chases the same ones every morning. Nobody would call that
//! looking after the receivables.
//!
//! Three things turn repetition into a duty.
//!
//! **State.** Where it got to, written by the bot and read back on the next
//! run. Free-form text by key, because what has to be remembered is different
//! for every duty and inventing a schema would only be inventing the wrong one.
//!
//! **Rules.** What to do, and the numbers that decide — the refund ceiling, the
//! margin floor. Written once, in the words of whoever set the policy, instead
//! of retyped into a prompt every time.
//!
//! **Escalation.** The question a bot stops on, recorded so it can be answered
//! later — from another room, or a phone. A duty holding an unanswered question
//! does not become due again: asking the same thing every hour until someone
//! looks is how a useful interruption turns into something people learn to
//! ignore.

use serde::Deserialize;
use serde::Serialize;
use std::collections::BTreeMap;
use std::path::Path;
use std::path::PathBuf;

use crate::scheduled::now_seconds;

const DUTIES_FILE: &str = "duties.json";
const STATE_FILE: &str = "duty-state.json";
const ESCALATIONS_FILE: &str = "escalations.json";

/// Work one bot keeps doing.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Duty {
    pub id: String,
    /// The bot that performs it.
    pub bot: String,
    pub name: String,
    /// What to do, each time.
    #[serde(default)]
    pub what: String,
    /// How to decide, and the numbers that decide it.
    ///
    /// Kept apart from `what` because it changes on a different clock: the work
    /// is the same every morning and the refund ceiling is a policy someone
    /// revisits. Merged into one prompt, editing the policy means re-reading
    /// the whole instruction to find the number.
    #[serde(default)]
    pub rules: String,
    /// What obliges it to stop and ask rather than decide.
    #[serde(default)]
    pub escalate_when: String,
    pub interval_seconds: u64,
    #[serde(default = "yes")]
    pub enabled: bool,
    #[serde(default)]
    pub last_run: Option<u64>,
    #[serde(default)]
    pub run_count: u64,
    #[serde(default)]
    pub created_at: u64,
    #[serde(default)]
    pub updated_at: u64,
}

fn yes() -> bool {
    true
}

/// A question a bot stopped on, and the answer when it comes.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Escalation {
    pub id: String,
    pub duty: String,
    pub bot: String,
    /// What it needs decided.
    pub question: String,
    /// What it had found when it stopped, so the question can be answered
    /// without reopening the conversation.
    #[serde(default)]
    pub context: String,
    pub asked_at: u64,
    #[serde(default)]
    pub answered_at: Option<u64>,
    #[serde(default)]
    pub answer: Option<String>,
}

impl Escalation {
    pub fn is_open(&self) -> bool {
        self.answered_at.is_none()
    }
}

impl Duty {
    /// Whether this duty should run at `now`.
    ///
    /// `blocked` says a question of its own is still unanswered. A duty that
    /// went on running while it waited would ask again on every interval, and
    /// a person who finds the same question four times has been given a reason
    /// to stop reading them.
    ///
    /// Never run means due now, so a duty just set up visibly does something
    /// rather than sitting idle for its whole first interval.
    pub fn is_due(&self, now: u64, blocked: bool) -> bool {
        if !self.enabled || blocked {
            return false;
        }
        match self.last_run {
            None => true,
            Some(last) => now.saturating_sub(last) >= self.interval_seconds,
        }
    }
}

fn path(opencli_home: &Path, file: &str) -> PathBuf {
    opencli_home.join(file)
}

fn read<T: serde::de::DeserializeOwned + Default>(opencli_home: &Path, file: &str) -> T {
    std::fs::read_to_string(path(opencli_home, file))
        .ok()
        .and_then(|contents| serde_json::from_str(&contents).ok())
        .unwrap_or_default()
}

fn write<T: Serialize>(opencli_home: &Path, file: &str, value: &T) -> std::io::Result<()> {
    std::fs::write(
        path(opencli_home, file),
        serde_json::to_string_pretty(value)?,
    )
}

pub fn load(opencli_home: &Path) -> Vec<Duty> {
    read(opencli_home, DUTIES_FILE)
}

pub fn save(opencli_home: &Path, duties: &[Duty]) -> std::io::Result<()> {
    write(opencli_home, DUTIES_FILE, &duties)
}

pub fn create(
    opencli_home: &Path,
    bot: String,
    name: String,
    what: String,
    interval_seconds: u64,
) -> std::io::Result<Duty> {
    let now = now_seconds();
    let duty = Duty {
        id: format!("duty-{now}-{}", suffix()),
        bot,
        name,
        what,
        rules: String::new(),
        escalate_when: String::new(),
        // A duty that ran continuously would be a loop, not a duty.
        interval_seconds: interval_seconds.max(60),
        enabled: true,
        last_run: None,
        run_count: 0,
        created_at: now,
        updated_at: now,
    };
    let mut duties = load(opencli_home);
    duties.push(duty.clone());
    save(opencli_home, &duties)?;
    Ok(duty)
}

pub fn get(opencli_home: &Path, id: &str) -> Option<Duty> {
    load(opencli_home).into_iter().find(|duty| duty.id == id)
}

pub fn of_bot(opencli_home: &Path, bot: &str) -> Vec<Duty> {
    load(opencli_home)
        .into_iter()
        .filter(|duty| duty.bot == bot)
        .collect()
}

pub fn delete(opencli_home: &Path, id: &str) -> std::io::Result<bool> {
    let mut duties = load(opencli_home);
    let before = duties.len();
    duties.retain(|duty| duty.id != id);
    let removed = duties.len() != before;
    if removed {
        save(opencli_home, &duties)?;
        // The state and the questions belong to the duty; leaving them would
        // hand a duty created later, under a reused id, someone else's notes.
        let mut all_state: BTreeMap<String, DutyState> = read(opencli_home, STATE_FILE);
        all_state.remove(id);
        write(opencli_home, STATE_FILE, &all_state)?;
        let mut open: Vec<Escalation> = read(opencli_home, ESCALATIONS_FILE);
        open.retain(|escalation| escalation.duty != id);
        write(opencli_home, ESCALATIONS_FILE, &open)?;
    }
    Ok(removed)
}

/// Record that a duty ran.
pub fn mark_run(opencli_home: &Path, id: &str) -> std::io::Result<Option<Duty>> {
    let mut duties = load(opencli_home);
    let Some(duty) = duties.iter_mut().find(|duty| duty.id == id) else {
        return Ok(None);
    };
    duty.last_run = Some(now_seconds());
    duty.run_count += 1;
    duty.updated_at = now_seconds();
    let updated = duty.clone();
    save(opencli_home, &duties)?;
    Ok(Some(updated))
}

/// What a duty knows, carried from one run to the next.
#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
pub struct DutyState {
    #[serde(default)]
    pub entries: BTreeMap<String, String>,
    #[serde(default)]
    pub updated_at: u64,
}

pub fn state(opencli_home: &Path, duty: &str) -> DutyState {
    read::<BTreeMap<String, DutyState>>(opencli_home, STATE_FILE)
        .remove(duty)
        .unwrap_or_default()
}

/// Merge entries into a duty's state.
///
/// Merged rather than replaced. A run that only learned one thing should not
/// have to restate everything it already knew to avoid erasing it, and a run
/// that failed halfway must not take the rest of the notes with it. An empty
/// value removes a key, which is how something is deliberately forgotten.
pub fn remember(
    opencli_home: &Path,
    duty: &str,
    entries: BTreeMap<String, String>,
) -> std::io::Result<DutyState> {
    let mut all: BTreeMap<String, DutyState> = read(opencli_home, STATE_FILE);
    let held = all.entry(duty.to_string()).or_default();
    for (key, value) in entries {
        if value.is_empty() {
            held.entries.remove(&key);
        } else {
            held.entries.insert(key, value);
        }
    }
    held.updated_at = now_seconds();
    let updated = held.clone();
    write(opencli_home, STATE_FILE, &all)?;
    Ok(updated)
}

pub fn escalations(opencli_home: &Path) -> Vec<Escalation> {
    read(opencli_home, ESCALATIONS_FILE)
}

/// Questions nobody has answered yet, oldest first.
pub fn open_escalations(opencli_home: &Path) -> Vec<Escalation> {
    let mut open: Vec<Escalation> = escalations(opencli_home)
        .into_iter()
        .filter(Escalation::is_open)
        .collect();
    open.sort_by_key(|escalation| escalation.asked_at);
    open
}

/// Whether this duty is waiting on someone.
pub fn is_blocked(opencli_home: &Path, duty: &str) -> bool {
    escalations(opencli_home)
        .iter()
        .any(|escalation| escalation.duty == duty && escalation.is_open())
}

/// Stop and ask.
///
/// Returns the question already on file when one is open, rather than filing a
/// second: a bot interrupted mid-run and restarted would otherwise ask twice,
/// and the person would have to work out that both are the same question.
pub fn ask(
    opencli_home: &Path,
    duty: String,
    bot: String,
    question: String,
    context: String,
) -> std::io::Result<Escalation> {
    let mut all = escalations(opencli_home);
    if let Some(existing) = all
        .iter()
        .find(|escalation| escalation.duty == duty && escalation.is_open())
    {
        return Ok(existing.clone());
    }
    let now = now_seconds();
    let escalation = Escalation {
        id: format!("ask-{now}-{}", suffix()),
        duty,
        bot,
        question,
        context,
        asked_at: now,
        answered_at: None,
        answer: None,
    };
    all.push(escalation.clone());
    write(opencli_home, ESCALATIONS_FILE, &all)?;
    Ok(escalation)
}

/// Answer a question, unblocking the duty that asked it.
pub fn answer(
    opencli_home: &Path,
    id: &str,
    answer: String,
) -> std::io::Result<Option<Escalation>> {
    let mut all = escalations(opencli_home);
    let Some(escalation) = all.iter_mut().find(|escalation| escalation.id == id) else {
        return Ok(None);
    };
    // Answering twice is a second person deciding the same thing. The first
    // answer stands, because the bot may already have acted on it.
    if escalation.answered_at.is_some() {
        return Ok(Some(escalation.clone()));
    }
    escalation.answered_at = Some(now_seconds());
    escalation.answer = Some(answer);
    let updated = escalation.clone();
    write(opencli_home, ESCALATIONS_FILE, &all)?;
    Ok(Some(updated))
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

    fn a_duty(home: &Path) -> Duty {
        create(
            home,
            "bot-1".to_string(),
            "Reconcile".to_string(),
            "Match the ledger against the statement".to_string(),
            3600,
        )
        .expect("create")
    }

    #[test]
    fn should_run_a_new_duty_at_once_rather_than_after_its_first_interval() {
        let dir = tempdir().expect("tempdir");
        let duty = a_duty(dir.path());
        assert!(duty.is_due(now_seconds(), false));
    }

    #[test]
    fn should_wait_out_the_interval_after_a_run() {
        let dir = tempdir().expect("tempdir");
        let duty = a_duty(dir.path());
        let ran = mark_run(dir.path(), &duty.id)
            .expect("mark")
            .expect("found");

        assert!(!ran.is_due(now_seconds(), false));
        assert!(ran.is_due(now_seconds() + 3600, false));
        assert_eq!(ran.run_count, 1);
    }

    #[test]
    fn should_not_become_due_while_it_is_waiting_on_a_person() {
        // A duty that went on running while it waited would ask again every
        // interval, and someone who finds the same question four times has
        // been given a reason to stop reading them.
        let dir = tempdir().expect("tempdir");
        let duty = a_duty(dir.path());
        assert!(!duty.is_due(now_seconds(), true));
    }

    #[test]
    fn should_never_schedule_a_duty_tighter_than_a_minute() {
        // Continuously is a loop, not a duty.
        let dir = tempdir().expect("tempdir");
        let duty =
            create(dir.path(), "bot-1".into(), "Fast".into(), "go".into(), 0).expect("create");
        assert_eq!(duty.interval_seconds, 60);
    }

    #[test]
    fn should_carry_what_a_run_learned_into_the_next_one() {
        // Without this a duty asked to chase overdue invoices chases the same
        // ones every morning.
        let dir = tempdir().expect("tempdir");
        let duty = a_duty(dir.path());
        remember(
            dir.path(),
            &duty.id,
            BTreeMap::from([("reconciled_to".to_string(), "txn-4821".to_string())]),
        )
        .expect("remember");

        assert_eq!(
            state(dir.path(), &duty.id).entries.get("reconciled_to"),
            Some(&"txn-4821".to_string())
        );
    }

    #[test]
    fn should_merge_notes_rather_than_replace_them() {
        // A run that learned one thing should not have to restate everything
        // it already knew to avoid erasing it.
        let dir = tempdir().expect("tempdir");
        let duty = a_duty(dir.path());
        remember(
            dir.path(),
            &duty.id,
            BTreeMap::from([("a".to_string(), "1".to_string())]),
        )
        .expect("first");
        remember(
            dir.path(),
            &duty.id,
            BTreeMap::from([("b".to_string(), "2".to_string())]),
        )
        .expect("second");

        let held = state(dir.path(), &duty.id);
        assert_eq!(held.entries.get("a"), Some(&"1".to_string()));
        assert_eq!(held.entries.get("b"), Some(&"2".to_string()));
    }

    #[test]
    fn should_forget_a_note_set_to_nothing() {
        let dir = tempdir().expect("tempdir");
        let duty = a_duty(dir.path());
        remember(
            dir.path(),
            &duty.id,
            BTreeMap::from([("a".to_string(), "1".to_string())]),
        )
        .expect("set");
        remember(
            dir.path(),
            &duty.id,
            BTreeMap::from([("a".to_string(), String::new())]),
        )
        .expect("clear");

        assert!(state(dir.path(), &duty.id).entries.is_empty());
    }

    #[test]
    fn should_keep_one_duty_out_of_anothers_notes() {
        let dir = tempdir().expect("tempdir");
        let one = a_duty(dir.path());
        let two = a_duty(dir.path());
        remember(
            dir.path(),
            &one.id,
            BTreeMap::from([("secret".to_string(), "mine".to_string())]),
        )
        .expect("remember");

        assert!(state(dir.path(), &two.id).entries.is_empty());
    }

    #[test]
    fn should_block_a_duty_that_has_asked_something() {
        let dir = tempdir().expect("tempdir");
        let duty = a_duty(dir.path());
        ask(
            dir.path(),
            duty.id.clone(),
            "bot-1".into(),
            "Refund 3800?".into(),
            "invoice 22".into(),
        )
        .expect("ask");

        assert!(is_blocked(dir.path(), &duty.id));
        assert_eq!(open_escalations(dir.path()).len(), 1);
    }

    #[test]
    fn should_not_ask_the_same_thing_twice_while_it_waits() {
        // A bot interrupted mid-run and restarted would otherwise file a second
        // question, and the person would have to work out they are the same.
        let dir = tempdir().expect("tempdir");
        let duty = a_duty(dir.path());
        let first = ask(
            dir.path(),
            duty.id.clone(),
            "bot-1".into(),
            "Refund 3800?".into(),
            String::new(),
        )
        .expect("ask");
        let again = ask(
            dir.path(),
            duty.id.clone(),
            "bot-1".into(),
            "Refund 3800, really?".into(),
            String::new(),
        )
        .expect("ask again");

        assert_eq!(first.id, again.id);
        assert_eq!(open_escalations(dir.path()).len(), 1);
    }

    #[test]
    fn should_unblock_the_duty_once_the_question_is_answered() {
        let dir = tempdir().expect("tempdir");
        let duty = a_duty(dir.path());
        let asked = ask(
            dir.path(),
            duty.id.clone(),
            "bot-1".into(),
            "Refund 3800?".into(),
            String::new(),
        )
        .expect("ask");

        answer(dir.path(), &asked.id, "yes, refund it".into()).expect("answer");

        assert!(!is_blocked(dir.path(), &duty.id));
        assert!(open_escalations(dir.path()).is_empty());
        assert!(duty.is_due(now_seconds(), false));
    }

    #[test]
    fn should_let_the_first_answer_stand() {
        // The bot may already have acted on it; a second person deciding the
        // same thing afterwards is not a correction, it is a race.
        let dir = tempdir().expect("tempdir");
        let duty = a_duty(dir.path());
        let asked = ask(
            dir.path(),
            duty.id.clone(),
            "bot-1".into(),
            "Refund?".into(),
            String::new(),
        )
        .expect("ask");

        answer(dir.path(), &asked.id, "yes".into()).expect("first");
        let second = answer(dir.path(), &asked.id, "no".into())
            .expect("second")
            .expect("found");

        assert_eq!(second.answer.as_deref(), Some("yes"));
    }

    #[test]
    fn should_take_a_duties_notes_and_questions_with_it_when_it_is_deleted() {
        // Left behind, they would be handed to whatever duty came next under a
        // reused id.
        let dir = tempdir().expect("tempdir");
        let duty = a_duty(dir.path());
        remember(
            dir.path(),
            &duty.id,
            BTreeMap::from([("a".to_string(), "1".to_string())]),
        )
        .expect("remember");
        ask(
            dir.path(),
            duty.id.clone(),
            "bot-1".into(),
            "?".into(),
            String::new(),
        )
        .expect("ask");

        assert!(delete(dir.path(), &duty.id).expect("delete"));
        assert!(state(dir.path(), &duty.id).entries.is_empty());
        assert!(open_escalations(dir.path()).is_empty());
    }

    #[test]
    fn should_list_only_one_bots_duties() {
        let dir = tempdir().expect("tempdir");
        a_duty(dir.path());
        create(dir.path(), "bot-2".into(), "Other".into(), "x".into(), 3600).expect("create");

        assert_eq!(of_bot(dir.path(), "bot-1").len(), 1);
    }

    #[test]
    fn should_survive_stores_that_cannot_be_read() {
        let dir = tempdir().expect("tempdir");
        for file in [DUTIES_FILE, STATE_FILE, ESCALATIONS_FILE] {
            std::fs::write(path(dir.path(), file), "{ not json").expect("write");
        }
        assert!(load(dir.path()).is_empty());
        assert!(state(dir.path(), "duty-1").entries.is_empty());
        assert!(escalations(dir.path()).is_empty());
    }
}
