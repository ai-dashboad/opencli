//! API keys, kept out of `config.toml`.
//!
//! A provider's key is read from an environment variable — `env_key` names it
//! — which is the right place for a secret and the wrong place for an app
//! launched from a dock icon. A window opened by Finder or Explorer inherits
//! no shell, so a desktop user had no way to supply a key at all: the picker
//! showed their provider, and every message failed on a variable that could
//! only be set in a terminal they were not using.
//!
//! So a second source: `$OPENCLI_HOME/.env`, one `KEY=value` per line, loaded
//! into this process at startup. Not `config.toml`, because that file is
//! shared, pasted into issues and committed to repositories, and a key in it
//! travels with all three.
//!
//! The environment still wins. A variable exported by hand is a deliberate act
//! for this run, and a file on disk must not quietly override it.

use std::collections::BTreeMap;
use std::io;
use std::path::Path;
use std::path::PathBuf;

/// Where the keys live, given an OpenCLI home.
pub fn secrets_path(opencli_home: &Path) -> PathBuf {
    opencli_home.join(".env")
}

/// Read the file into a map, in file order. A missing file is not an error:
/// most people have no keys to set.
pub fn read_secrets(opencli_home: &Path) -> io::Result<BTreeMap<String, String>> {
    let path = secrets_path(opencli_home);
    let text = match std::fs::read_to_string(&path) {
        Ok(text) => text,
        Err(err) if err.kind() == io::ErrorKind::NotFound => return Ok(BTreeMap::new()),
        Err(err) => return Err(err),
    };
    Ok(parse(&text))
}

/// Set one key, or remove it when `value` is `None`.
///
/// The file is rewritten whole rather than appended to, so setting a key twice
/// leaves one line rather than two — and reading it back cannot depend on
/// which of the two a parser happens to prefer.
pub fn write_secret(opencli_home: &Path, name: &str, value: Option<&str>) -> io::Result<()> {
    let mut entries = read_secrets(opencli_home)?;
    match value {
        Some(value) if !value.trim().is_empty() => {
            entries.insert(name.to_string(), value.trim().to_string());
        }
        _ => {
            entries.remove(name);
        }
    }

    let mut body = String::from(
        "# API keys for OpenCLI, loaded into the agent's environment at startup.\n\
         # One KEY=value per line. Anything already exported in the environment\n\
         # wins over what is written here.\n",
    );
    for (key, value) in &entries {
        body.push_str(&format!("{key}={value}\n"));
    }

    std::fs::create_dir_all(opencli_home)?;
    let path = secrets_path(opencli_home);
    std::fs::write(&path, body)?;
    restrict(&path)
}

/// Owner-only, because the file is a list of credentials.
#[cfg(unix)]
fn restrict(path: &Path) -> io::Result<()> {
    use std::os::unix::fs::PermissionsExt;
    std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o600))
}

#[cfg(not(unix))]
fn restrict(_path: &Path) -> io::Result<()> {
    // Windows inherits the directory's ACL, and `$OPENCLI_HOME` is already
    // under the user's profile.
    Ok(())
}

/// Put the file's keys into this process's environment.
///
/// Returns the names it set, for a startup log — never the values.
///
/// # Safety
///
/// `set_var` is unsafe because another thread reading the environment at the
/// same moment is a data race. Call this once, early, before anything is
/// spawned.
pub unsafe fn load_into_env(opencli_home: &Path) -> Vec<String> {
    let Ok(entries) = read_secrets(opencli_home) else {
        return Vec::new();
    };
    let mut set = Vec::new();
    for (key, value) in entries {
        // An exported variable is a decision about this run; a file is a
        // default. The decision wins.
        if std::env::var_os(&key).is_some_and(|existing| !existing.is_empty()) {
            continue;
        }
        unsafe { std::env::set_var(&key, &value) };
        set.push(key);
    }
    set
}

/// `KEY=value` per line. Blank lines and `#` comments are skipped, surrounding
/// quotes are dropped, and a line without `=` is ignored rather than guessed
/// at.
fn parse(text: &str) -> BTreeMap<String, String> {
    let mut entries = BTreeMap::new();
    for line in text.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let Some((key, value)) = line.split_once('=') else {
            continue;
        };
        let key = key.trim().trim_start_matches("export ").trim();
        if key.is_empty() {
            continue;
        }
        let value = value.trim();
        let value = value
            .strip_prefix('"')
            .and_then(|rest| rest.strip_suffix('"'))
            .or_else(|| {
                value
                    .strip_prefix('\'')
                    .and_then(|rest| rest.strip_suffix('\''))
            })
            .unwrap_or(value);
        entries.insert(key.to_string(), value.to_string());
    }
    entries
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn should_read_back_what_was_written() {
        let home = TempDir::new().expect("temp dir");
        write_secret(home.path(), "MY_KEY", Some("abc123")).expect("write");
        let entries = read_secrets(home.path()).expect("read");
        assert_eq!(entries.get("MY_KEY").map(String::as_str), Some("abc123"));
    }

    #[test]
    fn should_replace_rather_than_append() {
        // Appending would leave two lines for one key, and which one wins
        // would depend on the parser rather than on what the user last did.
        let home = TempDir::new().expect("temp dir");
        write_secret(home.path(), "MY_KEY", Some("first")).expect("write");
        write_secret(home.path(), "MY_KEY", Some("second")).expect("write");
        let text = std::fs::read_to_string(secrets_path(home.path())).expect("read");
        assert_eq!(text.matches("MY_KEY=").count(), 1);
        assert!(text.contains("MY_KEY=second"));
    }

    #[test]
    fn should_forget_a_key_when_it_is_cleared() {
        let home = TempDir::new().expect("temp dir");
        write_secret(home.path(), "MY_KEY", Some("abc")).expect("write");
        write_secret(home.path(), "MY_KEY", None).expect("clear");
        assert!(read_secrets(home.path()).expect("read").is_empty());
    }

    #[test]
    fn should_ignore_comments_blanks_and_lines_without_a_value() {
        let parsed = parse("# a comment\n\nA=1\nnonsense\nexport B=\"two\"\nC='three'\n");
        assert_eq!(parsed.get("A").map(String::as_str), Some("1"));
        assert_eq!(parsed.get("B").map(String::as_str), Some("two"));
        assert_eq!(parsed.get("C").map(String::as_str), Some("three"));
        assert_eq!(parsed.len(), 3);
    }

    #[test]
    fn should_say_nothing_when_there_is_no_file() {
        let home = TempDir::new().expect("temp dir");
        assert!(read_secrets(home.path()).expect("read").is_empty());
    }
}
