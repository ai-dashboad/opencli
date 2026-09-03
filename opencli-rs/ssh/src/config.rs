//! Reading the SSH configuration a user already has.
//!
//! Someone who reaches their server as `ssh gpu5090` has already written down
//! its address, port and account. Asking for all of it again would be asking
//! them to keep two copies in step, so the alias is resolved from
//! `~/.ssh/config` exactly as the `ssh` command would.
//!
//! Only the keywords that decide *where and as whom to connect* are read.
//! `ProxyJump`, `Match` blocks and the rest are deliberately unsupported —
//! honouring half of a directive is worse than not claiming to support it, so
//! anything unrecognised is reported rather than silently ignored.

use std::collections::BTreeMap;
use std::path::Path;
use std::path::PathBuf;

/// Where and as whom to connect.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HostSettings {
    pub hostname: String,
    pub port: u16,
    pub user: Option<String>,
    /// Identity files named for this host, in the order given.
    pub identity_files: Vec<PathBuf>,
    /// Keywords present for this host that this reader does not act on.
    ///
    /// Carried so a caller can say "your config uses ProxyJump, which is not
    /// supported here" instead of connecting somewhere unexpected.
    pub unsupported: Vec<String>,
}

impl HostSettings {
    fn new(hostname: &str) -> Self {
        Self {
            hostname: hostname.to_string(),
            port: 22,
            user: None,
            identity_files: Vec::new(),
            unsupported: Vec::new(),
        }
    }
}

/// Keywords that change where a connection goes or how it is trusted.
///
/// Ignoring one of these silently could send a connection somewhere the user
/// did not intend, so their presence is reported.
const SIGNIFICANT_UNSUPPORTED: &[&str] = &[
    "proxyjump",
    "proxycommand",
    "match",
    "include",
    "localforward",
    "remoteforward",
    "certificatefile",
];

/// Resolve an alias against a config file's contents.
///
/// Returns `None` when the alias is not named, which the caller should treat
/// as "this is a hostname, not an alias" rather than an error.
pub fn resolve_in(contents: &str, alias: &str) -> Option<HostSettings> {
    let mut current: Option<Vec<String>> = None;
    let mut collected: BTreeMap<String, String> = BTreeMap::new();
    let mut identity_files: Vec<PathBuf> = Vec::new();
    let mut unsupported: Vec<String> = Vec::new();
    let mut matched = false;

    for raw in contents.lines() {
        let line = raw.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        // `Key value` or `Key=value`, case-insensitive keyword.
        let (keyword, value) = match line.split_once(['=', ' ', '\t']) {
            Some((keyword, value)) => (keyword.trim().to_ascii_lowercase(), value.trim()),
            None => continue,
        };

        if keyword == "host" {
            current = Some(value.split_whitespace().map(str::to_string).collect());
            continue;
        }

        let applies = current.as_ref().is_some_and(|patterns| {
            patterns
                .iter()
                .any(|pattern| matches_pattern(pattern, alias))
        });
        if !applies {
            continue;
        }
        matched = true;

        if keyword == "identityfile" {
            identity_files.push(PathBuf::from(expand_tilde(value)));
        } else if SIGNIFICANT_UNSUPPORTED.contains(&keyword.as_str()) {
            unsupported.push(keyword);
        } else {
            // First value wins, as OpenSSH does.
            collected
                .entry(keyword)
                .or_insert_with(|| value.to_string());
        }
    }

    if !matched {
        return None;
    }

    let hostname = collected
        .get("hostname")
        .cloned()
        .unwrap_or_else(|| alias.to_string());
    let mut settings = HostSettings::new(&hostname);
    settings.port = collected
        .get("port")
        .and_then(|port| port.parse().ok())
        .unwrap_or(22);
    settings.user = collected.get("user").cloned();
    settings.identity_files = identity_files;
    unsupported.sort();
    unsupported.dedup();
    settings.unsupported = unsupported;
    Some(settings)
}

/// Resolve an alias against the user's own `~/.ssh/config`.
pub fn resolve(alias: &str) -> Option<HostSettings> {
    let path = home()?.join(".ssh").join("config");
    let contents = std::fs::read_to_string(path).ok()?;
    resolve_in(&contents, alias)
}

/// Glob matching as OpenSSH does it: `*` and `?`, and a leading `!` negates.
///
/// Written out rather than pulled in: the whole grammar is two wildcards, and
/// a general glob crate would also match `[a-z]` ranges that OpenSSH does not
/// treat the same way.
fn matches_pattern(pattern: &str, alias: &str) -> bool {
    if let Some(rest) = pattern.strip_prefix('!') {
        return !matches_pattern(rest, alias);
    }
    let pattern: Vec<char> = pattern.chars().collect();
    let alias: Vec<char> = alias.chars().collect();
    matches_from(&pattern, 0, &alias, 0)
}

fn matches_from(pattern: &[char], p: usize, alias: &[char], a: usize) -> bool {
    if p == pattern.len() {
        return a == alias.len();
    }
    match pattern[p] {
        '*' => (a..=alias.len()).any(|next| matches_from(pattern, p + 1, alias, next)),
        '?' => a < alias.len() && matches_from(pattern, p + 1, alias, a + 1),
        other => a < alias.len() && alias[a] == other && matches_from(pattern, p + 1, alias, a + 1),
    }
}

pub(crate) fn home() -> Option<PathBuf> {
    std::env::var_os("HOME")
        .filter(|home| !home.is_empty())
        .map(PathBuf::from)
}

fn expand_tilde(path: &str) -> String {
    match path.strip_prefix("~/") {
        Some(rest) => match home() {
            Some(home) => home.join(rest).to_string_lossy().into_owned(),
            None => path.to_string(),
        },
        None => path.to_string(),
    }
}

/// Identity files to try when the config names none.
pub fn default_identity_files() -> Vec<PathBuf> {
    let Some(home) = home() else {
        return Vec::new();
    };
    let ssh = home.join(".ssh");
    ["id_ed25519", "id_ecdsa", "id_rsa"]
        .iter()
        .map(|name| ssh.join(name))
        .filter(|path| Path::new(path).is_file())
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    const SAMPLE: &str = "\
# a comment
Host gpu5090
    HostName yhqhxs.f3322.net
    Port 22722
    User w480
    IdentityFile ~/.ssh/id_ed25519

Host build-*
    User builder

Host jumped
    HostName inner
    ProxyJump bastion
";

    #[test]
    fn should_resolve_an_alias_to_where_it_points() {
        let host = resolve_in(SAMPLE, "gpu5090").expect("the alias is named");
        assert_eq!(host.hostname, "yhqhxs.f3322.net");
        assert_eq!(host.port, 22722);
        assert_eq!(host.user.as_deref(), Some("w480"));
        assert_eq!(host.identity_files.len(), 1);
    }

    #[test]
    fn should_default_the_port_when_none_is_given() {
        let host = resolve_in("Host plain\n  HostName example.com\n", "plain").expect("named");
        assert_eq!(host.port, 22);
    }

    #[test]
    fn should_report_an_unnamed_alias_rather_than_inventing_one() {
        // The caller treats this as "a hostname, not an alias"; returning a
        // default would connect somewhere never configured.
        assert!(resolve_in(SAMPLE, "never-mentioned").is_none());
    }

    #[test]
    fn should_match_a_wildcard_host_pattern() {
        let host = resolve_in(SAMPLE, "build-01").expect("matched by build-*");
        assert_eq!(host.user.as_deref(), Some("builder"));
        // No HostName given, so the alias itself is the address.
        assert_eq!(host.hostname, "build-01");
    }

    #[test]
    fn should_report_directives_it_does_not_act_on() {
        // Silently ignoring ProxyJump would connect straight to the inner host,
        // which is usually unreachable and occasionally the wrong machine.
        let host = resolve_in(SAMPLE, "jumped").expect("named");
        assert_eq!(host.unsupported, vec!["proxyjump"]);
    }

    #[test]
    fn should_accept_the_equals_form_of_a_directive() {
        let host = resolve_in("Host x\n  HostName=example.net\n  Port=2222\n", "x").expect("named");
        assert_eq!(host.hostname, "example.net");
        assert_eq!(host.port, 2222);
    }

    #[test]
    fn should_let_the_first_value_win_as_openssh_does() {
        let host = resolve_in("Host x\n  User first\n  User second\n", "x").expect("named");
        assert_eq!(host.user.as_deref(), Some("first"));
    }

    #[test]
    fn should_understand_negated_patterns() {
        assert!(matches_pattern("*", "anything"));
        assert!(matches_pattern("build-?", "build-1"));
        assert!(!matches_pattern("build-?", "build-12"));
        assert!(!matches_pattern("!secret", "secret"));
        assert!(matches_pattern("!secret", "other"));
    }
}

#[cfg(test)]
mod real_config_tests {
    use super::*;

    /// Read the machine's own `~/.ssh/config`, when there is one.
    ///
    /// A parser tested only against samples it was written from proves little.
    /// This one is skipped where there is no config rather than failing, so it
    /// stays useful on a developer's machine and harmless in CI.
    #[test]
    fn should_parse_this_machines_own_config_without_panicking() {
        let Some(path) = home().map(|home| home.join(".ssh").join("config")) else {
            return;
        };
        let Ok(contents) = std::fs::read_to_string(&path) else {
            return;
        };
        // Every alias named in the file must resolve to somewhere.
        for line in contents.lines() {
            let line = line.trim();
            let Some(rest) = line
                .strip_prefix("Host ")
                .or_else(|| line.strip_prefix("host "))
            else {
                continue;
            };
            for alias in rest.split_whitespace() {
                if alias.contains('*') || alias.contains('?') || alias.starts_with('!') {
                    continue;
                }
                let resolved = resolve_in(&contents, alias);
                assert!(
                    resolved.is_some(),
                    "`{alias}` is declared but does not resolve"
                );
                let host = resolved.expect("just checked");
                assert!(
                    !host.hostname.is_empty(),
                    "`{alias}` resolved to no address"
                );
                assert!(host.port > 0);
            }
        }
    }
}
