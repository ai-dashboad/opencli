//! Deciding whether a server is the one we connected to last time.
//!
//! This is the part that must not be skipped. Without it, anything able to
//! answer on the address gets handed the session — and, for this app, the
//! commands the agent was going to run on your machine's behalf.
//!
//! Three outcomes, and they are deliberately different:
//!
//! - **Known** — the key matches what is recorded. Connect.
//! - **Unknown** — nothing recorded. Ask, showing the fingerprint, and record
//!   it only if the user says yes. Never record silently.
//! - **Changed** — something recorded, and it differs. Refuse, and do not offer
//!   to overwrite: either the server was rebuilt, which the user should confirm
//!   by hand, or someone is between us, which no dialog should make easy to
//!   click past.

use std::path::PathBuf;

/// What the record says about a host key.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Verdict {
    /// Recorded, and it matches.
    Known,
    /// Not recorded. Carries the fingerprint to show before trusting it.
    Unknown { fingerprint: String },
    /// Recorded, and different. Carries both so the user can see the change.
    Changed {
        recorded: String,
        offered: String,
        /// Where the old entry lives, so the user can remove it themselves.
        file: PathBuf,
        line: usize,
    },
}

/// A host key entry read from `known_hosts`.
struct Entry {
    patterns: Vec<String>,
    algorithm: String,
    key: String,
    line: usize,
}

fn parse(contents: &str) -> Vec<Entry> {
    contents
        .lines()
        .enumerate()
        .filter_map(|(index, raw)| {
            let line = raw.trim();
            if line.is_empty() || line.starts_with('#') {
                return None;
            }
            // Revocation and CA markers change what a line means; treating one
            // as an ordinary key would trust a key that was explicitly revoked.
            if line.starts_with('@') {
                return None;
            }
            let mut parts = line.split_whitespace();
            let hosts = parts.next()?;
            let algorithm = parts.next()?;
            let key = parts.next()?;
            Some(Entry {
                patterns: hosts.split(',').map(str::to_string).collect(),
                algorithm: algorithm.to_string(),
                key: key.to_string(),
                line: index + 1,
            })
        })
        .collect()
}

/// How a host is written in `known_hosts`: bare for port 22, bracketed
/// otherwise.
pub fn host_pattern(hostname: &str, port: u16) -> String {
    if port == 22 {
        hostname.to_string()
    } else {
        format!("[{hostname}]:{port}")
    }
}

/// Check an offered key against recorded entries.
///
/// `offered_key` is the base64 body, and `algorithm` its type — the two fields
/// as they appear in the file.
pub fn check_in(
    contents: &str,
    file: PathBuf,
    hostname: &str,
    port: u16,
    algorithm: &str,
    offered_key: &str,
) -> Verdict {
    let pattern = host_pattern(hostname, port);
    let entries = parse(contents);

    // A hashed `known_hosts` (HashKnownHosts yes) stores `|1|salt|hash`, which
    // cannot be compared without HMAC. Those entries are skipped rather than
    // mistaken for a mismatch, so a hashed file reads as "unknown" and asks
    // rather than refusing every connection.
    let relevant: Vec<&Entry> = entries
        .iter()
        .filter(|entry| {
            entry
                .patterns
                .iter()
                .any(|candidate| !candidate.starts_with("|1|") && candidate == &pattern)
        })
        .collect();

    if relevant.is_empty() {
        return Verdict::Unknown {
            fingerprint: fingerprint(algorithm, offered_key),
        };
    }

    // Only entries of the same type can agree or disagree; a host may record
    // an ed25519 key and an rsa one, and neither contradicts the other.
    let same_type: Vec<&&Entry> = relevant
        .iter()
        .filter(|entry| entry.algorithm == algorithm)
        .collect();
    if same_type.is_empty() {
        return Verdict::Unknown {
            fingerprint: fingerprint(algorithm, offered_key),
        };
    }
    if same_type.iter().any(|entry| entry.key == offered_key) {
        return Verdict::Known;
    }

    let recorded = same_type[0];
    Verdict::Changed {
        recorded: fingerprint(&recorded.algorithm, &recorded.key),
        offered: fingerprint(algorithm, offered_key),
        file,
        line: recorded.line,
    }
}

/// Check against the user's own `~/.ssh/known_hosts`.
pub fn check(hostname: &str, port: u16, algorithm: &str, offered_key: &str) -> Verdict {
    let Some(path) = known_hosts_path() else {
        return Verdict::Unknown {
            fingerprint: fingerprint(algorithm, offered_key),
        };
    };
    let contents = std::fs::read_to_string(&path).unwrap_or_default();
    check_in(&contents, path, hostname, port, algorithm, offered_key)
}

pub fn known_hosts_path() -> Option<PathBuf> {
    crate::config::home().map(|home| home.join(".ssh").join("known_hosts"))
}

/// Record a key the user has agreed to trust.
///
/// Appends, never rewrites: the file is shared with `ssh` itself, and losing
/// an entry would silently downgrade the security of a connection made
/// elsewhere.
pub fn remember(hostname: &str, port: u16, algorithm: &str, key: &str) -> std::io::Result<()> {
    use std::io::Write;
    let Some(path) = known_hosts_path() else {
        return Err(std::io::Error::other("no home directory to record in"));
    };
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let mut file = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(&path)?;
    writeln!(file, "{} {algorithm} {key}", host_pattern(hostname, port))
}

/// A short, comparable form of a key, for showing to a person.
///
/// Not the SHA-256 form `ssh-keygen` prints — computing that needs a hash of
/// the decoded key, and this crate would rather show something plainly derived
/// from the recorded text than something that looks official and is wrong.
fn fingerprint(algorithm: &str, key: &str) -> String {
    let head: String = key.chars().take(12).collect();
    let tail: String = key.chars().rev().take(12).collect::<Vec<_>>().into_iter().rev().collect();
    format!("{algorithm} {head}…{tail}")
}

#[cfg(test)]
mod tests {
    use super::*;

    const KEY_A: &str = "AAAAC3NzaC1lZDI1NTE5AAAAIKAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
    const KEY_B: &str = "AAAAC3NzaC1lZDI1NTE5AAAAIKBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB";

    fn at(contents: &str, port: u16, key: &str) -> Verdict {
        check_in(
            contents,
            PathBuf::from("/tmp/known_hosts"),
            "gpu.example.com",
            port,
            "ssh-ed25519",
            key,
        )
    }

    #[test]
    fn should_accept_a_key_it_has_seen_before() {
        let file = format!("gpu.example.com ssh-ed25519 {KEY_A}\n");
        assert_eq!(at(&file, 22, KEY_A), Verdict::Known);
    }

    #[test]
    fn should_ask_about_a_host_it_has_never_seen() {
        assert!(matches!(at("", 22, KEY_A), Verdict::Unknown { .. }));
    }

    #[test]
    fn should_refuse_when_the_key_has_changed() {
        // Either the server was rebuilt, or something is in the middle. Both
        // deserve a human, not a button.
        let file = format!("gpu.example.com ssh-ed25519 {KEY_A}\n");
        match at(&file, 22, KEY_B) {
            Verdict::Changed { line, .. } => assert_eq!(line, 1),
            other => panic!("expected a mismatch, got {other:?}"),
        }
    }

    #[test]
    fn should_treat_a_nonstandard_port_as_its_own_host() {
        // OpenSSH records `[host]:port`; matching the bare name would accept a
        // key recorded for a different service on the same machine.
        let file = format!("[gpu.example.com]:22722 ssh-ed25519 {KEY_A}\n");
        assert_eq!(at(&file, 22722, KEY_A), Verdict::Known);
        assert!(matches!(at(&file, 22, KEY_A), Verdict::Unknown { .. }));
    }

    #[test]
    fn should_match_a_host_listed_among_others_on_one_line() {
        let file = format!("other.example.com,gpu.example.com ssh-ed25519 {KEY_A}\n");
        assert_eq!(at(&file, 22, KEY_A), Verdict::Known);
    }

    #[test]
    fn should_not_confuse_two_key_types_for_a_mismatch() {
        // A host may record both an ed25519 and an rsa key; neither
        // contradicts the other.
        let file = format!("gpu.example.com ssh-rsa {KEY_B}\n");
        assert!(matches!(at(&file, 22, KEY_A), Verdict::Unknown { .. }));
    }

    #[test]
    fn should_ignore_revocation_markers_rather_than_trusting_them() {
        // `@revoked` says the opposite of what an ordinary line says; reading
        // it as a normal entry would trust a key that was explicitly withdrawn.
        let file = format!("@revoked gpu.example.com ssh-ed25519 {KEY_A}\n");
        assert!(matches!(at(&file, 22, KEY_A), Verdict::Unknown { .. }));
    }

    #[test]
    fn should_ask_rather_than_refuse_when_the_file_is_hashed() {
        // A hashed entry cannot be compared without HMAC. Reading it as a
        // mismatch would make every connection fail for anyone using
        // `HashKnownHosts yes`.
        let file = format!("|1|c2FsdA==|aGFzaA== ssh-ed25519 {KEY_A}\n");
        assert!(matches!(at(&file, 22, KEY_A), Verdict::Unknown { .. }));
    }

    #[test]
    fn should_ignore_comments_and_blank_lines() {
        let file = format!("# a note\n\ngpu.example.com ssh-ed25519 {KEY_A}\n");
        assert_eq!(at(&file, 22, KEY_A), Verdict::Known);
    }

    #[test]
    fn should_show_a_fingerprint_that_distinguishes_two_keys() {
        let a = fingerprint("ssh-ed25519", KEY_A);
        let b = fingerprint("ssh-ed25519", KEY_B);
        assert_ne!(a, b, "a fingerprint nobody can tell apart is no use");
    }
}
