use std::path::PathBuf;
use std::fs;
use crate::error::{OpenCliError, Result};

const DAEMON_BINARY: &[u8] = &[]; // Will be embedded at build time

pub fn ensure_daemon_extracted() -> Result<()> {
    let daemon_path = get_daemon_path();

    // Check if daemon already exists
    if daemon_path.exists() {
        return Ok(());
    }

    // Create directory if needed
    if let Some(parent) = daemon_path.parent() {
        fs::create_dir_all(parent)?;
    }

    // Extract embedded daemon binary
    if !DAEMON_BINARY.is_empty() {
        fs::write(&daemon_path, DAEMON_BINARY)?;

        // Make executable on Unix
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let mut perms = fs::metadata(&daemon_path)?.permissions();
            perms.set_mode(0o755);
            fs::set_permissions(&daemon_path, perms)?;
        }
    }

    Ok(())
}

pub fn get_daemon_path() -> PathBuf {
    let home = dirs::home_dir().unwrap_or_else(|| PathBuf::from("."));
    home.join(".opencli").join("bin").join("opencli-daemon")
}

mod dirs {
    use std::path::PathBuf;

    pub fn home_dir() -> Option<PathBuf> {
        std::env::var_os("HOME").map(PathBuf::from)
    }
}
