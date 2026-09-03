//! Machines that serve models.
//!
//! A server is remembered by two addresses, because they answer different
//! questions. The runtime's URL says what models are installed and can be told
//! to fetch more. An SSH alias says whether the runtime itself can be
//! installed, started or repaired — which HTTP cannot do, and which is exactly
//! what is needed when the runtime is the thing that is broken.
//!
//! Only the alias is stored, never a key or a password. It is looked up in the
//! user's own `~/.ssh/config`, so a machine already reachable as `ssh gpu5090`
//! needs nothing new written down.

use serde::Deserialize;
use serde::Serialize;
use std::path::Path;
use std::path::PathBuf;

use crate::scheduled::now_seconds;

const STORE_FILE: &str = "servers.json";

/// A machine that serves models.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Server {
    pub id: String,
    /// Short label for the list.
    pub name: String,
    /// Where the runtime answers, for example `https://llm.example.com`.
    pub base_url: String,
    /// Which runtime is expected there; matches the runtime catalogue.
    #[serde(default = "default_runtime")]
    pub runtime: String,
    /// An alias from `~/.ssh/config`, when this machine can also be reached by
    /// shell. Absent means model management only.
    #[serde(default)]
    pub ssh_alias: Option<String>,
    #[serde(default)]
    pub created_at: u64,
}

fn default_runtime() -> String {
    "ollama".to_string()
}

fn store_path(opencli_home: &Path) -> PathBuf {
    opencli_home.join(STORE_FILE)
}

/// Read every stored server. A missing or corrupt file yields an empty list:
/// losing the list should not stop the app, and nothing about a server lives
/// only here.
pub fn load(opencli_home: &Path) -> Vec<Server> {
    std::fs::read_to_string(store_path(opencli_home))
        .ok()
        .and_then(|contents| serde_json::from_str(&contents).ok())
        .unwrap_or_default()
}

pub fn save(opencli_home: &Path, servers: &[Server]) -> std::io::Result<()> {
    std::fs::write(
        store_path(opencli_home),
        serde_json::to_string_pretty(servers)?,
    )
}

pub fn create(
    opencli_home: &Path,
    name: String,
    base_url: String,
    runtime: String,
    ssh_alias: Option<String>,
) -> std::io::Result<Server> {
    let server = Server {
        id: format!("srv-{}-{}", now_seconds(), rand_suffix()),
        name,
        base_url,
        runtime,
        ssh_alias,
        created_at: now_seconds(),
    };
    let mut servers = load(opencli_home);
    servers.push(server.clone());
    save(opencli_home, &servers)?;
    Ok(server)
}

pub fn get(opencli_home: &Path, id: &str) -> Option<Server> {
    load(opencli_home)
        .into_iter()
        .find(|server| server.id == id)
}

pub fn update(
    opencli_home: &Path,
    id: &str,
    name: Option<String>,
    base_url: Option<String>,
    ssh_alias: Option<Option<String>>,
) -> std::io::Result<Option<Server>> {
    let mut servers = load(opencli_home);
    let Some(server) = servers.iter_mut().find(|server| server.id == id) else {
        return Ok(None);
    };
    if let Some(name) = name {
        server.name = name;
    }
    if let Some(base_url) = base_url {
        server.base_url = base_url;
    }
    // Nested option: absent means "leave it", `Some(None)` means "remove it".
    if let Some(alias) = ssh_alias {
        server.ssh_alias = alias;
    }
    let updated = server.clone();
    save(opencli_home, &servers)?;
    Ok(Some(updated))
}

pub fn delete(opencli_home: &Path, id: &str) -> std::io::Result<bool> {
    let mut servers = load(opencli_home);
    let before = servers.len();
    servers.retain(|server| server.id != id);
    let removed = servers.len() != before;
    if removed {
        save(opencli_home, &servers)?;
    }
    Ok(removed)
}

fn rand_suffix() -> String {
    use std::collections::hash_map::RandomState;
    use std::hash::BuildHasher;
    format!(
        "{:x}",
        RandomState::new().hash_one(now_seconds()) & 0xffffff
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    fn make(home: &Path, alias: Option<&str>) -> Server {
        create(
            home,
            "GPU Box".into(),
            "https://llm.example.com".into(),
            "ollama".into(),
            alias.map(str::to_string),
        )
        .expect("create")
    }

    #[test]
    fn should_return_nothing_before_a_server_is_added() {
        let dir = tempdir().expect("tempdir");
        assert!(load(dir.path()).is_empty());
    }

    #[test]
    fn should_round_trip_a_server_through_disk() {
        let dir = tempdir().expect("tempdir");
        let created = make(dir.path(), Some("gpu5090"));
        assert_eq!(load(dir.path()), vec![created]);
    }

    #[test]
    fn should_store_only_the_alias_never_a_credential() {
        // The alias is looked up in the user's own ssh config; a key or
        // password here would be a secret this app had no need to hold.
        let dir = tempdir().expect("tempdir");
        make(dir.path(), Some("gpu5090"));
        let raw = std::fs::read_to_string(store_path(dir.path())).expect("read");
        assert!(raw.contains("gpu5090"));
        for secret in ["password", "privateKey", "private_key", "passphrase"] {
            assert!(!raw.contains(secret), "`{secret}` must never be stored");
        }
    }

    #[test]
    fn should_allow_a_server_with_no_shell_access() {
        // Model management works over HTTP alone; requiring an alias would
        // shut out anyone who only has the endpoint.
        let dir = tempdir().expect("tempdir");
        let created = make(dir.path(), None);
        assert!(created.ssh_alias.is_none());
    }

    #[test]
    fn should_tell_leaving_the_alias_alone_from_removing_it() {
        let dir = tempdir().expect("tempdir");
        let created = make(dir.path(), Some("gpu5090"));

        let untouched = update(dir.path(), &created.id, Some("Renamed".into()), None, None)
            .expect("update")
            .expect("exists");
        assert_eq!(untouched.ssh_alias.as_deref(), Some("gpu5090"));

        let cleared = update(dir.path(), &created.id, None, None, Some(None))
            .expect("update")
            .expect("exists");
        assert!(cleared.ssh_alias.is_none());
    }

    #[test]
    fn should_report_an_unknown_id_rather_than_creating_one() {
        let dir = tempdir().expect("tempdir");
        assert!(
            update(dir.path(), "nope", None, None, None)
                .expect("update")
                .is_none()
        );
        assert!(!delete(dir.path(), "nope").expect("delete"));
    }

    #[test]
    fn should_default_the_runtime_for_a_server_stored_before_it_was_recorded() {
        // An older file has no `runtime` key; reading it must not fail.
        let dir = tempdir().expect("tempdir");
        std::fs::write(
            store_path(dir.path()),
            r#"[{"id":"srv-1","name":"Old","base_url":"http://x:11434","created_at":1}]"#,
        )
        .expect("write");
        assert_eq!(load(dir.path())[0].runtime, "ollama");
    }

    #[test]
    fn should_ignore_a_corrupt_store_instead_of_failing_to_start() {
        let dir = tempdir().expect("tempdir");
        std::fs::write(store_path(dir.path()), "{ not json").expect("write");
        assert!(load(dir.path()).is_empty());
    }
}
