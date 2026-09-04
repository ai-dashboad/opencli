//! One bot handing work to another.
//!
//! The engine could already do this — `agent_spawn` makes a child and
//! `agent_send` talks to it — but only downwards, only to something the
//! spawner is holding an id for, and only for as long as that conversation is
//! open. Bots that outlive a session and work beside each other need to reach
//! each other by name.
//!
//! What makes that safe rather than alarming is three refusals, and they are
//! the substance of this module.
//!
//! **Depth.** A chain is capped. Without it, two bots that each answer the
//! other run until somebody notices — and nobody is watching a background
//! queue at four in the morning.
//!
//! **Repetition.** A bot may appear a few times in one chain and not many. A→B→A
//! is a colleague reporting back; A→B→A→B→A is a loop that has not worked out
//! it is one, and a hop cap alone would let it run to the cap every time.
//!
//! **Permission.** A department decides who may send work into it. Isolating
//! finance's directory from engineering's and then letting either department's
//! bots drive the other's would be isolation in name only.
//!
//! The cap is also the budget. Every hop is a model run with a real cost, and
//! keeping one number for "how far may this go" avoids the case where the hops
//! are allowed and the spending is not, which is a difference nobody can act
//! on.

use serde::Deserialize;
use serde::Serialize;
use std::path::Path;
use std::path::PathBuf;

use crate::bots;
use crate::projects;
use crate::scheduled::now_seconds;

const STORE_FILE: &str = "handoffs.json";

/// Names the chain a process belongs to, and how deep it already is.
///
/// In the environment rather than in the model's hands, for the reason the
/// duty id is: a model that could name its own chain could also start a fresh
/// one on every hop and never reach the cap.
pub const CHAIN_ENV: &str = "OPENCLI_CHAIN";
pub const HOP_ENV: &str = "OPENCLI_HOP";

/// How far one piece of work may travel before it has to stop and involve a
/// person.
pub const MAX_HOPS: u32 = 8;

/// How often one bot may appear in a single chain.
pub const MAX_APPEARANCES: usize = 3;

/// Where this process sits in a chain, if it is in one.
pub fn current_chain() -> Option<(String, u32)> {
    let chain = std::env::var(CHAIN_ENV)
        .ok()
        .map(|id| id.trim().to_string())
        .filter(|id| !id.is_empty())?;
    let hop = std::env::var(HOP_ENV)
        .ok()
        .and_then(|hop| hop.trim().parse::<u32>().ok())
        .unwrap_or(0);
    Some((chain, hop))
}

/// One bot handing work to another.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Handoff {
    pub id: String,
    /// Groups everything that followed from one original piece of work.
    pub chain: String,
    /// How many handoffs deep this is, counting from one.
    pub hop: u32,
    pub from_bot: String,
    pub to_bot: String,
    /// What the sender did, so the receiver is not guessing.
    pub did: String,
    /// Files it produced, which is what the receiver actually works on.
    #[serde(default)]
    pub artifacts: Vec<String>,
    /// What it is asking for.
    pub next: String,
    pub at: u64,
    /// The queued run this became.
    #[serde(default)]
    pub run: Option<String>,
}

/// What is being handed over: what was done, what it produced, what is wanted.
///
/// One value rather than three arguments, because they are one thing — the
/// message — and every caller has all three or none.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Work {
    pub did: String,
    pub artifacts: Vec<String>,
    pub next: String,
}

/// Why a handoff was refused, in words the sending bot can act on.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Refusal {
    NoSuchBot(String),
    NotAllowed { to: String, department: String },
    TooDeep { hops: u32 },
    GoingInCircles { bot: String },
    ToItself,
}

impl std::fmt::Display for Refusal {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Refusal::NoSuchBot(address) => {
                write!(f, "there is no bot at `{address}`")
            }
            Refusal::NotAllowed { to, department } => write!(
                f,
                "`{to}` is in {department}, which does not accept work from your department. \
                 Ask the person who set this up to allow it, or do the work yourself."
            ),
            Refusal::TooDeep { hops } => write!(
                f,
                "this work has already been handed on {hops} times. Stop and report what you \
                 have, rather than passing it further."
            ),
            Refusal::GoingInCircles { bot } => write!(
                f,
                "`{bot}` has already been given this work {MAX_APPEARANCES} times in this \
                 chain. Something is going round; stop and report what you have."
            ),
            Refusal::ToItself => {
                write!(
                    f,
                    "you cannot hand work to yourself; just carry on doing it"
                )
            }
        }
    }
}

fn store_path(opencli_home: &Path) -> PathBuf {
    opencli_home.join(STORE_FILE)
}

pub fn load(opencli_home: &Path) -> Vec<Handoff> {
    std::fs::read_to_string(store_path(opencli_home))
        .ok()
        .and_then(|contents| serde_json::from_str(&contents).ok())
        .unwrap_or_default()
}

pub fn save(opencli_home: &Path, handoffs: &[Handoff]) -> std::io::Result<()> {
    std::fs::write(
        store_path(opencli_home),
        serde_json::to_string_pretty(handoffs)?,
    )
}

/// Everything that followed from one original piece of work, in order.
pub fn chain(opencli_home: &Path, chain: &str) -> Vec<Handoff> {
    let mut all: Vec<Handoff> = load(opencli_home)
        .into_iter()
        .filter(|handoff| handoff.chain == chain)
        .collect();
    all.sort_by_key(|handoff| (handoff.hop, handoff.at));
    all
}

/// Whether `from` may hand work to the bot at `address`, and to whom.
///
/// Every refusal is decided here, before anything is written or queued, so
/// there is one place to read to know what a bot can and cannot set off.
pub fn may_hand_over(
    opencli_home: &Path,
    from: &bots::Bot,
    address: &str,
    chain_id: Option<&str>,
    hop: u32,
) -> Result<bots::Bot, Refusal> {
    if hop >= MAX_HOPS {
        return Err(Refusal::TooDeep { hops: hop });
    }

    let to = bots::resolve(opencli_home, address, &from.department)
        .ok_or_else(|| Refusal::NoSuchBot(address.to_string()))?;

    if to.id == from.id {
        return Err(Refusal::ToItself);
    }

    let into = projects::get(opencli_home, &to.department)
        .ok_or_else(|| Refusal::NoSuchBot(address.to_string()))?;
    if !projects::accepts_message_from(&into, &from.department) {
        return Err(Refusal::NotAllowed {
            to: to.name,
            department: into.name,
        });
    }

    if let Some(chain_id) = chain_id {
        let seen = chain(opencli_home, chain_id)
            .iter()
            .filter(|handoff| handoff.to_bot == to.id)
            .count();
        if seen >= MAX_APPEARANCES {
            return Err(Refusal::GoingInCircles { bot: to.name });
        }
    }

    Ok(to)
}

/// Write down a handoff that has been allowed.
///
/// `chain_id` is the chain the sender was already part of; without one this is
/// the start of a chain and gets a new id, which is how a bot working on its
/// own behalf begins a cascade that can then be capped.
pub fn record(
    opencli_home: &Path,
    chain_id: Option<&str>,
    hop: u32,
    from: &bots::Bot,
    to: &bots::Bot,
    work: Work,
) -> std::io::Result<Handoff> {
    let at = now_seconds();
    let handoff = Handoff {
        id: format!("hand-{at}-{}", suffix()),
        chain: chain_id
            .map(str::to_string)
            .unwrap_or_else(|| format!("chain-{at}-{}", suffix())),
        hop: hop + 1,
        from_bot: from.id.clone(),
        to_bot: to.id.clone(),
        did: work.did,
        artifacts: work.artifacts,
        next: work.next,
        at,
        run: None,
    };
    let mut all = load(opencli_home);
    all.push(handoff.clone());
    save(opencli_home, &all)?;
    Ok(handoff)
}

/// Attach the run a handoff became, so the chain view can follow it.
pub fn attach_run(opencli_home: &Path, id: &str, run: &str) -> std::io::Result<()> {
    let mut all = load(opencli_home);
    if let Some(handoff) = all.iter_mut().find(|handoff| handoff.id == id) {
        handoff.run = Some(run.to_string());
        save(opencli_home, &all)?;
    }
    Ok(())
}

/// What to send the receiving bot.
///
/// Structured, and in this order, because the receiver reads it cold: who it
/// is from and what they did, then the files — which is what it actually works
/// on — then what is being asked. A handoff written as prose would have to be
/// interpreted before it could be acted on.
pub fn briefing(from: &bots::Bot, handoff: &Handoff) -> String {
    let mut brief = format!("{} has handed you work.\n\nWhat they did:\n", from.name);
    brief.push_str(handoff.did.trim());

    if !handoff.artifacts.is_empty() {
        brief.push_str("\n\nWhat they produced:\n");
        for artifact in &handoff.artifacts {
            brief.push_str(&format!("- {artifact}\n"));
        }
    }

    brief.push_str("\n\nWhat they are asking of you:\n");
    brief.push_str(handoff.next.trim());
    brief.push_str(&format!(
        "\n\nThis is hop {} of at most {MAX_HOPS}. If you hand this on again, say what you \
         did and what is left.",
        handoff.hop
    ));
    brief
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

    fn hire(home: &Path, department: &projects::Project, name: &str) -> bots::Bot {
        bots::create(home, department.id.clone(), name.to_string(), String::new()).expect("hire")
    }

    #[test]
    fn should_let_a_bot_hand_work_to_a_colleague() {
        let dir = tempdir().expect("tempdir");
        let finance = department(dir.path(), "Finance");
        let one = hire(dir.path(), &finance, "Reconciler");
        let two = hire(dir.path(), &finance, "Chaser");

        let allowed = may_hand_over(dir.path(), &one, "chaser", None, 0).expect("allowed");
        assert_eq!(allowed.id, two.id);
    }

    #[test]
    fn should_refuse_work_sent_into_a_department_that_has_not_agreed() {
        // Isolating the directories and then letting either department's bots
        // drive the other's would be isolation in name only.
        let dir = tempdir().expect("tempdir");
        let finance = department(dir.path(), "Finance");
        let engineering = department(dir.path(), "Engineering");
        let sender = hire(dir.path(), &engineering, "Watcher");
        hire(dir.path(), &finance, "Reconciler");

        let refused = may_hand_over(dir.path(), &sender, "finance/reconciler", None, 0)
            .expect_err("should be refused");
        assert!(matches!(refused, Refusal::NotAllowed { .. }));
        // And says what to do about it rather than just no.
        assert!(refused.to_string().contains("Ask the person"));
    }

    #[test]
    fn should_allow_it_once_the_department_has_agreed() {
        let dir = tempdir().expect("tempdir");
        let finance = department(dir.path(), "Finance");
        let engineering = department(dir.path(), "Engineering");
        let sender = hire(dir.path(), &engineering, "Watcher");
        hire(dir.path(), &finance, "Reconciler");
        projects::set_access(dir.path(), &finance.id, None, Some(vec![engineering.id]))
            .expect("allow");

        assert!(may_hand_over(dir.path(), &sender, "finance/reconciler", None, 0).is_ok());
    }

    #[test]
    fn should_stop_a_chain_that_has_gone_far_enough() {
        // Nobody is watching a background queue at four in the morning.
        let dir = tempdir().expect("tempdir");
        let finance = department(dir.path(), "Finance");
        let one = hire(dir.path(), &finance, "A");
        hire(dir.path(), &finance, "B");

        let refused =
            may_hand_over(dir.path(), &one, "b", None, MAX_HOPS).expect_err("should be refused");
        assert!(matches!(refused, Refusal::TooDeep { .. }));
        assert!(refused.to_string().contains("Stop and report"));
    }

    #[test]
    fn should_let_a_colleague_report_back_but_not_go_round_and_round() {
        // A -> B -> A is reporting back. A -> B -> A -> B -> A is a loop that
        // has not worked out that it is one, and a depth cap alone would let it
        // run to the cap every time.
        let dir = tempdir().expect("tempdir");
        let finance = department(dir.path(), "Finance");
        let one = hire(dir.path(), &finance, "A");
        let two = hire(dir.path(), &finance, "B");

        let first = record(
            dir.path(),
            None,
            0,
            &one,
            &two,
            Work {
                did: "did".into(),
                artifacts: vec![],
                next: "next".into(),
            },
        )
        .expect("record");
        let chain_id = first.chain;

        // Twice more is still allowed: a colleague may be asked again.
        for hop in 1..MAX_APPEARANCES as u32 {
            assert!(
                may_hand_over(dir.path(), &one, "b", Some(&chain_id), hop).is_ok(),
                "hop {hop} should still be allowed"
            );
            record(
                dir.path(),
                Some(&chain_id),
                hop,
                &one,
                &two,
                Work {
                    did: "did".into(),
                    artifacts: vec![],
                    next: "next".into(),
                },
            )
            .expect("record");
        }

        let refused = may_hand_over(dir.path(), &one, "b", Some(&chain_id), 3)
            .expect_err("should be refused");
        assert!(matches!(refused, Refusal::GoingInCircles { .. }));
    }

    #[test]
    fn should_count_appearances_within_one_chain_only() {
        // Two unrelated pieces of work must not add up to a loop.
        let dir = tempdir().expect("tempdir");
        let finance = department(dir.path(), "Finance");
        let one = hire(dir.path(), &finance, "A");
        let two = hire(dir.path(), &finance, "B");

        for _ in 0..MAX_APPEARANCES {
            record(
                dir.path(),
                None,
                0,
                &one,
                &two,
                Work {
                    did: "did".into(),
                    artifacts: vec![],
                    next: "next".into(),
                },
            )
            .expect("record");
        }

        // A brand new chain, so nothing counted against it.
        assert!(may_hand_over(dir.path(), &one, "b", None, 0).is_ok());
    }

    #[test]
    fn should_refuse_a_bot_handing_work_to_itself() {
        let dir = tempdir().expect("tempdir");
        let finance = department(dir.path(), "Finance");
        let one = hire(dir.path(), &finance, "A");

        let refused = may_hand_over(dir.path(), &one, "a", None, 0).expect_err("refused");
        assert_eq!(refused, Refusal::ToItself);
    }

    #[test]
    fn should_say_which_address_was_wrong() {
        let dir = tempdir().expect("tempdir");
        let finance = department(dir.path(), "Finance");
        let one = hire(dir.path(), &finance, "A");

        let refused = may_hand_over(dir.path(), &one, "nobody", None, 0).expect_err("refused");
        assert!(refused.to_string().contains("nobody"));
    }

    #[test]
    fn should_start_a_chain_when_there_is_none_and_stay_in_it_after() {
        let dir = tempdir().expect("tempdir");
        let finance = department(dir.path(), "Finance");
        let one = hire(dir.path(), &finance, "A");
        let two = hire(dir.path(), &finance, "B");

        let first = record(
            dir.path(),
            None,
            0,
            &one,
            &two,
            Work {
                did: "did".into(),
                artifacts: vec![],
                next: "next".into(),
            },
        )
        .expect("record");
        assert_eq!(first.hop, 1);

        let second = record(
            dir.path(),
            Some(&first.chain),
            first.hop,
            &two,
            &one,
            Work {
                did: "did".into(),
                artifacts: vec![],
                next: "next".into(),
            },
        )
        .expect("record");
        assert_eq!(second.chain, first.chain);
        assert_eq!(second.hop, 2);
        assert_eq!(chain(dir.path(), &first.chain).len(), 2);
    }

    #[test]
    fn should_tell_the_receiver_what_was_done_and_what_is_wanted() {
        let dir = tempdir().expect("tempdir");
        let finance = department(dir.path(), "Finance");
        let one = hire(dir.path(), &finance, "Reconciler");
        let two = hire(dir.path(), &finance, "Chaser");

        let handoff = record(
            dir.path(),
            None,
            0,
            &one,
            &two,
            Work {
                did: "Reconciled 142 lines; 3 are unmatched.".into(),
                artifacts: vec!["unmatched.csv".into()],
                next: "Chase the three customers.".into(),
            },
        )
        .expect("record");

        let said = briefing(&one, &handoff);
        assert!(said.contains("Reconciler has handed you work"));
        assert!(said.contains("unmatched.csv"), "the files are the work");
        assert!(said.contains("Chase the three customers"));
        assert!(
            said.contains("hop 1 of"),
            "so it knows how much rope is left"
        );
    }

    #[test]
    fn should_read_the_chain_from_the_environment() {
        // Not from the model: one that could name its own chain could start a
        // fresh one every hop and never reach the cap.
        unsafe { std::env::set_var(CHAIN_ENV, "chain-9") };
        unsafe { std::env::set_var(HOP_ENV, "3") };
        assert_eq!(current_chain(), Some(("chain-9".to_string(), 3)));
        unsafe { std::env::remove_var(CHAIN_ENV) };
        unsafe { std::env::remove_var(HOP_ENV) };
        assert!(current_chain().is_none());
    }

    #[test]
    fn should_survive_a_store_that_cannot_be_read() {
        let dir = tempdir().expect("tempdir");
        std::fs::write(store_path(dir.path()), "{ not json").expect("write");
        assert!(load(dir.path()).is_empty());
    }
}
