//! Gateway-side handling of duties, their notes, and the questions they stop
//! on.
//!
//! All three outlive any one conversation, so they are answered here rather
//! than relayed to an app server scoped to a single thread — and the scheduler
//! that runs them lives beside them for the same reason.

use opencli_core::bots;
use opencli_core::duties;
use serde_json::Value;
use serde_json::json;
use std::collections::BTreeMap;
use std::path::Path;
use std::path::PathBuf;

use opencli_core::dispatch;

/// Answer a `duty/*` request, or return `None` to let it pass through.
pub fn handle(raw: &str, opencli_home: &Path) -> Option<String> {
    let message: Value = serde_json::from_str(raw).ok()?;
    let method = message.get("method")?.as_str()?;
    if !method.starts_with("duty/") {
        return None;
    }
    let id = message.get("id").cloned().unwrap_or(Value::Null);
    let params = message.get("params").cloned().unwrap_or(json!({}));

    let result = match method {
        "duty/list" => list(opencli_home, &params),
        "duty/create" => create(opencli_home, &params),
        "duty/update" => update(opencli_home, &params),
        "duty/delete" => remove(opencli_home, &params),
        "duty/runNow" => run_now(opencli_home, &params),
        "duty/remember" => remember(opencli_home, &params),
        "duty/ask" => ask(opencli_home, &params),
        "duty/answer" => answer(opencli_home, &params),
        "duty/asking" => Ok(asking(opencli_home)),
        _ => Err(format!("unknown method `{method}`")),
    };

    Some(match result {
        Ok(value) => json!({ "id": id, "result": value }).to_string(),
        Err(message) => {
            json!({ "id": id, "error": { "code": -32602, "message": message } }).to_string()
        }
    })
}

/// One duty, with the two things a reader needs that are not fields on it:
/// what it knows, and whether it is waiting on somebody.
fn duty_json(opencli_home: &Path, duty: &duties::Duty) -> Value {
    let state = duties::state(opencli_home, &duty.id);
    json!({
        "id": duty.id,
        "bot": duty.bot,
        "name": duty.name,
        "what": duty.what,
        "rules": duty.rules,
        "escalateWhen": duty.escalate_when,
        "intervalSeconds": duty.interval_seconds,
        "enabled": duty.enabled,
        "lastRun": duty.last_run,
        "runCount": duty.run_count,
        "blocked": duties::is_blocked(opencli_home, &duty.id),
        "knows": state.entries,
        "createdAt": duty.created_at,
        "updatedAt": duty.updated_at,
    })
}

fn escalation_json(escalation: &duties::Escalation) -> Value {
    json!({
        "id": escalation.id,
        "duty": escalation.duty,
        "bot": escalation.bot,
        "question": escalation.question,
        "context": escalation.context,
        "askedAt": escalation.asked_at,
        "answeredAt": escalation.answered_at,
        "answer": escalation.answer,
    })
}

fn required(params: &Value, key: &str) -> Result<String, String> {
    params
        .get(key)
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(str::to_string)
        .ok_or_else(|| format!("{key} is required"))
}

fn list(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let all = match params.get("bot").and_then(Value::as_str) {
        Some(bot) => duties::of_bot(opencli_home, bot),
        None => duties::load(opencli_home),
    };
    let data: Vec<Value> = all
        .iter()
        .map(|duty| duty_json(opencli_home, duty))
        .collect();
    Ok(json!({ "data": data }))
}

fn create(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let bot = required(params, "bot")?;
    // Checked here so the mistake surfaces where it was made rather than on
    // the first tick, hours later, as a run against nobody.
    if bots::get(opencli_home, &bot).is_none() {
        return Err(format!("no bot with id `{bot}`"));
    }
    let name = required(params, "name")?;
    let what = required(params, "what")?;
    let interval = params
        .get("intervalSeconds")
        .and_then(Value::as_u64)
        .unwrap_or(3600);

    let mut duty = duties::create(opencli_home, bot, name, what, interval)
        .map_err(|err| format!("could not save: {err}"))?;

    // Rules and the stopping condition are optional at creation and set the
    // same way as any later edit, so there is one path that writes them.
    let rules = params.get("rules").and_then(Value::as_str);
    let escalate = params.get("escalateWhen").and_then(Value::as_str);
    if rules.is_some() || escalate.is_some() {
        duty = edit(opencli_home, &duty.id, |duty| {
            if let Some(rules) = rules {
                duty.rules = rules.to_string();
            }
            if let Some(escalate) = escalate {
                duty.escalate_when = escalate.to_string();
            }
        })?;
    }
    Ok(duty_json(opencli_home, &duty))
}

/// Apply a change to one duty and save the list.
fn edit(
    opencli_home: &Path,
    id: &str,
    change: impl FnOnce(&mut duties::Duty),
) -> Result<duties::Duty, String> {
    let mut all = duties::load(opencli_home);
    let Some(duty) = all.iter_mut().find(|duty| duty.id == id) else {
        return Err(format!("no duty with id `{id}`"));
    };
    change(duty);
    duty.updated_at = opencli_core::scheduled::now_seconds();
    let updated = duty.clone();
    duties::save(opencli_home, &all).map_err(|err| format!("could not save: {err}"))?;
    Ok(updated)
}

fn update(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let id = required(params, "id")?;
    let text = |key: &str| params.get(key).and_then(Value::as_str).map(str::to_string);
    let updated = edit(opencli_home, &id, |duty| {
        if let Some(name) = text("name") {
            duty.name = name;
        }
        if let Some(what) = text("what") {
            duty.what = what;
        }
        if let Some(rules) = text("rules") {
            duty.rules = rules;
        }
        if let Some(escalate) = text("escalateWhen") {
            duty.escalate_when = escalate;
        }
        if let Some(interval) = params.get("intervalSeconds").and_then(Value::as_u64) {
            duty.interval_seconds = interval.max(60);
        }
        if let Some(enabled) = params.get("enabled").and_then(Value::as_bool) {
            duty.enabled = enabled;
        }
    })?;
    Ok(duty_json(opencli_home, &updated))
}

fn remove(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let id = required(params, "id")?;
    let removed =
        duties::delete(opencli_home, &id).map_err(|err| format!("could not save: {err}"))?;
    Ok(json!({ "removed": removed }))
}

/// Run a duty now, whatever its interval says.
///
/// How anyone finds out whether the rules they just wrote do what they meant.
/// Waiting an hour to see is how a duty gets set up wrong and left that way.
fn run_now(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let id = required(params, "id")?;
    let duty = duties::get(opencli_home, &id).ok_or_else(|| format!("no duty with id `{id}`"))?;
    if duties::is_blocked(opencli_home, &duty.id) {
        return Err("this duty is waiting on an answer".to_string());
    }
    queue(opencli_home, &duty).map(|_| json!({ "queued": true }))
}

fn remember(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let id = required(params, "id")?;
    let entries = params
        .get("entries")
        .and_then(Value::as_object)
        .ok_or("entries is required")?
        .iter()
        .map(|(key, value)| (key.clone(), value.as_str().unwrap_or_default().to_string()))
        .collect::<BTreeMap<String, String>>();
    let state = duties::remember(opencli_home, &id, entries)
        .map_err(|err| format!("could not save: {err}"))?;
    Ok(json!({ "knows": state.entries }))
}

fn ask(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let duty = required(params, "duty")?;
    let bot = required(params, "bot")?;
    let question = required(params, "question")?;
    let context = params
        .get("context")
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_string();
    let escalation = duties::ask(opencli_home, duty, bot, question, context)
        .map_err(|err| format!("could not save: {err}"))?;
    Ok(escalation_json(&escalation))
}

fn answer(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let id = required(params, "id")?;
    let answer = required(params, "answer")?;
    let answered = duties::answer(opencli_home, &id, answer)
        .map_err(|err| format!("could not save: {err}"))?
        .ok_or_else(|| format!("no question with id `{id}`"))?;
    Ok(escalation_json(&answered))
}

/// Everything waiting on a person, oldest first.
fn asking(opencli_home: &Path) -> Value {
    let data: Vec<Value> = duties::open_escalations(opencli_home)
        .iter()
        .map(escalation_json)
        .collect();
    json!({ "data": data })
}

/// Put one run of a duty on the queue.
///
/// Through the dispatch worker rather than run here, for the reason scheduled
/// tasks already go that way: one place decides how many agents run at once.
/// The brief is assembled at this moment because that is when the notes and any
/// answer are current.
fn queue(opencli_home: &Path, duty: &duties::Duty) -> Result<(), String> {
    let bot = bots::get(opencli_home, &duty.bot)
        .ok_or_else(|| format!("`{}` is nobody's duty any more", duty.name))?;
    let department = opencli_core::projects::get(opencli_home, &bot.department)
        .ok_or_else(|| format!("`{}` works in a department that is gone", bot.name))?;

    let state = duties::state(opencli_home, &duty.id);
    let carried = duties::answer_to_carry(opencli_home, duty);
    let brief = duties::brief(duty, &state, carried.as_ref());

    dispatch::create(
        opencli_home,
        format!("{} · {}", bot.name, duty.name),
        brief,
        // A duty runs where its department works, not wherever the gateway
        // was started: that directory is the boundary the sandbox enforces.
        department.cwd.clone(),
        None,
        dispatch::RunSource::Scheduled,
        Some(duty.id.clone()),
    )
    .map_err(|err| format!("could not queue: {err}"))?;
    Ok(())
}

/// Run duties as they come due.
///
/// Separate from the scheduled-task loop because the questions are different:
/// a task asks only whether enough time has passed, a duty also asks whether it
/// is waiting on somebody.
pub async fn run_scheduler(opencli_home: PathBuf) {
    const TICK: std::time::Duration = std::time::Duration::from_secs(20);
    loop {
        tokio::time::sleep(TICK).await;
        let now = opencli_core::scheduled::now_seconds();
        for duty in duties::load(&opencli_home) {
            let blocked = duties::is_blocked(&opencli_home, &duty.id);
            if !duty.is_due(now, blocked) {
                continue;
            }
            // Marked before it is queued, not after: a duty that takes longer
            // than its interval would otherwise still be due on the next tick
            // and be started again beside itself.
            if let Err(err) = duties::mark_run(&opencli_home, &duty.id) {
                tracing::error!("could not record the run of `{}`: {err}", duty.name);
                continue;
            }
            if let Err(err) = queue(&opencli_home, &duty) {
                tracing::error!("could not queue `{}`: {err}", duty.name);
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::handle;
    use serde_json::Value;
    use std::path::Path;
    use tempfile::tempdir;

    fn call(raw: &str, home: &Path) -> Value {
        serde_json::from_str(&handle(raw, home).expect("handled")).expect("json")
    }

    fn a_bot(home: &Path) -> String {
        let department = crate::project::handle(
            r#"{"method":"project/create","id":1,"params":{"name":"Finance"}}"#,
            home,
        )
        .expect("handled");
        let parsed: Value = serde_json::from_str(&department).expect("json");
        let department = parsed["result"]["id"].as_str().expect("id").to_string();

        let hired = crate::bot::handle(
            &format!(
                r#"{{"method":"bot/create","id":2,"params":
                    {{"department":"{department}","name":"Reconciler","job":"reconcile"}}}}"#
            ),
            home,
        )
        .expect("handled");
        let parsed: Value = serde_json::from_str(&hired).expect("json");
        parsed["result"]["id"].as_str().expect("id").to_string()
    }

    fn a_duty(home: &Path, bot: &str) -> String {
        let made = call(
            &format!(
                r#"{{"method":"duty/create","id":3,"params":
                    {{"bot":"{bot}","name":"Reconcile","what":"match the ledger",
                      "rules":"refund under 200 without asking",
                      "escalateWhen":"the refund is over 200"}}}}"#
            ),
            home,
        );
        made["result"]["id"].as_str().expect("id").to_string()
    }

    #[test]
    fn should_refuse_a_duty_for_a_bot_that_does_not_exist() {
        // Otherwise it surfaces on the first tick, hours later, as a run
        // against nobody.
        let dir = tempdir().expect("tempdir");
        let reply = call(
            r#"{"method":"duty/create","id":1,"params":{"bot":"bot-nope","name":"x","what":"y"}}"#,
            dir.path(),
        );
        assert!(
            reply["error"]["message"]
                .as_str()
                .is_some_and(|message| message.contains("bot-nope"))
        );
    }

    #[test]
    fn should_keep_the_rules_apart_from_the_work() {
        let dir = tempdir().expect("tempdir");
        let bot = a_bot(dir.path());
        let id = a_duty(dir.path(), &bot);

        let listed = call(r#"{"method":"duty/list","id":4}"#, dir.path());
        let row = &listed["result"]["data"][0];
        assert_eq!(row["id"], id.as_str());
        assert_eq!(row["what"], "match the ledger");
        assert_eq!(row["rules"], "refund under 200 without asking");
        assert_eq!(row["escalateWhen"], "the refund is over 200");
        assert_eq!(row["blocked"], false);
    }

    #[test]
    fn should_report_what_a_duty_knows_beside_it() {
        let dir = tempdir().expect("tempdir");
        let bot = a_bot(dir.path());
        let id = a_duty(dir.path(), &bot);

        call(
            &format!(
                r#"{{"method":"duty/remember","id":5,"params":
                    {{"id":"{id}","entries":{{"reconciled_to":"txn-4821"}}}}}}"#
            ),
            dir.path(),
        );

        let listed = call(r#"{"method":"duty/list","id":6}"#, dir.path());
        assert_eq!(
            listed["result"]["data"][0]["knows"]["reconciled_to"],
            "txn-4821"
        );
    }

    #[test]
    fn should_show_a_duty_as_blocked_while_it_waits() {
        let dir = tempdir().expect("tempdir");
        let bot = a_bot(dir.path());
        let id = a_duty(dir.path(), &bot);

        call(
            &format!(
                r#"{{"method":"duty/ask","id":7,"params":
                    {{"duty":"{id}","bot":"{bot}","question":"refund 3800?"}}}}"#
            ),
            dir.path(),
        );

        let listed = call(r#"{"method":"duty/list","id":8}"#, dir.path());
        assert_eq!(listed["result"]["data"][0]["blocked"], true);

        let waiting = call(r#"{"method":"duty/asking","id":9}"#, dir.path());
        assert_eq!(waiting["result"]["data"][0]["question"], "refund 3800?");
    }

    #[test]
    fn should_refuse_to_run_a_duty_that_is_waiting_on_an_answer() {
        // Running it would ask the same question again beside the first.
        let dir = tempdir().expect("tempdir");
        let bot = a_bot(dir.path());
        let id = a_duty(dir.path(), &bot);
        call(
            &format!(
                r#"{{"method":"duty/ask","id":7,"params":
                    {{"duty":"{id}","bot":"{bot}","question":"?"}}}}"#
            ),
            dir.path(),
        );

        let reply = call(
            &format!(r#"{{"method":"duty/runNow","id":10,"params":{{"id":"{id}"}}}}"#),
            dir.path(),
        );
        assert!(
            reply["error"]["message"]
                .as_str()
                .is_some_and(|message| message.contains("waiting"))
        );
    }

    #[test]
    fn should_unblock_a_duty_once_its_question_is_answered() {
        let dir = tempdir().expect("tempdir");
        let bot = a_bot(dir.path());
        let id = a_duty(dir.path(), &bot);
        let asked = call(
            &format!(
                r#"{{"method":"duty/ask","id":7,"params":
                    {{"duty":"{id}","bot":"{bot}","question":"?"}}}}"#
            ),
            dir.path(),
        );
        let question = asked["result"]["id"].as_str().expect("id").to_string();

        call(
            &format!(
                r#"{{"method":"duty/answer","id":11,"params":
                    {{"id":"{question}","answer":"go ahead"}}}}"#
            ),
            dir.path(),
        );

        let listed = call(r#"{"method":"duty/list","id":12}"#, dir.path());
        assert_eq!(listed["result"]["data"][0]["blocked"], false);
        assert!(
            call(r#"{"method":"duty/asking","id":13}"#, dir.path())["result"]["data"]
                .as_array()
                .expect("data")
                .is_empty()
        );
    }

    #[test]
    fn should_queue_a_run_in_the_departments_directory() {
        // Not wherever the gateway was started: that directory is the boundary
        // the sandbox enforces between departments.
        let dir = tempdir().expect("tempdir");
        let bot = a_bot(dir.path());
        let id = a_duty(dir.path(), &bot);

        let queued = call(
            &format!(r#"{{"method":"duty/runNow","id":14,"params":{{"id":"{id}"}}}}"#),
            dir.path(),
        );
        assert_eq!(queued["result"]["queued"], true);

        let runs = crate::dispatch::handle(r#"{"method":"dispatch/list","id":15}"#, dir.path())
            .expect("handled");
        let runs: Value = serde_json::from_str(&runs).expect("json");
        let row = &runs["result"]["data"][0];
        assert_eq!(row["title"], "Reconciler · Reconcile");
        assert!(
            row["cwd"]
                .as_str()
                .is_some_and(|cwd| cwd.ends_with("workspace/finance")),
            "got {}",
            row["cwd"]
        );
        // The brief, assembled at the moment of queueing.
        assert!(
            row["prompt"]
                .as_str()
                .is_some_and(|prompt| prompt.contains("Stop and ask")),
            "the stopping rule never reached the bot"
        );
    }

    #[test]
    fn should_let_other_methods_pass_through() {
        let dir = tempdir().expect("tempdir");
        assert!(handle(r#"{"method":"project/list","id":1}"#, dir.path()).is_none());
    }
}
