//! Connecting to a server and running a command on it.
//!
//! Enough SSH to install and repair a model runtime on a machine elsewhere.
//! Two things are deliberate:
//!
//! - The host key is checked before anything is sent. A connection that skips
//!   that hands the session — and the commands about to run — to whatever
//!   answered on the address.
//! - No credential is kept. Keys are read from where the user already keeps
//!   them, and nothing is written back except a host key they agreed to trust.

use std::path::PathBuf;
use std::sync::Arc;

use russh::client;
use russh::keys::PrivateKeyWithHashAlg;
use russh::keys::ssh_key::PublicKey;
use tokio::io::AsyncWriteExt;

use crate::config::HostSettings;
use crate::hosts::Verdict;

/// What went wrong, in terms a caller can act on.
#[derive(Debug)]
pub enum Failure {
    /// Could not open a connection at all.
    Unreachable(String),
    /// The host key is not recorded. The caller must ask before trusting it.
    UnknownHost { fingerprint: String },
    /// The host key differs from the record. Refuse, and do not offer to
    /// overwrite: this is either a rebuilt server or an interception, and both
    /// deserve a person rather than a button.
    HostKeyChanged {
        recorded: String,
        offered: String,
        file: PathBuf,
        line: usize,
    },
    /// No key was accepted.
    Rejected(String),
    /// Everything connected, but the command itself failed to run.
    Failed(String),
}

impl std::fmt::Display for Failure {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Failure::Unreachable(why) => write!(formatter, "could not reach the server: {why}"),
            Failure::UnknownHost { fingerprint } => write!(
                formatter,
                "this server is not in your known_hosts. Its key is {fingerprint}"
            ),
            Failure::HostKeyChanged {
                recorded,
                offered,
                file,
                line,
            } => write!(
                formatter,
                "the server's key has changed. Recorded {recorded}, offered {offered}. \
                 If you rebuilt it, remove line {line} of {} yourself.",
                file.display()
            ),
            Failure::Rejected(why) => write!(formatter, "the server refused the key: {why}"),
            Failure::Failed(why) => write!(formatter, "{why}"),
        }
    }
}

impl std::error::Error for Failure {}

/// What a command left behind.
#[derive(Debug, Clone)]
pub struct Output {
    pub stdout: String,
    pub stderr: String,
    pub exit_code: i32,
}

impl Output {
    pub fn succeeded(&self) -> bool {
        self.exit_code == 0
    }
}

/// Whether an unrecorded host key may be trusted.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TrustPolicy {
    /// Refuse and report the fingerprint, so a person can decide.
    Ask,
    /// The user has already seen the fingerprint and agreed to it.
    AcceptAndRemember,
}

/// Checks the offered key, and records the verdict for the caller.
struct Verifier {
    hostname: String,
    port: u16,
    policy: TrustPolicy,
    outcome: Arc<std::sync::Mutex<Option<Verdict>>>,
}

impl client::Handler for Verifier {
    type Error = russh::Error;

    async fn check_server_key(&mut self, key: &PublicKey) -> Result<bool, Self::Error> {
        let algorithm = key.algorithm().to_string();
        let encoded = key.to_openssh().unwrap_or_default();
        // `to_openssh` yields `type base64 comment`; the record wants the body.
        let body = encoded
            .split_whitespace()
            .nth(1)
            .unwrap_or_default()
            .to_string();

        let verdict = crate::hosts::check(&self.hostname, self.port, &algorithm, &body);
        let accept = match (&verdict, self.policy) {
            (Verdict::Known, _) => true,
            (Verdict::Unknown { .. }, TrustPolicy::AcceptAndRemember) => {
                let _ = crate::hosts::remember(&self.hostname, self.port, &algorithm, &body);
                true
            }
            // A changed key is never accepted, whatever the policy says. There
            // is no situation where clicking through that is the right answer.
            (Verdict::Unknown { .. }, TrustPolicy::Ask) | (Verdict::Changed { .. }, _) => false,
        };

        if let Ok(mut slot) = self.outcome.lock() {
            *slot = Some(verdict);
        }
        Ok(accept)
    }
}

/// A connected session.
pub struct Session {
    handle: client::Handle<Verifier>,
}

/// Open a session to a host.
pub async fn connect(
    settings: &HostSettings,
    user: &str,
    policy: TrustPolicy,
) -> Result<Session, Failure> {
    let outcome = Arc::new(std::sync::Mutex::new(None));
    let verifier = Verifier {
        hostname: settings.hostname.clone(),
        port: settings.port,
        policy,
        outcome: Arc::clone(&outcome),
    };

    let config = Arc::new(client::Config {
        // Long enough for a slow link; short enough that a wrong address
        // reports rather than hanging whatever is waiting on it.
        inactivity_timeout: Some(std::time::Duration::from_secs(120)),
        ..client::Config::default()
    });

    let handle = client::connect(
        config,
        (settings.hostname.as_str(), settings.port),
        verifier,
    )
    .await
    .map_err(|err| {
        // A rejected host key surfaces as a connection error, so the
        // verdict recorded during the handshake is what says why.
        match outcome.lock().ok().and_then(|slot| slot.clone()) {
            Some(Verdict::Unknown { fingerprint }) => Failure::UnknownHost { fingerprint },
            Some(Verdict::Changed {
                recorded,
                offered,
                file,
                line,
            }) => Failure::HostKeyChanged {
                recorded,
                offered,
                file,
                line,
            },
            _ => Failure::Unreachable(err.to_string()),
        }
    })?;

    let mut session = Session { handle };
    session.authenticate(settings, user).await?;
    Ok(session)
}

impl Session {
    /// Try the agent first, then the identity files.
    ///
    /// The agent first because a key it holds is already unlocked; reading the
    /// file would ask for a passphrase the user has already given once.
    async fn authenticate(&mut self, settings: &HostSettings, user: &str) -> Result<(), Failure> {
        let mut tried = Vec::new();

        // The agent is a Unix idea here: `connect_env` reads `SSH_AUTH_SOCK`,
        // and on Windows the function does not exist at all — the agent there
        // speaks over a named pipe. Windows falls through to the identity
        // files, which is what it would have done anyway.
        #[cfg(unix)]
        if let Ok(mut agent) = russh::keys::agent::client::AgentClient::connect_env().await
            && let Ok(identities) = agent.request_identities().await
        {
            for key in identities {
                let fingerprint = key.fingerprint(Default::default()).to_string();
                match self
                    .handle
                    .authenticate_publickey_with(
                        user,
                        key,
                        self.handle
                            .best_supported_rsa_hash()
                            .await
                            .ok()
                            .flatten()
                            .flatten(),
                        &mut agent,
                    )
                    .await
                {
                    Ok(result) if result.success() => return Ok(()),
                    _ => tried.push(format!("agent key {fingerprint}")),
                }
            }
        }

        let files = if settings.identity_files.is_empty() {
            crate::config::default_identity_files()
        } else {
            settings.identity_files.clone()
        };
        for path in files {
            // An encrypted key needs a passphrase this crate does not ask for.
            // Reporting it is better than failing as though the key were wrong.
            let key = match russh::keys::load_secret_key(&path, None) {
                Ok(key) => key,
                Err(err) => {
                    tried.push(format!("{}: {err}", path.display()));
                    continue;
                }
            };
            let hash = self
                .handle
                .best_supported_rsa_hash()
                .await
                .ok()
                .flatten()
                .flatten();
            match self
                .handle
                .authenticate_publickey(user, PrivateKeyWithHashAlg::new(Arc::new(key), hash))
                .await
            {
                Ok(result) if result.success() => return Ok(()),
                _ => tried.push(format!("{}", path.display())),
            }
        }

        Err(Failure::Rejected(if tried.is_empty() {
            "no keys were found to try. Add one to your ssh-agent or ~/.ssh/".to_string()
        } else {
            format!("tried {}", tried.join(", "))
        }))
    }

    /// Run a command and collect what it produced.
    pub async fn exec(&self, command: &str) -> Result<Output, Failure> {
        let mut channel = self
            .handle
            .channel_open_session()
            .await
            .map_err(|err| Failure::Failed(err.to_string()))?;
        channel
            .exec(true, command)
            .await
            .map_err(|err| Failure::Failed(err.to_string()))?;

        let mut stdout = Vec::new();
        let mut stderr = Vec::new();
        let mut exit_code = None;

        while let Some(message) = channel.wait().await {
            match message {
                russh::ChannelMsg::Data { ref data } => stdout.extend_from_slice(data),
                russh::ChannelMsg::ExtendedData { ref data, ext } => {
                    // Extended data type 1 is stderr; anything else is not
                    // output and would corrupt the transcript if appended.
                    if ext == 1 {
                        stderr.extend_from_slice(data);
                    }
                }
                russh::ChannelMsg::ExitStatus { exit_status } => {
                    exit_code = Some(exit_status as i32);
                }
                // Deliberately not breaking on `Eof` or `Close`: the exit
                // status arrives *after* them, and leaving early loses it —
                // every command then looks as though it failed. The stream
                // ending is what says there is no more to read.
                _ => {}
            }
        }

        Ok(Output {
            stdout: String::from_utf8_lossy(&stdout).into_owned(),
            stderr: String::from_utf8_lossy(&stderr).into_owned(),
            // A channel that closed without a status did not report success,
            // and reading that as zero would call a killed command fine.
            exit_code: exit_code.unwrap_or(-1),
        })
    }

    pub async fn close(&self) {
        let _ = self
            .handle
            .disconnect(russh::Disconnect::ByApplication, "", "en")
            .await;
    }
}

/// Write a file by piping it through `cat`, so no extra protocol is needed.
///
/// Only for small files — a script or a unit file. Anything large should be
/// fetched by the server itself, which is faster and does not hold the whole
/// thing in memory here.
pub async fn write_small_file(
    session: &Session,
    path: &str,
    contents: &str,
) -> Result<Output, Failure> {
    let mut channel = session
        .handle
        .channel_open_session()
        .await
        .map_err(|err| Failure::Failed(err.to_string()))?;
    channel
        .exec(true, format!("cat > {}", shell_quote(path)))
        .await
        .map_err(|err| Failure::Failed(err.to_string()))?;
    channel
        .data(contents.as_bytes())
        .await
        .map_err(|err| Failure::Failed(err.to_string()))?;
    channel
        .eof()
        .await
        .map_err(|err| Failure::Failed(err.to_string()))?;

    let mut exit_code = None;
    let mut stderr = Vec::new();
    while let Some(message) = channel.wait().await {
        match message {
            russh::ChannelMsg::ExtendedData { ref data, ext } if ext == 1 => {
                stderr.extend_from_slice(data)
            }
            russh::ChannelMsg::ExitStatus { exit_status } => exit_code = Some(exit_status as i32),
            // As above: the status follows the close, so the loop runs to the
            // end of the stream.
            _ => {}
        }
    }
    let _ = AsyncWriteExt::flush(&mut tokio::io::sink()).await;

    Ok(Output {
        stdout: String::new(),
        stderr: String::from_utf8_lossy(&stderr).into_owned(),
        exit_code: exit_code.unwrap_or(-1),
    })
}

/// Quote a value for a POSIX shell.
///
/// Single quotes with the one escape they need. A path from a user can contain
/// a space or a quote, and pasting it raw into a command line is how an
/// ordinary filename turns into an extra command.
pub fn shell_quote(value: &str) -> String {
    format!("'{}'", value.replace('\'', r"'\''"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn should_quote_a_plain_path_without_changing_it() {
        assert_eq!(shell_quote("/usr/local/bin"), "'/usr/local/bin'");
    }

    #[test]
    fn should_quote_a_path_containing_a_space() {
        assert_eq!(shell_quote("/my models/a.gguf"), "'/my models/a.gguf'");
    }

    #[test]
    fn should_neutralise_an_embedded_quote() {
        // Without this, `'; rm -rf /; '` in a filename becomes another command.
        // Checked by asking a real shell how many arguments it sees: one means
        // the whole thing stayed a single value. A substring check would fail
        // here for correctly escaped output, which is how this test was wrong
        // the first time.
        let nasty = "a'; rm -rf /; '";
        let quoted = shell_quote(nasty);
        assert_eq!(quoted, r"'a'\''; rm -rf /; '\'''");

        let output = std::process::Command::new("sh")
            .arg("-c")
            .arg(format!("set -- {quoted}; printf '%s' \"$#\""))
            .output()
            .expect("run sh");
        assert_eq!(
            String::from_utf8_lossy(&output.stdout),
            "1",
            "the escaped value must stay one argument"
        );

        let echoed = std::process::Command::new("sh")
            .arg("-c")
            .arg(format!("printf '%s' {quoted}"))
            .output()
            .expect("run sh");
        assert_eq!(String::from_utf8_lossy(&echoed.stdout), nasty);
    }

    #[test]
    fn should_report_a_missing_exit_status_as_a_failure() {
        // A channel that closed without one did not report success, and
        // reading that as zero would call a killed command fine.
        let output = Output {
            stdout: String::new(),
            stderr: String::new(),
            exit_code: -1,
        };
        assert!(!output.succeeded());
    }

    #[test]
    fn should_explain_a_changed_host_key_with_what_to_do() {
        let failure = Failure::HostKeyChanged {
            recorded: "ssh-ed25519 AAA…ZZZ".into(),
            offered: "ssh-ed25519 BBB…YYY".into(),
            file: PathBuf::from("/home/me/.ssh/known_hosts"),
            line: 7,
        };
        let message = failure.to_string();
        assert!(message.contains("has changed"));
        assert!(
            message.contains("line 7"),
            "the user needs to know where to look"
        );
    }

    #[test]
    fn should_name_the_fingerprint_of_an_unknown_host() {
        // Asking "trust this?" without showing what is being trusted is a
        // question nobody can answer.
        let failure = Failure::UnknownHost {
            fingerprint: "ssh-ed25519 AAA…ZZZ".into(),
        };
        assert!(failure.to_string().contains("AAA…ZZZ"));
    }
}
