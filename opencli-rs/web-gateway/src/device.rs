//! Pairing a phone, and seeing what is paired.
//!
//! The address matters as much as the token. A device token is only worth
//! having if the phone can reach this machine at all, and on a home network
//! that means a LAN address rather than `127.0.0.1` — which is what the
//! gateway binds by default and what every URL it prints says. So pairing
//! answers with an address the other device could actually use, and says
//! plainly when there is none.

use opencli_core::devices;
use serde_json::Value;
use serde_json::json;
use std::path::Path;

/// Answer a `device/*` request, or return `None` to let it pass through.
pub fn handle(raw: &str, opencli_home: &Path, port: u16) -> Option<String> {
    let message: Value = serde_json::from_str(raw).ok()?;
    let method = message.get("method")?.as_str()?;
    if !method.starts_with("device/") {
        return None;
    }
    let id = message.get("id").cloned().unwrap_or(Value::Null);
    let params = message.get("params").cloned().unwrap_or(json!({}));

    let result = match method {
        "device/list" => Ok(list(opencli_home)),
        "device/pair" => pair(opencli_home, &params, port),
        "device/revoke" => revoke(opencli_home, &params),
        _ => Err(format!("unknown method `{method}`")),
    };

    Some(match result {
        Ok(value) => json!({ "id": id, "result": value }).to_string(),
        Err(message) => {
            json!({ "id": id, "error": { "code": -32602, "message": message } }).to_string()
        }
    })
}

fn list(opencli_home: &Path) -> Value {
    let data: Vec<Value> = devices::load(opencli_home)
        .iter()
        .map(|device| {
            let (id, name, paired_at, last_seen) = device.describe();
            json!({
                "id": id,
                "name": name,
                "pairedAt": paired_at,
                "lastSeen": last_seen,
            })
        })
        .collect();
    json!({ "data": data })
}

/// Pair a device and hand back the one URL that will ever contain its token.
fn pair(opencli_home: &Path, params: &Value, port: u16) -> Result<Value, String> {
    let name = params
        .get("name")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|name| !name.is_empty())
        .unwrap_or("Phone")
        .to_string();

    let (device, token) = devices::pair(opencli_home, name)
        .map_err(|err| format!("could not save the pairing: {err}"))?;
    let (id, name, paired_at, _) = device.describe();

    let reachable = reachable_address();
    Ok(json!({
        "id": id,
        "name": name,
        "pairedAt": paired_at,
        // The one time it exists in the open. Shown once, as a URL and a code
        // to scan, and never retrievable afterwards.
        "url": reachable
            .as_ref()
            .map(|host| format!("ws://{host}:{port}/ws?token={token}")),
        "host": reachable,
        "validForSeconds": devices::PAIRING_VALID_SECONDS,
    }))
}

fn revoke(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let id = params
        .get("id")
        .and_then(Value::as_str)
        .ok_or("id is required")?;
    let removed =
        devices::revoke(opencli_home, id).map_err(|err| format!("could not save: {err}"))?;
    Ok(json!({ "removed": removed }))
}

/// An address on this network that another device could reach.
///
/// Loopback is deliberately excluded rather than offered as a fallback: a
/// pairing URL saying `127.0.0.1` looks like it works and cannot, and the
/// person is left to work out why their phone times out. `None` means say so.
fn reachable_address() -> Option<String> {
    // A Tailscale address first when there is one, because it is the one that
    // keeps working away from this network — which is the case the whole
    // feature is for.
    if let Some(address) = tailscale_address() {
        return Some(address);
    }
    local_address()
}

fn tailscale_address() -> Option<String> {
    let output = std::process::Command::new("tailscale")
        .args(["ip", "-4"])
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    String::from_utf8(output.stdout)
        .ok()?
        .lines()
        .next()
        .map(str::trim)
        .filter(|address| !address.is_empty())
        .map(str::to_string)
}

#[cfg(unix)]
fn local_address() -> Option<String> {
    let output = std::process::Command::new("ipconfig")
        .args(["getifaddr", "en0"])
        .output()
        .ok()
        .filter(|output| output.status.success())
        .or_else(|| {
            std::process::Command::new("hostname")
                .arg("-I")
                .output()
                .ok()
                .filter(|output| output.status.success())
        })?;
    String::from_utf8(output.stdout)
        .ok()?
        .split_whitespace()
        .next()
        .map(str::to_string)
        .filter(|address| !address.starts_with("127."))
}

#[cfg(not(unix))]
fn local_address() -> Option<String> {
    None
}

#[cfg(test)]
mod tests {
    use super::handle;
    use serde_json::Value;
    use std::path::Path;
    use tempfile::tempdir;

    fn call(raw: &str, home: &Path) -> Value {
        serde_json::from_str(&handle(raw, home, 4517).expect("handled")).expect("json")
    }

    #[test]
    fn should_hand_the_token_over_once_and_never_again() {
        // Pairing is the one moment it exists in the open. A list that could
        // return it would be a list of passwords to this machine.
        let dir = tempdir().expect("tempdir");
        let paired = call(
            r#"{"method":"device/pair","id":1,"params":{"name":"Phone"}}"#,
            dir.path(),
        );
        let url = paired["result"]["url"]
            .as_str()
            .unwrap_or_default()
            .to_string();

        let listed = call(r#"{"method":"device/list","id":2}"#, dir.path());
        let text = serde_json::to_string(&listed).expect("json");
        assert!(!text.contains("token="), "the list must not carry a token");
        if !url.is_empty() {
            let token = url.split("token=").nth(1).expect("token");
            assert!(!text.contains(token));
        }
    }

    #[test]
    fn should_list_a_paired_device_without_its_secret() {
        let dir = tempdir().expect("tempdir");
        call(
            r#"{"method":"device/pair","id":1,"params":{"name":"Phone"}}"#,
            dir.path(),
        );

        let listed = call(r#"{"method":"device/list","id":2}"#, dir.path());
        let row = &listed["result"]["data"][0];
        assert_eq!(row["name"], "Phone");
        assert!(row["pairedAt"].as_u64().is_some_and(|at| at > 0));
        assert!(row["lastSeen"].is_null(), "it has not connected yet");
    }

    #[test]
    fn should_revoke_one_device() {
        let dir = tempdir().expect("tempdir");
        let paired = call(
            r#"{"method":"device/pair","id":1,"params":{"name":"Phone"}}"#,
            dir.path(),
        );
        let id = paired["result"]["id"].as_str().expect("id").to_string();
        call(
            r#"{"method":"device/pair","id":2,"params":{"name":"Tablet"}}"#,
            dir.path(),
        );

        let gone = call(
            &format!(r#"{{"method":"device/revoke","id":3,"params":{{"id":"{id}"}}}}"#),
            dir.path(),
        );
        assert_eq!(gone["result"]["removed"], true);

        let listed = call(r#"{"method":"device/list","id":4}"#, dir.path());
        let rows = listed["result"]["data"].as_array().expect("data");
        assert_eq!(rows.len(), 1);
        assert_eq!(rows[0]["name"], "Tablet");
    }

    #[test]
    fn should_name_an_unnamed_device_rather_than_refusing() {
        // A phone with no name is still a phone; making the name compulsory
        // would put a form in front of the one action that has to be quick.
        let dir = tempdir().expect("tempdir");
        let paired = call(r#"{"method":"device/pair","id":1}"#, dir.path());
        assert_eq!(paired["result"]["name"], "Phone");
    }

    #[test]
    fn should_let_other_methods_pass_through() {
        let dir = tempdir().expect("tempdir");
        assert!(handle(r#"{"method":"project/list","id":1}"#, dir.path(), 4517).is_none());
    }
}
