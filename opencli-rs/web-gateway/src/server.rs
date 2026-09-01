//! Gateway-side server management, and saying what is actually wrong.
//!
//! Two questions a panel must answer honestly, because they need different
//! fixes and look identical from outside:
//!
//! - Is the runtime *reachable*? A tunnel answering 502 is not the same as a
//!   network that cannot be crossed.
//! - Is the runtime *installed and running*? A service restarting in a loop
//!   reports as "activating" forever, which reads like "starting up" rather
//!   than "broken since yesterday".
//!
//! HTTP answers the first. Only a shell answers the second, which is why an
//! SSH alias is worth having even when model management already works.

use opencli_core::servers;
use opencli_ssh::client;
use opencli_ssh::config as ssh_config;
use serde_json::Value;
use serde_json::json;
use std::path::Path;

/// Answer a `server/*` request.
pub async fn handle(raw: &str, opencli_home: &Path) -> Option<String> {
    let message: Value = serde_json::from_str(raw).ok()?;
    let method = message.get("method")?.as_str()?;
    if !method.starts_with("server/") {
        return None;
    }
    let id = message.get("id").cloned().unwrap_or(Value::Null);
    let params = message.get("params").cloned().unwrap_or(json!({}));

    let result = match method {
        "server/list" => list(opencli_home),
        "server/add" => add(opencli_home, &params),
        "server/update" => update(opencli_home, &params),
        "server/remove" => remove(opencli_home, &params),
        "server/aliases" => Ok(aliases()),
        "server/diagnose" => diagnose(opencli_home, &params).await,
        "server/exec" => exec(opencli_home, &params).await,
        _ => Err(format!("unknown method `{method}`")),
    };

    Some(match result {
        Ok(value) => json!({ "id": id, "result": value }).to_string(),
        Err(message) => {
            json!({ "id": id, "error": { "code": -32602, "message": message } }).to_string()
        }
    })
}

fn server_json(server: &servers::Server) -> Value {
    json!({
        "id": server.id,
        "name": server.name,
        "baseUrl": server.base_url,
        "runtime": server.runtime,
        "sshAlias": server.ssh_alias,
        "createdAt": server.created_at,
    })
}

fn list(opencli_home: &Path) -> Result<Value, String> {
    let data: Vec<Value> = servers::load(opencli_home).iter().map(server_json).collect();
    Ok(json!({ "data": data }))
}

/// Aliases the user's own `~/.ssh/config` already names.
///
/// Offered as a list rather than a free-text field: a machine already reachable
/// as `ssh gpu5090` should be one click, not a second copy of its address.
fn aliases() -> Value {
    let Some(home) = std::env::var_os("HOME").map(std::path::PathBuf::from) else {
        return json!({ "data": [] });
    };
    let Ok(contents) = std::fs::read_to_string(home.join(".ssh").join("config")) else {
        return json!({ "data": [] });
    };

    let mut data = Vec::new();
    for line in contents.lines() {
        let line = line.trim();
        let Some(rest) = line
            .strip_prefix("Host ")
            .or_else(|| line.strip_prefix("host "))
        else {
            continue;
        };
        for alias in rest.split_whitespace() {
            // A pattern is not a machine anyone can be asked to pick.
            if alias.contains('*') || alias.contains('?') || alias.starts_with('!') {
                continue;
            }
            let Some(settings) = ssh_config::resolve_in(&contents, alias) else {
                continue;
            };
            data.push(json!({
                "alias": alias,
                "hostname": settings.hostname,
                "port": settings.port,
                "user": settings.user,
                // Say what will not work rather than failing later.
                "unsupported": settings.unsupported,
            }));
        }
    }
    json!({ "data": data })
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

fn add(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let name = required(params, "name")?;
    let base_url = required(params, "baseUrl")?;
    if !base_url.starts_with("http://") && !base_url.starts_with("https://") {
        return Err("baseUrl must start with http:// or https://".to_string());
    }
    let runtime = params
        .get("runtime")
        .and_then(Value::as_str)
        .unwrap_or("ollama")
        .to_string();
    if opencli_core::runtimes::find(&runtime).is_none() {
        return Err(format!("`{runtime}` is not a runtime this build knows"));
    }
    let alias = params
        .get("sshAlias")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|alias| !alias.is_empty())
        .map(str::to_string);

    // An alias that is not in the config would fail only when first used, by
    // which time the user has forgotten they typed it.
    if let Some(alias) = &alias
        && ssh_config::resolve(alias).is_none()
    {
        return Err(format!("`{alias}` is not in your ~/.ssh/config"));
    }

    let server = servers::create(opencli_home, name, base_url, runtime, alias)
        .map_err(|err| format!("could not save: {err}"))?;
    Ok(server_json(&server))
}

fn update(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let id = required(params, "id")?;
    // `null` means remove the alias; absent means leave it.
    let alias = match params.get("sshAlias") {
        None => None,
        Some(Value::Null) => Some(None),
        Some(Value::String(alias)) if alias.trim().is_empty() => Some(None),
        Some(Value::String(alias)) => {
            if ssh_config::resolve(alias.trim()).is_none() {
                return Err(format!("`{}` is not in your ~/.ssh/config", alias.trim()));
            }
            Some(Some(alias.trim().to_string()))
        }
        Some(_) => return Err("sshAlias must be a name or null".to_string()),
    };

    let updated = servers::update(
        opencli_home,
        &id,
        params.get("name").and_then(Value::as_str).map(str::to_string),
        params.get("baseUrl").and_then(Value::as_str).map(str::to_string),
        alias,
    )
    .map_err(|err| format!("could not save: {err}"))?;
    match updated {
        Some(server) => Ok(server_json(&server)),
        None => Err(format!("no server with id `{id}`")),
    }
}

fn remove(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let id = required(params, "id")?;
    if !servers::delete(opencli_home, &id).map_err(|err| format!("could not save: {err}"))? {
        return Err(format!("no server with id `{id}`"));
    }
    Ok(json!({}))
}

/// Open a session to a server's SSH alias.
async fn open(server: &servers::Server) -> Result<(client::Session, String), String> {
    let alias = server
        .ssh_alias
        .as_ref()
        .ok_or("this server has no SSH alias, so it can only be managed over HTTP")?;
    let settings =
        ssh_config::resolve(alias).ok_or_else(|| format!("`{alias}` is not in your ~/.ssh/config"))?;
    if !settings.unsupported.is_empty() {
        return Err(format!(
            "your config uses {} for `{alias}`, which this client does not support",
            settings.unsupported.join(", ")
        ));
    }
    let user = settings
        .user
        .clone()
        .or_else(|| std::env::var("USER").ok())
        .ok_or("no user to connect as; add `User` to that host in ~/.ssh/config")?;

    let session = client::connect(&settings, &user, client::TrustPolicy::Ask)
        .await
        .map_err(|err| err.to_string())?;
    Ok((session, user))
}

/// Look at a server closely enough to say what is wrong with it.
///
/// HTTP alone cannot tell a runtime that is down from a network that is out,
/// and cannot see a service that has been restarting in a loop for a day. With
/// a shell, both become plain.
async fn diagnose(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let id = required(params, "id")?;
    let server =
        servers::get(opencli_home, &id).ok_or_else(|| format!("no server with id `{id}`"))?;

    let mut findings = Vec::new();

    // Not fatal on its own: the point of diagnosing is usually that this fails.
    let http = match reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(15))
        .build()
    {
        Ok(client) => {
            let root = server.base_url.trim_end_matches('/').trim_end_matches("/v1");
            match client.get(format!("{root}/api/version")).send().await {
                Ok(response) if response.status().is_success() => {
                    let body: Value = response.json().await.unwrap_or(json!({}));
                    json!({
                        "reachable": true,
                        "version": body.get("version"),
                    })
                }
                Ok(response) => {
                    let status = response.status().as_u16();
                    if status == 502 || status == 503 {
                        findings.push(
                            "Something is answering at that address, but the runtime behind it \
                             is not running."
                                .to_string(),
                        );
                    }
                    json!({ "reachable": false, "status": status })
                }
                Err(err) => {
                    findings.push(format!("Could not reach it over HTTP: {err}"));
                    json!({ "reachable": false })
                }
            }
        }
        Err(err) => json!({ "reachable": false, "error": err.to_string() }),
    };

    if server.ssh_alias.is_none() {
        findings.push(
            "No SSH alias, so nothing beyond the HTTP check can be seen. Add one to inspect or \
             repair the runtime itself."
                .to_string(),
        );
        return Ok(json!({ "http": http, "shell": Value::Null, "findings": findings }));
    }

    let (session, user) = match open(&server).await {
        Ok(session) => session,
        Err(err) => {
            findings.push(format!("Could not open a shell: {err}"));
            return Ok(json!({ "http": http, "shell": Value::Null, "findings": findings }));
        }
    };

    // One round trip rather than eight: each `exec` is a channel, and a slow
    // link makes eight of them noticeably slow.
    let script = "\
echo \"__os__=$(uname -sr 2>/dev/null)\"; \
echo \"__binary__=$(command -v ollama 2>/dev/null)\"; \
echo \"__service__=$(systemctl is-active ollama 2>/dev/null)\"; \
echo \"__enabled__=$(systemctl is-enabled ollama 2>/dev/null)\"; \
echo \"__restarts__=$(systemctl show ollama -p NRestarts --value 2>/dev/null)\"; \
echo \"__listening__=$(curl -s -m 3 -o /dev/null -w %{http_code} http://127.0.0.1:11434/api/version 2>/dev/null)\"; \
echo \"__models__=$(du -sh /usr/share/ollama/.ollama/models 2>/dev/null | cut -f1)\"; \
echo \"__disk__=$(df -h / 2>/dev/null | tail -1 | awk '{print $4}')\"; \
echo \"__gpu__=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null | head -1)\"; \
echo \"__sudo__=$(sudo -n true 2>/dev/null && echo yes || echo no)\"";

    let output = session
        .exec(script)
        .await
        .map_err(|err| format!("the shell command failed: {err}"))?;
    session.close().await;

    let mut fields = serde_json::Map::new();
    for line in output.stdout.lines() {
        if let Some((key, value)) = line.split_once('=') {
            let key = key.trim_start_matches("__").trim_end_matches("__");
            fields.insert(key.to_string(), json!(value));
        }
    }

    let field = |key: &str| fields.get(key).and_then(Value::as_str).unwrap_or("");
    let binary = field("binary");
    let service = field("service");
    let restarts = field("restarts").parse::<u64>().unwrap_or(0);
    let listening = field("listening") == "200";

    if binary.is_empty() {
        findings.push(
            "The `ollama` command is not on the server's PATH — it is not installed, or its \
             binary has been removed."
                .to_string(),
        );
    }
    if service == "activating" && restarts > 10 {
        // This is the state that reads as "starting up" and is not.
        findings.push(format!(
            "The service has restarted {restarts} times and never stayed up. It reports as \
             `activating`, which looks like starting but is a crash loop."
        ));
    }
    if service == "failed" {
        findings.push("The service is in a failed state.".to_string());
    }
    if listening && !http["reachable"].as_bool().unwrap_or(false) {
        findings.push(
            "The runtime answers on the server itself but not through its public address — the \
             tunnel or firewall is what is broken, not the runtime."
                .to_string(),
        );
    }
    if field("sudo") != "yes" {
        findings.push(format!(
            "`{user}` cannot use sudo without a password, so system-level repairs have to be run \
             by you. The commands will be shown rather than attempted."
        ));
    }
    if findings.is_empty() {
        findings.push("Nothing looks wrong.".to_string());
    }

    Ok(json!({
        "http": http,
        "shell": {
            "os": field("os"),
            "binary": binary,
            "service": service,
            "enabled": field("enabled"),
            "restarts": restarts,
            "listeningLocally": listening,
            "modelsOnDisk": field("models"),
            "diskFree": field("disk"),
            "gpu": field("gpu"),
            "canSudo": field("sudo") == "yes",
            "user": user,
        },
        "findings": findings,
    }))
}

/// Run one command on a server.
///
/// Deliberately not a shell the agent can drive on its own: it is called from
/// a repair the user asked for, with the command shown to them first.
async fn exec(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let id = required(params, "id")?;
    let command = required(params, "command")?;
    let server =
        servers::get(opencli_home, &id).ok_or_else(|| format!("no server with id `{id}`"))?;

    let (session, _) = open(&server).await?;
    let output = session
        .exec(&command)
        .await
        .map_err(|err| format!("the command failed: {err}"))?;
    session.close().await;

    Ok(json!({
        "stdout": output.stdout,
        "stderr": output.stderr,
        "exitCode": output.exit_code,
        "succeeded": output.succeeded(),
    }))
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    async fn call(raw: &str, home: &Path) -> Value {
        let reply = handle(raw, home).await.expect("server methods are handled locally");
        serde_json::from_str(&reply).expect("valid JSON reply")
    }

    #[tokio::test]
    async fn should_pass_non_server_methods_through_to_the_agent() {
        let dir = tempdir().expect("tempdir");
        assert!(handle(r#"{"method":"turn/start","id":1}"#, dir.path()).await.is_none());
        assert!(handle("not json", dir.path()).await.is_none());
    }

    #[tokio::test]
    async fn should_add_a_server_reachable_only_over_http() {
        let dir = tempdir().expect("tempdir");
        let added = call(
            r#"{"method":"server/add","id":1,"params":
                {"name":"Box","baseUrl":"https://llm.example.com"}}"#,
            dir.path(),
        )
        .await;
        assert_eq!(added["result"]["name"], "Box");
        assert!(added["result"]["sshAlias"].is_null());
    }

    #[tokio::test]
    async fn should_refuse_an_address_that_is_not_a_url() {
        let dir = tempdir().expect("tempdir");
        let reply = call(
            r#"{"method":"server/add","id":1,"params":{"name":"x","baseUrl":"gpu-box:11434"}}"#,
            dir.path(),
        )
        .await;
        assert!(reply["error"].is_object());
    }

    #[tokio::test]
    async fn should_refuse_an_alias_that_is_not_in_the_ssh_config() {
        // Accepting it would fail only on first use, by which time the user has
        // forgotten they typed it.
        let dir = tempdir().expect("tempdir");
        let reply = call(
            r#"{"method":"server/add","id":1,"params":
                {"name":"x","baseUrl":"http://x:11434","sshAlias":"definitely-not-configured"}}"#,
            dir.path(),
        )
        .await;
        assert!(reply["error"]["message"]
            .as_str()
            .is_some_and(|message| message.contains("ssh/config")));
    }

    #[tokio::test]
    async fn should_refuse_a_runtime_it_does_not_know() {
        let dir = tempdir().expect("tempdir");
        let reply = call(
            r#"{"method":"server/add","id":1,"params":
                {"name":"x","baseUrl":"http://x:11434","runtime":"invented"}}"#,
            dir.path(),
        )
        .await;
        assert!(reply["error"].is_object());
    }

    #[tokio::test]
    async fn should_say_what_it_cannot_see_without_a_shell() {
        // A diagnosis that just says "unreachable" leaves the user no wiser.
        let dir = tempdir().expect("tempdir");
        let added = call(
            r#"{"method":"server/add","id":1,"params":
                {"name":"x","baseUrl":"http://127.0.0.1:1"}}"#,
            dir.path(),
        )
        .await;
        let id = added["result"]["id"].as_str().expect("id").to_string();

        let report = call(
            &format!(r#"{{"method":"server/diagnose","id":2,"params":{{"id":"{id}"}}}}"#),
            dir.path(),
        )
        .await;
        let findings = report["result"]["findings"].as_array().expect("findings");
        assert!(
            findings
                .iter()
                .any(|finding| finding.as_str().unwrap_or("").contains("No SSH alias")),
            "got {findings:?}"
        );
        assert!(report["result"]["shell"].is_null());
    }

    #[tokio::test]
    async fn should_list_the_aliases_the_user_already_has() {
        // Reads this machine's own config; an empty list is a valid answer.
        let listed = call(r#"{"method":"server/aliases","id":1}"#, Path::new("/tmp")).await;
        assert!(listed["result"]["data"].is_array());
    }

    #[tokio::test]
    async fn should_remove_a_server_and_report_an_unknown_one() {
        let dir = tempdir().expect("tempdir");
        let added = call(
            r#"{"method":"server/add","id":1,"params":{"name":"x","baseUrl":"http://x:11434"}}"#,
            dir.path(),
        )
        .await;
        let id = added["result"]["id"].as_str().expect("id").to_string();

        let removed = call(
            &format!(r#"{{"method":"server/remove","id":2,"params":{{"id":"{id}"}}}}"#),
            dir.path(),
        )
        .await;
        assert!(removed["result"].is_object());

        let missing = call(
            r#"{"method":"server/remove","id":3,"params":{"id":"gone"}}"#,
            dir.path(),
        )
        .await;
        assert!(missing["error"].is_object());
    }
}
