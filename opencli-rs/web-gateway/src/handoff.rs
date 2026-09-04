//! Reading back what the bots set off between themselves.
//!
//! Without this the handoff feature is unauditable: work appears in a queue
//! having been asked for by something, and the only record of who asked and why
//! is inside a transcript nobody is reading. A cascade that went wrong at the
//! second hop looks exactly like one that went wrong at the fifth.
//!
//! So a chain is a first-class thing to look at — who handed what to whom, in
//! order, with what came of it.

use opencli_core::bots;
use opencli_core::dispatch;
use opencli_core::handoffs;
use serde_json::Value;
use serde_json::json;
use std::collections::HashMap;
use std::path::Path;

/// Answer a `handoff/*` request, or return `None` to let it pass through.
pub fn handle(raw: &str, opencli_home: &Path) -> Option<String> {
    let message: Value = serde_json::from_str(raw).ok()?;
    let method = message.get("method")?.as_str()?;
    if !method.starts_with("handoff/") {
        return None;
    }
    let id = message.get("id").cloned().unwrap_or(Value::Null);
    let params = message.get("params").cloned().unwrap_or(json!({}));

    let result = match method {
        "handoff/chains" => Ok(chains(opencli_home)),
        "handoff/chain" => chain(opencli_home, &params),
        _ => Err(format!("unknown method `{method}`")),
    };

    Some(match result {
        Ok(value) => json!({ "id": id, "result": value }).to_string(),
        Err(message) => {
            json!({ "id": id, "error": { "code": -32602, "message": message } }).to_string()
        }
    })
}

/// Bot names by id, read once for the whole answer.
///
/// A chain of eight hops touches at most eight bots and would otherwise read
/// the roster eight times to put names on them.
fn roster(opencli_home: &Path) -> HashMap<String, String> {
    bots::load(opencli_home)
        .into_iter()
        .map(|bot| (bot.id, bot.name))
        .collect()
}

/// What happened to the run a handoff became.
///
/// Read from the dispatch store rather than recorded on the handoff, because
/// it changes after the handoff is written and a copy would be the status at
/// the moment of asking rather than now.
fn outcome(runs: &[dispatch::Run], handoff: &handoffs::Handoff) -> Value {
    let Some(id) = &handoff.run else {
        return json!({ "status": "gone" });
    };
    match runs.iter().find(|run| &run.id == id) {
        Some(run) => json!({ "status": run.status, "run": run.id }),
        // Cleared from the list, which happens; saying nothing at all would
        // read as though the work was never started.
        None => json!({ "status": "gone", "run": id }),
    }
}

fn handoff_json(
    names: &HashMap<String, String>,
    runs: &[dispatch::Run],
    handoff: &handoffs::Handoff,
) -> Value {
    let name = |id: &String| names.get(id).cloned().unwrap_or_else(|| "someone".into());
    json!({
        "id": handoff.id,
        "chain": handoff.chain,
        "hop": handoff.hop,
        "from": handoff.from_bot,
        "fromName": name(&handoff.from_bot),
        "to": handoff.to_bot,
        "toName": name(&handoff.to_bot),
        "did": handoff.did,
        "artifacts": handoff.artifacts,
        "next": handoff.next,
        "at": handoff.at,
        "outcome": outcome(runs, handoff),
    })
}

/// Every chain, most recent first, with enough to decide which to open.
fn chains(opencli_home: &Path) -> Value {
    let names = roster(opencli_home);
    let all = handoffs::load(opencli_home);

    let mut grouped: Vec<(String, Vec<handoffs::Handoff>)> = Vec::new();
    for handoff in all {
        match grouped.iter_mut().find(|(id, _)| id == &handoff.chain) {
            Some((_, held)) => held.push(handoff),
            None => grouped.push((handoff.chain.clone(), vec![handoff])),
        }
    }

    let mut data: Vec<Value> = grouped
        .into_iter()
        .map(|(id, mut held)| {
            held.sort_by_key(|handoff| (handoff.hop, handoff.at));
            // Who was involved, in the order they were drawn in, which is how
            // anyone would describe what happened.
            let mut involved: Vec<String> = Vec::new();
            for handoff in &held {
                for bot in [&handoff.from_bot, &handoff.to_bot] {
                    let name = names.get(bot).cloned().unwrap_or_else(|| "someone".into());
                    if !involved.contains(&name) {
                        involved.push(name);
                    }
                }
            }
            let started = held.first().map(|handoff| handoff.at).unwrap_or(0);
            let last = held.last().map(|handoff| handoff.at).unwrap_or(0);
            json!({
                "chain": id,
                "hops": held.len(),
                "involved": involved,
                "startedAt": started,
                "lastAt": last,
                // Whether it reached the point where it had to stop asking
                // others and involve a person.
                "atTheLimit": held.len() as u32 >= handoffs::MAX_HOPS,
            })
        })
        .collect();
    data.sort_by(|a, b| b["lastAt"].as_u64().cmp(&a["lastAt"].as_u64()));
    json!({ "data": data, "maxHops": handoffs::MAX_HOPS })
}

fn chain(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let id = params
        .get("chain")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|id| !id.is_empty())
        .ok_or("chain is required")?;

    let names = roster(opencli_home);
    let runs = dispatch::load(opencli_home);
    let data: Vec<Value> = handoffs::chain(opencli_home, id)
        .iter()
        .map(|handoff| handoff_json(&names, &runs, handoff))
        .collect();
    Ok(json!({ "data": data }))
}

#[cfg(test)]
mod tests {
    use super::handle;
    use opencli_core::bots;
    use opencli_core::handoffs;
    use opencli_core::projects;
    use serde_json::Value;
    use std::path::Path;
    use tempfile::tempdir;

    fn call(raw: &str, home: &Path) -> Value {
        serde_json::from_str(&handle(raw, home).expect("handled")).expect("json")
    }

    fn two_bots(home: &Path) -> (bots::Bot, bots::Bot) {
        let finance = projects::create(
            home,
            "Finance".to_string(),
            home.to_string_lossy().into_owned(),
            String::new(),
            String::new(),
        )
        .expect("department");
        (
            bots::create(home, finance.id.clone(), "Reconciler".into(), String::new())
                .expect("hire"),
            bots::create(home, finance.id, "Chaser".into(), String::new()).expect("hire"),
        )
    }

    fn work(next: &str) -> handoffs::Work {
        handoffs::Work {
            did: "reconciled the ledger".into(),
            artifacts: vec!["unmatched.csv".into()],
            next: next.to_string(),
        }
    }

    #[test]
    fn should_name_who_handed_what_to_whom() {
        // Ids are what is stored and names are what anyone reads. A view that
        // showed `bot-1788…` would be a record nobody checks.
        let dir = tempdir().expect("tempdir");
        let (one, two) = two_bots(dir.path());
        let handoff = handoffs::record(
            dir.path(),
            None,
            0,
            &one,
            &two,
            work("chase the three customers"),
        )
        .expect("record");

        let read = call(
            &format!(
                r#"{{"method":"handoff/chain","id":1,"params":{{"chain":"{}"}}}}"#,
                handoff.chain
            ),
            dir.path(),
        );
        let row = &read["result"]["data"][0];
        assert_eq!(row["fromName"], "Reconciler");
        assert_eq!(row["toName"], "Chaser");
        assert_eq!(row["next"], "chase the three customers");
        assert_eq!(row["artifacts"][0], "unmatched.csv");
        assert_eq!(row["hop"], 1);
    }

    #[test]
    fn should_read_a_chain_in_the_order_it_happened() {
        let dir = tempdir().expect("tempdir");
        let (one, two) = two_bots(dir.path());
        let first =
            handoffs::record(dir.path(), None, 0, &one, &two, work("chase them")).expect("record");
        handoffs::record(
            dir.path(),
            Some(&first.chain),
            first.hop,
            &two,
            &one,
            work("book what I recovered"),
        )
        .expect("record");

        let read = call(
            &format!(
                r#"{{"method":"handoff/chain","id":1,"params":{{"chain":"{}"}}}}"#,
                first.chain
            ),
            dir.path(),
        );
        let rows = read["result"]["data"].as_array().expect("data");
        assert_eq!(rows.len(), 2);
        assert_eq!(rows[0]["hop"], 1);
        assert_eq!(rows[1]["hop"], 2);
        assert_eq!(rows[1]["fromName"], "Chaser");
    }

    #[test]
    fn should_say_a_run_is_gone_rather_than_saying_nothing() {
        // Cleared from the dispatch list, which happens. Reported as absent, it
        // would read as though the work had never been started.
        let dir = tempdir().expect("tempdir");
        let (one, two) = two_bots(dir.path());
        let handoff =
            handoffs::record(dir.path(), None, 0, &one, &two, work("chase")).expect("record");
        handoffs::attach_run(dir.path(), &handoff.id, "run-that-was-cleared").expect("attach");

        let read = call(
            &format!(
                r#"{{"method":"handoff/chain","id":1,"params":{{"chain":"{}"}}}}"#,
                handoff.chain
            ),
            dir.path(),
        );
        assert_eq!(read["result"]["data"][0]["outcome"]["status"], "gone");
    }

    #[test]
    fn should_list_chains_with_who_was_drawn_in() {
        let dir = tempdir().expect("tempdir");
        let (one, two) = two_bots(dir.path());
        handoffs::record(dir.path(), None, 0, &one, &two, work("chase")).expect("record");

        let listed = call(r#"{"method":"handoff/chains","id":1}"#, dir.path());
        let row = &listed["result"]["data"][0];
        assert_eq!(row["hops"], 1);
        assert_eq!(row["involved"][0], "Reconciler");
        assert_eq!(row["involved"][1], "Chaser");
        assert_eq!(row["atTheLimit"], false);
        assert_eq!(listed["result"]["maxHops"], handoffs::MAX_HOPS);
    }

    #[test]
    fn should_mark_a_chain_that_reached_the_limit() {
        // The one a person has to look at: it stopped because it ran out of
        // rope, not because it finished.
        let dir = tempdir().expect("tempdir");
        let (one, two) = two_bots(dir.path());
        let first =
            handoffs::record(dir.path(), None, 0, &one, &two, work("chase")).expect("record");
        for hop in 1..handoffs::MAX_HOPS {
            handoffs::record(
                dir.path(),
                Some(&first.chain),
                hop,
                &one,
                &two,
                work("again"),
            )
            .expect("record");
        }

        let listed = call(r#"{"method":"handoff/chains","id":1}"#, dir.path());
        assert_eq!(listed["result"]["data"][0]["atTheLimit"], true);
    }

    #[test]
    fn should_keep_two_chains_apart() {
        let dir = tempdir().expect("tempdir");
        let (one, two) = two_bots(dir.path());
        handoffs::record(dir.path(), None, 0, &one, &two, work("a")).expect("record");
        handoffs::record(dir.path(), None, 0, &one, &two, work("b")).expect("record");

        let listed = call(r#"{"method":"handoff/chains","id":1}"#, dir.path());
        assert_eq!(listed["result"]["data"].as_array().expect("data").len(), 2);
    }

    #[test]
    fn should_let_other_methods_pass_through() {
        let dir = tempdir().expect("tempdir");
        assert!(handle(r#"{"method":"project/list","id":1}"#, dir.path()).is_none());
    }
}
