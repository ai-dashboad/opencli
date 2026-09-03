//! Gateway-side connector management.
//!
//! The app server can *report* which MCP servers are configured and whether
//! they started. Changing that set means editing `config.toml`, which is a
//! file on this machine rather than anything belonging to a conversation — so
//! it is answered here, like projects and schedules.
//!
//! Edits go through `ConfigEditsBuilder`, which rewrites the table in place and
//! keeps the rest of the file — comments, ordering, unrelated sections —
//! exactly as the user left it.

use opencli_core::config::ConfigToml;
use opencli_core::config::edit::ConfigEditsBuilder;
use opencli_core::config::types::McpServerConfig;
use opencli_core::config::types::McpServerTransportConfig;
use serde_json::Value;
use serde_json::json;
use std::collections::BTreeMap;
use std::path::Path;

/// Answer a `connector/*` request, or return `None` to let it pass through.
pub fn handle(raw: &str, opencli_home: &Path) -> Option<String> {
    let message: Value = serde_json::from_str(raw).ok()?;
    let method = message.get("method")?.as_str()?;
    if !method.starts_with("connector/") {
        return None;
    }
    let id = message.get("id").cloned().unwrap_or(Value::Null);
    let params = message.get("params").cloned().unwrap_or(json!({}));

    let result = match method {
        "connector/list" => list(opencli_home),
        "connector/add" => add(opencli_home, &params),
        "connector/setEnabled" => set_enabled(opencli_home, &params),
        "connector/remove" => remove(opencli_home, &params),
        "connector/catalog" => Ok(catalog()),
        _ => Err(format!("unknown method `{method}`")),
    };

    Some(match result {
        Ok(value) => json!({ "id": id, "result": value }).to_string(),
        Err(message) => {
            json!({ "id": id, "error": { "code": -32602, "message": message } }).to_string()
        }
    })
}

/// Read the `[mcp_servers]` table straight from the file.
///
/// Not from the running session's config: an edit made a moment ago has not
/// reached it, and the list would show what was true when the session started.
fn read_servers(opencli_home: &Path) -> Result<BTreeMap<String, McpServerConfig>, String> {
    let path = opencli_home.join("config.toml");
    if !path.exists() {
        return Ok(BTreeMap::new());
    }
    let text = std::fs::read_to_string(&path).map_err(|err| format!("could not read: {err}"))?;
    let parsed: ConfigToml =
        toml::from_str(&text).map_err(|err| format!("config.toml is not valid: {err}"))?;
    Ok(parsed.mcp_servers.into_iter().collect())
}

fn write_servers(
    opencli_home: &Path,
    servers: &BTreeMap<String, McpServerConfig>,
) -> Result<(), String> {
    ConfigEditsBuilder::new(opencli_home)
        .replace_mcp_servers(servers)
        .apply_blocking()
        .map_err(|err| format!("could not save config.toml: {err}"))
}

fn transport_json(transport: &McpServerTransportConfig) -> Value {
    match transport {
        McpServerTransportConfig::Stdio {
            command,
            args,
            env_vars,
            ..
        } => json!({
            "kind": "stdio",
            "command": command,
            "args": args,
            "envVars": env_vars,
        }),
        McpServerTransportConfig::StreamableHttp { url, .. } => json!({
            "kind": "http",
            "url": url,
        }),
    }
}

fn server_json(name: &str, config: &McpServerConfig) -> Value {
    json!({
        "name": name,
        "enabled": config.enabled,
        "transport": transport_json(&config.transport),
    })
}

fn list(opencli_home: &Path) -> Result<Value, String> {
    let servers = read_servers(opencli_home)?;
    let data: Vec<Value> = servers
        .iter()
        .map(|(name, config)| server_json(name, config))
        .collect();
    Ok(json!({ "data": data }))
}

/// Connectors worth offering by name.
///
/// A short, honest list: each entry is a real MCP server that exists, with the
/// command or URL it is actually started by. Anything else is added by hand,
/// which `connector/add` also supports.
fn catalog() -> Value {
    json!({
        "data": [
            {
                "id": "figma",
                "name": "Figma",
                "description": "Read designs, components and variables from Figma files.",
                "transport": { "kind": "http", "url": "https://mcp.figma.com/mcp" },
                "note": "Requires a Figma account; the server asks you to sign in in a browser."
            },
            {
                "id": "github",
                "name": "GitHub",
                "description": "Issues, pull requests and code search on GitHub.",
                "transport": {
                    "kind": "stdio",
                    "command": "npx",
                    "args": ["-y", "@modelcontextprotocol/server-github"],
                    "envVars": ["GITHUB_PERSONAL_ACCESS_TOKEN"]
                },
                "note": "Needs a personal access token from github.com/settings/tokens.",
                "keyHint": "GITHUB_PERSONAL_ACCESS_TOKEN"
            },
            {
                "id": "filesystem",
                "name": "Filesystem",
                "description": "Read and write files under a directory you choose.",
                "transport": {
                    "kind": "stdio",
                    "command": "npx",
                    "args": ["-y", "@modelcontextprotocol/server-filesystem"]
                },
                "note": "Add the directory to allow as a further argument."
            },
            {
                "id": "postgres",
                "name": "Postgres",
                "description": "Query a Postgres database read-only.",
                "transport": {
                    "kind": "stdio",
                    "command": "npx",
                    "args": ["-y", "@modelcontextprotocol/server-postgres"]
                },
                "note": "Add the connection string as a further argument."
            }
        ]
    })
}

fn required_name(params: &Value) -> Result<String, String> {
    params
        .get("name")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|name| !name.is_empty())
        .map(str::to_string)
        .ok_or_else(|| "name is required".to_string())
}

/// Add or replace one connector.
fn add(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let name = required_name(params)?;
    // A name becomes a TOML key and is how the agent refers to the server, so
    // an awkward one is a lasting nuisance rather than a passing one.
    if !name
        .chars()
        .all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_')
    {
        return Err("name may use letters, digits, dashes and underscores only".to_string());
    }

    let transport = params.get("transport").ok_or("transport is required")?;
    let transport = match transport.get("kind").and_then(Value::as_str) {
        Some("http") => {
            let url = transport
                .get("url")
                .and_then(Value::as_str)
                .filter(|url| !url.is_empty())
                .ok_or("an http connector needs a url")?;
            McpServerTransportConfig::StreamableHttp {
                url: url.to_string(),
                bearer_token_env_var: transport
                    .get("bearerTokenEnvVar")
                    .and_then(Value::as_str)
                    .map(str::to_string),
                http_headers: None,
                env_http_headers: None,
            }
        }
        Some("stdio") => {
            let command = transport
                .get("command")
                .and_then(Value::as_str)
                .filter(|command| !command.is_empty())
                .ok_or("a stdio connector needs a command")?;
            let args = transport
                .get("args")
                .and_then(Value::as_array)
                .map(|args| {
                    args.iter()
                        .filter_map(Value::as_str)
                        .map(str::to_string)
                        .collect()
                })
                .unwrap_or_default();
            // Named, not valued. Most MCP servers need a token, and a token
            // written into the connector's configuration is a token in a file
            // people share. The name is recorded here; the value lives with
            // the other keys, in `$OPENCLI_HOME/.env`, and is passed through
            // to the server's environment when it starts.
            let env_vars = transport
                .get("envVars")
                .and_then(Value::as_array)
                .map(|names| {
                    names
                        .iter()
                        .filter_map(Value::as_str)
                        .map(str::trim)
                        .filter(|name| !name.is_empty())
                        .map(str::to_string)
                        .collect()
                })
                .unwrap_or_default();
            McpServerTransportConfig::Stdio {
                command: command.to_string(),
                args,
                env: None,
                env_vars,
                cwd: None,
            }
        }
        _ => return Err("transport kind must be `stdio` or `http`".to_string()),
    };

    let mut servers = read_servers(opencli_home)?;
    servers.insert(
        name.clone(),
        McpServerConfig {
            transport,
            enabled: true,
            disabled_reason: None,
            startup_timeout_sec: None,
            tool_timeout_sec: None,
            enabled_tools: None,
            disabled_tools: None,
            scopes: None,
        },
    );
    write_servers(opencli_home, &servers)?;

    let added = servers
        .get(&name)
        .ok_or_else(|| format!("{name} was written but could not be read back"))?;
    Ok(server_json(&name, added))
}

/// Turn a connector on or off without losing how it was configured.
fn set_enabled(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let name = required_name(params)?;
    let enabled = params
        .get("enabled")
        .and_then(Value::as_bool)
        .ok_or("enabled must be a boolean")?;

    let mut servers = read_servers(opencli_home)?;
    let Some(server) = servers.get_mut(&name) else {
        return Err(format!("no connector named `{name}`"));
    };
    server.enabled = enabled;
    write_servers(opencli_home, &servers)?;
    Ok(json!({ "name": name, "enabled": enabled, "restartRequired": true }))
}

fn remove(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let name = required_name(params)?;
    let mut servers = read_servers(opencli_home)?;
    if servers.remove(&name).is_none() {
        return Err(format!("no connector named `{name}`"));
    }
    write_servers(opencli_home, &servers)?;
    Ok(json!({}))
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    fn call(raw: &str, home: &Path) -> Value {
        let reply = handle(raw, home).expect("connector methods are handled locally");
        serde_json::from_str(&reply).expect("valid JSON reply")
    }

    fn add_one(home: &Path) -> Value {
        call(
            r#"{"method":"connector/add","id":1,"params":
                {"name":"figma","transport":{"kind":"http","url":"https://mcp.figma.com/mcp"}}}"#,
            home,
        )
    }

    #[test]
    fn should_pass_non_connector_methods_through_to_the_agent() {
        let dir = tempdir().expect("tempdir");
        assert!(handle(r#"{"method":"turn/start","id":1}"#, dir.path()).is_none());
        assert!(handle("not json", dir.path()).is_none());
    }

    #[test]
    fn should_list_nothing_before_anything_is_configured() {
        let dir = tempdir().expect("tempdir");
        let listed = call(r#"{"method":"connector/list","id":1}"#, dir.path());
        assert!(
            listed["result"]["data"]
                .as_array()
                .expect("data")
                .is_empty()
        );
    }

    #[test]
    fn should_add_an_http_connector_and_list_it() {
        let dir = tempdir().expect("tempdir");
        let added = add_one(dir.path());
        assert_eq!(added["result"]["name"], "figma");
        assert_eq!(added["result"]["enabled"], true);
        assert_eq!(added["result"]["transport"]["kind"], "http");

        let listed = call(r#"{"method":"connector/list","id":2}"#, dir.path());
        assert_eq!(listed["result"]["data"].as_array().map(Vec::len), Some(1));
    }

    #[test]
    fn should_add_a_stdio_connector_with_its_arguments() {
        let dir = tempdir().expect("tempdir");
        let added = call(
            r#"{"method":"connector/add","id":1,"params":
                {"name":"gh","transport":{"kind":"stdio","command":"npx",
                 "args":["-y","@modelcontextprotocol/server-github"]}}}"#,
            dir.path(),
        );
        assert_eq!(added["result"]["transport"]["command"], "npx");
        assert_eq!(added["result"]["transport"]["args"][0], "-y");
    }

    #[test]
    fn should_reject_a_name_that_would_be_awkward_as_a_config_key() {
        // The name becomes a TOML key and is how the agent refers to the
        // server, so a bad one is a lasting nuisance.
        let dir = tempdir().expect("tempdir");
        let reply = call(
            r#"{"method":"connector/add","id":1,"params":
                {"name":"my server!","transport":{"kind":"http","url":"https://x"}}}"#,
            dir.path(),
        );
        assert!(reply["error"].is_object());
    }

    #[test]
    fn should_reject_a_transport_it_cannot_start() {
        let dir = tempdir().expect("tempdir");
        for params in [
            r#"{"name":"x","transport":{"kind":"http"}}"#,
            r#"{"name":"x","transport":{"kind":"stdio"}}"#,
            r#"{"name":"x","transport":{"kind":"carrier-pigeon"}}"#,
        ] {
            let reply = call(
                &format!(r#"{{"method":"connector/add","id":1,"params":{params}}}"#),
                dir.path(),
            );
            assert!(reply["error"].is_object(), "{params} should be refused");
        }
    }

    #[test]
    fn should_turn_a_connector_off_without_losing_its_configuration() {
        let dir = tempdir().expect("tempdir");
        add_one(dir.path());

        let toggled = call(
            r#"{"method":"connector/setEnabled","id":2,"params":{"name":"figma","enabled":false}}"#,
            dir.path(),
        );
        assert_eq!(toggled["result"]["enabled"], false);

        let listed = call(r#"{"method":"connector/list","id":3}"#, dir.path());
        let row = &listed["result"]["data"][0];
        assert_eq!(row["enabled"], false);
        assert_eq!(
            row["transport"]["url"], "https://mcp.figma.com/mcp",
            "how it connects must survive being turned off"
        );
    }

    #[test]
    fn should_say_a_restart_is_needed_because_servers_start_with_the_session() {
        let dir = tempdir().expect("tempdir");
        add_one(dir.path());
        let toggled = call(
            r#"{"method":"connector/setEnabled","id":2,"params":{"name":"figma","enabled":true}}"#,
            dir.path(),
        );
        assert_eq!(toggled["result"]["restartRequired"], true);
    }

    #[test]
    fn should_remove_a_connector_and_report_an_unknown_one() {
        let dir = tempdir().expect("tempdir");
        add_one(dir.path());

        let removed = call(
            r#"{"method":"connector/remove","id":2,"params":{"name":"figma"}}"#,
            dir.path(),
        );
        assert!(removed["result"].is_object());
        assert!(
            call(r#"{"method":"connector/list","id":3}"#, dir.path())["result"]["data"]
                .as_array()
                .expect("data")
                .is_empty()
        );

        let missing = call(
            r#"{"method":"connector/remove","id":4,"params":{"name":"figma"}}"#,
            dir.path(),
        );
        assert!(missing["error"].is_object());
    }

    #[test]
    fn should_keep_the_rest_of_the_config_file_when_editing_connectors() {
        // The edit rewrites one table; a comment or unrelated setting losing
        // its place would make the file untrustworthy to edit by hand.
        let dir = tempdir().expect("tempdir");
        std::fs::write(
            dir.path().join("config.toml"),
            "# my notes\nmodel = \"some-model\"\n",
        )
        .expect("write");

        add_one(dir.path());

        let after = std::fs::read_to_string(dir.path().join("config.toml")).expect("read");
        assert!(after.contains("# my notes"), "got: {after}");
        assert!(after.contains("model = \"some-model\""), "got: {after}");
        assert!(after.contains("figma"), "got: {after}");
    }

    #[test]
    fn should_offer_a_catalog_of_connectors_that_exist() {
        let catalogued = call(
            r#"{"method":"connector/catalog","id":1}"#,
            Path::new("/tmp"),
        );
        let rows = catalogued["result"]["data"].as_array().expect("data");
        assert!(rows.iter().any(|row| row["id"] == "figma"));
        assert!(
            rows.iter().all(|row| row["transport"]["kind"].is_string()),
            "every entry must say how it is started"
        );
    }
}
