//! Telling every open window that something changed, without being asked.
//!
//! Background runs were read by polling: the panel asked for the whole list
//! every 1.5 seconds while anything was running, and the answer was almost
//! always the same answer again. That is a poor way to watch a ten-minute run
//! — output arrives up to a tick late, and the cost is paid whether or not
//! anything happened.
//!
//! The worker that changes runs and the sockets that display them are in one
//! process, so nothing has to be inferred from the filesystem. The worker says
//! it moved; every attached window hears.
//!
//! A broadcast channel rather than a list of senders because windows come and
//! go: a receiver that has gone away is dropped by the channel, and a slow one
//! that misses messages is told it lagged rather than blocking the worker. The
//! payload is `()` on purpose — this says *look again*, not *here is the new
//! state*. A notification carrying state would have to be kept in agreement
//! with the reply to `dispatch/list`, and two descriptions of one thing is one
//! too many.
//!
//! Channels are kept per config home rather than one for the process. A single
//! global one was written first and was wrong: two gateways in one process
//! heard each other's runs, so a window attached to one was told to re-read a
//! store that had not moved. The home is what the signal is about — "runs
//! under this directory changed" — so it is what the signal is filed under.

use std::collections::HashMap;
use std::path::Path;
use std::path::PathBuf;
use std::sync::Mutex;
use std::sync::OnceLock;
use tokio::sync::broadcast;

/// Enough that a burst of writes during a run does not make a slow window lag.
const DEPTH: usize = 32;

fn channels() -> &'static Mutex<HashMap<PathBuf, broadcast::Sender<()>>> {
    static CHANNELS: OnceLock<Mutex<HashMap<PathBuf, broadcast::Sender<()>>>> = OnceLock::new();
    CHANNELS.get_or_init(|| Mutex::new(HashMap::new()))
}

fn channel_for(opencli_home: &Path) -> broadcast::Sender<()> {
    let mut held = match channels().lock() {
        Ok(held) => held,
        // A poisoned lock means another thread panicked while holding it. The
        // map is a set of senders; carrying on with it is safe and losing
        // notifications is worse than the alternative.
        Err(poisoned) => poisoned.into_inner(),
    };
    held.entry(opencli_home.to_path_buf())
        .or_insert_with(|| broadcast::channel(DEPTH).0)
        .clone()
}

/// Background runs under this home have moved: created, started, written to,
/// or finished.
pub fn runs_changed(opencli_home: &Path) {
    // An error here means nothing is listening, which is the ordinary state of
    // a gateway with no window open.
    let _ = channel_for(opencli_home).send(());
}

/// Hear about it. Dropping the receiver unsubscribes.
pub fn subscribe_runs(opencli_home: &Path) -> broadcast::Receiver<()> {
    channel_for(opencli_home).subscribe()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn should_reach_every_listener() {
        let home = Path::new("/tmp/opencli-notify-every");
        let mut first = subscribe_runs(home);
        let mut second = subscribe_runs(home);
        runs_changed(home);
        assert!(first.recv().await.is_ok());
        assert!(second.recv().await.is_ok());
    }

    #[tokio::test]
    async fn should_not_carry_between_two_homes() {
        // The bug this shape was chosen for: one gateway's runs reaching
        // another gateway's window, which then re-read a store that had not
        // moved.
        let mine = Path::new("/tmp/opencli-notify-mine");
        let theirs = Path::new("/tmp/opencli-notify-theirs");
        let mut listener = subscribe_runs(mine);
        runs_changed(theirs);
        assert!(listener.try_recv().is_err());
        runs_changed(mine);
        assert!(listener.recv().await.is_ok());
    }

    #[tokio::test]
    async fn should_not_fail_when_nobody_is_listening() {
        // The ordinary state of a gateway with no window open.
        runs_changed(Path::new("/tmp/opencli-notify-nobody"));
    }

    #[tokio::test]
    async fn should_tell_a_slow_listener_it_missed_some() {
        // Rather than blocking the worker until the window catches up. The
        // client's answer to a lag is the same as its answer to a signal —
        // ask for the list — so nothing is lost by it.
        let home = Path::new("/tmp/opencli-notify-slow");
        let mut slow = subscribe_runs(home);
        for _ in 0..(DEPTH + 5) {
            runs_changed(home);
        }
        assert!(matches!(
            slow.recv().await,
            Err(broadcast::error::RecvError::Lagged(_))
        ));
    }
}
