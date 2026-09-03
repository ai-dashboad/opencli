//! Gateway-side handling of bots.
//!
//! A bot outlives any one conversation — that is the whole point of the record
//! — so it belongs here beside departments and scheduled tasks rather than in
//! the app server, which is scoped to a single thread.

use opencli_core::bots;
use opencli_core::projects;
use serde_json::Value;
use serde_json::json;
use std::path::Path;

/// Answer a `bot/*` request, or return `None` to let it pass through.
pub fn handle(raw: &str, opencli_home: &Path) -> Option<String> {
    let message: Value = serde_json::from_str(raw).ok()?;
    let method = message.get("method")?.as_str()?;
    if !method.starts_with("bot/") {
        return None;
    }
    let id = message.get("id").cloned().unwrap_or(Value::Null);
    let params = message.get("params").cloned().unwrap_or(json!({}));

    let result = match method {
        "bot/list" => list(opencli_home, &params),
        "bot/create" => create(opencli_home, &params),
        "bot/update" => update(opencli_home, &params),
        "bot/delete" => delete(opencli_home, &params),
        "bot/resolve" => resolve(opencli_home, &params),
        _ => Err(format!("unknown method `{method}`")),
    };

    Some(match result {
        Ok(value) => json!({ "id": id, "result": value }).to_string(),
        Err(message) => {
            json!({ "id": id, "error": { "code": -32602, "message": message } }).to_string()
        }
    })
}

/// One bot, with the address other bots would use for it.
///
/// The address is derived here rather than stored, so it follows a rename.
/// Computing it in the client instead would mean two implementations of the
/// naming rule, and a handoff failing because they disagreed.
fn bot_json(opencli_home: &Path, bot: &bots::Bot) -> Value {
    let department = projects::get(opencli_home, &bot.department);
    let department_name = department
        .as_ref()
        .map(|department| department.name.as_str())
        .unwrap_or("");
    json!({
        "id": bot.id,
        "department": bot.department,
        "departmentName": department_name,
        "name": bot.name,
        "job": bot.job,
        "threadId": bot.thread_id,
        "status": bot.status,
        "address": bots::address(department_name, &bot.name),
        "createdAt": bot.created_at,
        "updatedAt": bot.updated_at,
    })
}

fn list(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let all = match params.get("department").and_then(Value::as_str) {
        Some(department) => bots::in_department(opencli_home, department),
        None => bots::load(opencli_home),
    };
    let data: Vec<Value> = all.iter().map(|bot| bot_json(opencli_home, bot)).collect();
    Ok(json!({ "data": data }))
}

fn create(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let department = params
        .get("department")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|id| !id.is_empty())
        .ok_or("department is required")?;
    // Checked rather than assumed: a bot in a department that does not exist
    // has no directory to work in and no policy to work under, and the mistake
    // would only show up when it was first asked to do something.
    if projects::get(opencli_home, department).is_none() {
        return Err(format!("no department with id `{department}`"));
    }
    let name = params
        .get("name")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|name| !name.is_empty())
        .ok_or("name is required")?;
    let job = params
        .get("job")
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_string();

    let bot = bots::create(opencli_home, department.to_string(), name.to_string(), job)
        .map_err(|err| format!("could not save: {err}"))?;
    Ok(bot_json(opencli_home, &bot))
}

fn update(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let id = params
        .get("id")
        .and_then(Value::as_str)
        .ok_or("id is required")?;
    let text = |key: &str| params.get(key).and_then(Value::as_str).map(str::to_string);
    let status = match params.get("status") {
        Some(value) if !value.is_null() => Some(
            serde_json::from_value(value.clone())
                .map_err(|_| format!("`{value}` is not a status"))?,
        ),
        _ => None,
    };

    let updated = bots::update(
        opencli_home,
        id,
        text("name"),
        text("job"),
        text("threadId"),
        status,
    )
    .map_err(|err| format!("could not save: {err}"))?
    .ok_or_else(|| format!("no bot with id `{id}`"))?;
    Ok(bot_json(opencli_home, &updated))
}

fn delete(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let id = params
        .get("id")
        .and_then(Value::as_str)
        .ok_or("id is required")?;
    let removed = bots::delete(opencli_home, id).map_err(|err| format!("could not save: {err}"))?;
    Ok(json!({ "removed": removed }))
}

/// Who an address points at, and whether that bot may be written to from here.
///
/// The permission is answered together with the lookup on purpose. Asked
/// separately, a caller could resolve a bot and then message it without ever
/// consulting the department's policy — and the policy is the only thing
/// keeping one department's bots from driving another's.
fn resolve(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let address = params
        .get("address")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|address| !address.is_empty())
        .ok_or("address is required")?;
    let from = params
        .get("from")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|id| !id.is_empty())
        .ok_or("from is required")?;

    let Some(bot) = bots::resolve(opencli_home, address, from) else {
        return Ok(json!({ "found": false }));
    };
    let into = projects::get(opencli_home, &bot.department)
        .ok_or_else(|| format!("`{address}` works in a department that is gone"))?;
    let allowed = projects::accepts_message_from(&into, from);

    Ok(json!({
        "found": true,
        "allowed": allowed,
        "bot": bot_json(opencli_home, &bot),
    }))
}

#[cfg(test)]
mod tests {
    use super::handle;
    use serde_json::Value;
    use tempfile::tempdir;

    fn call(raw: &str, home: &Path) -> Value {
        serde_json::from_str(&handle(raw, home).expect("handled")).expect("json")
    }

    use std::path::Path;

    fn department(home: &Path, name: &str) -> String {
        let raw = format!(r#"{{"method":"project/create","id":1,"params":{{"name":"{name}"}}}}"#);
        let reply = crate::project::handle(&raw, home).expect("handled");
        let parsed: Value = serde_json::from_str(&reply).expect("json");
        parsed["result"]["id"].as_str().expect("id").to_string()
    }

    fn hire(home: &Path, department: &str, name: &str) -> Value {
        call(
            &format!(
                r#"{{"method":"bot/create","id":1,"params":
                    {{"department":"{department}","name":"{name}","job":"do the thing"}}}}"#
            ),
            home,
        )
    }

    #[test]
    fn should_hire_a_bot_into_a_department_with_an_address() {
        let dir = tempdir().expect("tempdir");
        let finance = department(dir.path(), "Finance");
        let hired = hire(dir.path(), &finance, "Reconciler");

        assert_eq!(hired["result"]["address"], "finance/reconciler");
        assert_eq!(hired["result"]["departmentName"], "Finance");
        assert_eq!(hired["result"]["status"], "idle");
        assert!(hired["result"]["threadId"].is_null());
    }

    #[test]
    fn should_refuse_a_bot_in_a_department_that_does_not_exist() {
        // Otherwise the mistake surfaces the first time it is asked to work,
        // with no directory and no policy, and nothing pointing back here.
        let dir = tempdir().expect("tempdir");
        let reply = hire(dir.path(), "proj-nope", "Reconciler");
        assert!(
            reply["error"]["message"]
                .as_str()
                .is_some_and(|message| message.contains("proj-nope"))
        );
    }

    #[test]
    fn should_follow_a_rename_in_the_address() {
        let dir = tempdir().expect("tempdir");
        let finance = department(dir.path(), "Finance");
        let id = hire(dir.path(), &finance, "Reconciler")["result"]["id"]
            .as_str()
            .expect("id")
            .to_string();

        let renamed = call(
            &format!(
                r#"{{"method":"bot/update","id":2,"params":{{"id":"{id}","name":"Ledger Checker"}}}}"#
            ),
            dir.path(),
        );
        assert_eq!(renamed["result"]["address"], "finance/ledger-checker");
    }

    #[test]
    fn should_answer_who_an_address_points_at() {
        let dir = tempdir().expect("tempdir");
        let finance = department(dir.path(), "Finance");
        hire(dir.path(), &finance, "Reconciler");

        let found = call(
            &format!(
                r#"{{"method":"bot/resolve","id":3,"params":
                    {{"address":"finance/reconciler","from":"{finance}"}}}}"#
            ),
            dir.path(),
        );
        assert_eq!(found["result"]["found"], true);
        assert_eq!(found["result"]["allowed"], true);
    }

    #[test]
    fn should_say_a_cross_department_message_is_not_allowed_rather_than_hiding_the_bot() {
        // Found but not allowed, not "no such bot". A bot told the address does
        // not exist would try spelling it differently; told it is not
        // permitted, it can say so and stop.
        let dir = tempdir().expect("tempdir");
        let finance = department(dir.path(), "Finance");
        let engineering = department(dir.path(), "Engineering");
        hire(dir.path(), &finance, "Reconciler");

        let found = call(
            &format!(
                r#"{{"method":"bot/resolve","id":3,"params":
                    {{"address":"finance/reconciler","from":"{engineering}"}}}}"#
            ),
            dir.path(),
        );
        assert_eq!(found["result"]["found"], true);
        assert_eq!(found["result"]["allowed"], false);
    }

    #[test]
    fn should_list_one_departments_roster() {
        let dir = tempdir().expect("tempdir");
        let finance = department(dir.path(), "Finance");
        let engineering = department(dir.path(), "Engineering");
        hire(dir.path(), &finance, "A");
        hire(dir.path(), &engineering, "B");

        let listed = call(
            &format!(r#"{{"method":"bot/list","id":4,"params":{{"department":"{finance}"}}}}"#),
            dir.path(),
        );
        let rows = listed["result"]["data"].as_array().expect("data");
        assert_eq!(rows.len(), 1);
        assert_eq!(rows[0]["name"], "A");
    }

    #[test]
    fn should_let_other_methods_pass_through() {
        let dir = tempdir().expect("tempdir");
        assert!(handle(r#"{"method":"project/list","id":1}"#, dir.path()).is_none());
    }
}
