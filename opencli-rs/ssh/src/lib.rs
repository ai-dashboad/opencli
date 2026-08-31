//! An SSH client for reaching a model server.
//!
//! Enough SSH to install and repair a runtime on a machine elsewhere, and no
//! more. The parts that decide *where* a connection goes and *whether to trust
//! it* are the ones worth being careful about, so they are separate, tested,
//! and refuse rather than guess:
//!
//! - [`config`] resolves an alias from the user's own `~/.ssh/config`, so a
//!   server already reachable as `ssh gpu5090` needs no second set-up.
//! - [`hosts`] checks the offered key against `~/.ssh/known_hosts`, and treats
//!   "never seen" and "changed since last time" as different questions.
//!
//! No credential is ever stored by this crate. Keys are read from where the
//! user already keeps them, and a passphrase or password is asked for when
//! needed and kept only for the life of the connection.

pub mod config;
pub mod hosts;
