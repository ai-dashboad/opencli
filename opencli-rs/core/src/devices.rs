//! Devices paired with this machine.
//!
//! The gateway's token is generated on every start and printed once, which is
//! right for a URL you paste into a browser beside it and useless for a phone:
//! the phone would be locked out by the next restart, and the way back in is
//! to go and read a terminal.
//!
//! So a paired device gets a token of its own that lasts, and can be revoked
//! on its own. One per device rather than one shared secret, because "revoke"
//! has to mean something narrower than "lock everybody out", and because
//! knowing which device was last seen when is the only way to notice one you
//! do not recognise.
//!
//! **A token stored here is as good as a password to this machine.** Anything
//! holding one can make the agent run commands as the person who paired it.
//! Two consequences that are not negotiable and are enforced below: the token
//! is compared in constant time, and it is never handed back out — pairing is
//! the one moment it exists in the open.

use serde::Deserialize;
use serde::Serialize;
use std::path::Path;
use std::path::PathBuf;

use crate::scheduled::now_seconds;

const STORE_FILE: &str = "devices.json";

/// How long an unclaimed pairing offer stands.
///
/// Short, because it is a token in the open — on a screen, in a QR code — and
/// the window in which it is worth anything should be about as long as it takes
/// to pick up a phone.
pub const PAIRING_VALID_SECONDS: u64 = 180;

/// A device that may connect, and what is known about it.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Device {
    pub id: String,
    /// What the person called it. "Phone" is a better answer than a user agent.
    pub name: String,
    /// The secret this device presents. Never sent to a client.
    #[serde(default)]
    token: String,
    pub paired_at: u64,
    #[serde(default)]
    pub last_seen: Option<u64>,
}

impl Device {
    /// What a client may be told about a device: everything but the secret.
    pub fn describe(&self) -> (String, String, u64, Option<u64>) {
        (
            self.id.clone(),
            self.name.clone(),
            self.paired_at,
            self.last_seen,
        )
    }
}

fn store_path(opencli_home: &Path) -> PathBuf {
    opencli_home.join(STORE_FILE)
}

pub fn load(opencli_home: &Path) -> Vec<Device> {
    std::fs::read_to_string(store_path(opencli_home))
        .ok()
        .and_then(|contents| serde_json::from_str(&contents).ok())
        .unwrap_or_default()
}

fn save(opencli_home: &Path, devices: &[Device]) -> std::io::Result<()> {
    std::fs::write(
        store_path(opencli_home),
        serde_json::to_string_pretty(devices)?,
    )?;
    // Readable by this user only. A file of long-lived credentials left
    // world-readable is a hole that nothing else here can close.
    restrict(&store_path(opencli_home))
}

#[cfg(unix)]
fn restrict(path: &Path) -> std::io::Result<()> {
    use std::os::unix::fs::PermissionsExt;
    std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o600))
}

#[cfg(not(unix))]
fn restrict(_path: &Path) -> std::io::Result<()> {
    Ok(())
}

/// Pair a device and return its token — the one time it is ever produced.
pub fn pair(opencli_home: &Path, name: String) -> std::io::Result<(Device, String)> {
    let token = secret();
    let device = Device {
        id: format!("dev-{}-{}", now_seconds(), &token[..6]),
        name,
        token: token.clone(),
        paired_at: now_seconds(),
        last_seen: None,
    };
    let mut devices = load(opencli_home);
    devices.push(device.clone());
    save(opencli_home, &devices)?;
    Ok((device, token))
}

/// Whether this token belongs to a paired device, and which.
///
/// Compared in constant time. A comparison that stops at the first wrong byte
/// tells anyone who can measure it how much of a guess was right, which turns
/// a secret of this length into a few thousand requests.
pub fn recognise(opencli_home: &Path, token: &str) -> Option<Device> {
    let offered = token.trim();
    if offered.is_empty() {
        return None;
    }
    let mut found = None;
    for device in load(opencli_home) {
        // Every device is checked, without breaking early, for the same reason
        // the bytes are.
        if constant_time_eq(device.token.as_bytes(), offered.as_bytes()) {
            found = Some(device);
        }
    }
    found
}

/// Note that a device connected, so an unfamiliar one can be spotted.
pub fn seen(opencli_home: &Path, id: &str) -> std::io::Result<()> {
    let mut devices = load(opencli_home);
    if let Some(device) = devices.iter_mut().find(|device| device.id == id) {
        device.last_seen = Some(now_seconds());
        save(opencli_home, &devices)?;
    }
    Ok(())
}

/// Revoke one device. Everything else keeps working.
pub fn revoke(opencli_home: &Path, id: &str) -> std::io::Result<bool> {
    let mut devices = load(opencli_home);
    let before = devices.len();
    devices.retain(|device| device.id != id);
    let removed = devices.len() != before;
    if removed {
        save(opencli_home, &devices)?;
    }
    Ok(removed)
}

fn constant_time_eq(a: &[u8], b: &[u8]) -> bool {
    if a.len() != b.len() {
        return false;
    }
    let mut difference = 0u8;
    for (left, right) in a.iter().zip(b) {
        difference |= left ^ right;
    }
    difference == 0
}

fn secret() -> String {
    use rand::Rng;
    const ALPHABET: &[u8] = b"abcdefghijkmnopqrstuvwxyz23456789";
    let mut rng = rand::rng();
    (0..40)
        .map(|_| ALPHABET[rng.random_range(0..ALPHABET.len())] as char)
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn should_let_a_paired_device_back_in_after_a_restart() {
        // The whole point. The gateway's own token is new on every start, so a
        // phone paired yesterday would be locked out this morning with no way
        // back except reading a terminal.
        let dir = tempdir().expect("tempdir");
        let (device, token) = pair(dir.path(), "Phone".into()).expect("pair");

        let recognised = recognise(dir.path(), &token).expect("recognised");
        assert_eq!(recognised.id, device.id);
    }

    #[test]
    fn should_never_hand_a_token_back_out() {
        // Pairing is the one moment it exists in the open. Anything that can
        // read it afterwards has read a password to this machine.
        let dir = tempdir().expect("tempdir");
        pair(dir.path(), "Phone".into()).expect("pair");

        let stored = &load(dir.path())[0];
        let (id, name, paired, seen) = stored.describe();
        assert!(!id.is_empty() && name == "Phone" && paired > 0 && seen.is_none());
        // `describe` is the only way out, and the token is not in it.
        let described = format!("{id}{name}{paired}{seen:?}");
        assert!(!described.contains(&stored.token));
    }

    #[test]
    fn should_revoke_one_device_without_locking_out_the_rest() {
        // "Revoke" has to mean something narrower than "lock everybody out",
        // or nobody will use it when they need to.
        let dir = tempdir().expect("tempdir");
        let (phone, phone_token) = pair(dir.path(), "Phone".into()).expect("pair");
        let (_, tablet_token) = pair(dir.path(), "Tablet".into()).expect("pair");

        assert!(revoke(dir.path(), &phone.id).expect("revoke"));

        assert!(recognise(dir.path(), &phone_token).is_none());
        assert!(recognise(dir.path(), &tablet_token).is_some());
    }

    #[test]
    fn should_refuse_a_token_nobody_was_given() {
        let dir = tempdir().expect("tempdir");
        pair(dir.path(), "Phone".into()).expect("pair");

        assert!(recognise(dir.path(), "not-a-real-token").is_none());
        assert!(recognise(dir.path(), "").is_none());
        assert!(recognise(dir.path(), "   ").is_none());
    }

    #[test]
    fn should_give_two_devices_different_tokens() {
        let dir = tempdir().expect("tempdir");
        let (_, one) = pair(dir.path(), "Phone".into()).expect("pair");
        let (_, two) = pair(dir.path(), "Phone".into()).expect("pair");
        assert_ne!(one, two, "one shared secret is not a device list");
    }

    #[test]
    fn should_record_when_a_device_was_last_seen() {
        // The only way to notice one you do not recognise.
        let dir = tempdir().expect("tempdir");
        let (device, _) = pair(dir.path(), "Phone".into()).expect("pair");
        assert!(device.last_seen.is_none());

        seen(dir.path(), &device.id).expect("seen");
        assert!(load(dir.path())[0].last_seen.is_some());
    }

    #[test]
    fn should_compare_tokens_without_stopping_at_the_first_wrong_byte() {
        // A comparison that returns early tells anyone timing it how much of a
        // guess was right, which turns a secret of this length into a few
        // thousand requests.
        assert!(constant_time_eq(b"abcdef", b"abcdef"));
        assert!(!constant_time_eq(b"abcdef", b"abcdeg"));
        assert!(!constant_time_eq(b"abcdef", b"zbcdef"));
        assert!(!constant_time_eq(b"abcdef", b"abcde"));
    }

    #[test]
    fn should_keep_the_store_to_this_user() {
        let dir = tempdir().expect("tempdir");
        pair(dir.path(), "Phone".into()).expect("pair");

        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let mode = std::fs::metadata(store_path(dir.path()))
                .expect("metadata")
                .permissions()
                .mode();
            assert_eq!(mode & 0o077, 0, "a file of credentials must not be shared");
        }
    }

    #[test]
    fn should_survive_a_store_that_cannot_be_read() {
        let dir = tempdir().expect("tempdir");
        std::fs::write(store_path(dir.path()), "{ not json").expect("write");
        assert!(load(dir.path()).is_empty());
    }
}
