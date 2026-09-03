//! Execution of user-defined lifecycle hooks.
//!
//! Hooks are shell commands the user configures under `[hooks]` in
//! `config.toml`. They run around the agent's own command execution so the user
//! can automate side effects (formatting, linting, notifications) or guard
//! dangerous commands, all without changing the model or the prompt.
//!
//! The lifecycle context is handed to each hook through the environment:
//!   - `OPENCLI_HOOK_EVENT`     — `pre_exec` or `post_exec`
//!   - `OPENCLI_HOOK_COMMAND`   — the agent's command, space-joined
//!   - `OPENCLI_HOOK_CWD`       — the working directory of the agent command
//!   - `OPENCLI_HOOK_EXIT_CODE` — the agent command's exit code (post_exec only)

use std::path::Path;
use std::time::Duration;

use tokio::process::Command;
use tokio::time::timeout;

use crate::config::types::Hook;

/// Default ceiling for a single hook, applied when the hook sets no `timeout_ms`.
const DEFAULT_HOOK_TIMEOUT_MS: u64 = 30_000;

/// Which lifecycle point a batch of hooks is running for.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum HookEvent {
    PreExec,
    PostExec,
}

impl HookEvent {
    fn as_env_value(self) -> &'static str {
        match self {
            HookEvent::PreExec => "pre_exec",
            HookEvent::PostExec => "post_exec",
        }
    }
}

/// Outcome of running the pre-exec hooks for a command.
#[derive(Debug, PartialEq, Eq)]
pub enum PreExecDecision {
    /// No hook vetoed the command; the agent may run it.
    Proceed,
    /// A `block_on_failure` hook exited non-zero. The contained string names the
    /// blocking hook and is suitable for reporting back to the model.
    Blocked(String),
}

/// Return true when `hook` applies to `command` (i.e. its `matches` filter is
/// absent or is a substring of the command).
fn hook_applies(hook: &Hook, command: &str) -> bool {
    match hook.matches.as_deref() {
        Some(needle) if !needle.is_empty() => command.contains(needle),
        _ => true,
    }
}

/// Run one hook to completion, returning its exit code (or `None` if it timed
/// out or could not be spawned).
async fn run_one(
    hook: &Hook,
    event: HookEvent,
    command: &str,
    cwd: &Path,
    exit_code: Option<i32>,
) -> Option<i32> {
    // Route through the user's shell so `command` can use pipes, globs, etc.
    let mut cmd = Command::new("/bin/sh");
    cmd.arg("-c")
        .arg(&hook.command)
        .current_dir(cwd)
        .env("OPENCLI_HOOK_EVENT", event.as_env_value())
        .env("OPENCLI_HOOK_COMMAND", command)
        .env("OPENCLI_HOOK_CWD", cwd.to_string_lossy().as_ref());
    if let Some(code) = exit_code {
        cmd.env("OPENCLI_HOOK_EXIT_CODE", code.to_string());
    }

    let limit = Duration::from_millis(hook.timeout_ms.unwrap_or(DEFAULT_HOOK_TIMEOUT_MS));
    match timeout(limit, cmd.status()).await {
        Ok(Ok(status)) => Some(status.code().unwrap_or(-1)),
        Ok(Err(err)) => {
            tracing::warn!("hook failed to spawn: {err}");
            None
        }
        Err(_) => {
            tracing::warn!(
                "hook timed out after {}ms: {}",
                limit.as_millis(),
                hook.command
            );
            None
        }
    }
}

/// Run every applicable pre-exec hook. The first `block_on_failure` hook that
/// exits non-zero (or cannot run) blocks the command.
pub async fn run_pre_exec(hooks: &[Hook], command: &str, cwd: &Path) -> PreExecDecision {
    for hook in hooks.iter().filter(|h| hook_applies(h, command)) {
        let code = run_one(hook, HookEvent::PreExec, command, cwd, None).await;
        let failed = !matches!(code, Some(0));
        if failed && hook.block_on_failure {
            let reason = match code {
                Some(code) => format!("blocked by pre_exec hook `{}` (exit {code})", hook.command),
                None => format!(
                    "blocked by pre_exec hook `{}` (did not complete)",
                    hook.command
                ),
            };
            return PreExecDecision::Blocked(reason);
        }
    }
    PreExecDecision::Proceed
}

/// Run every applicable post-exec hook. Post-exec hooks never block; failures
/// are logged and ignored.
pub async fn run_post_exec(hooks: &[Hook], command: &str, cwd: &Path, exit_code: i32) {
    for hook in hooks.iter().filter(|h| hook_applies(h, command)) {
        let _ = run_one(hook, HookEvent::PostExec, command, cwd, Some(exit_code)).await;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::env::temp_dir;

    fn hook(command: &str, matches: Option<&str>, block: bool) -> Hook {
        Hook {
            command: command.to_string(),
            matches: matches.map(str::to_string),
            block_on_failure: block,
            timeout_ms: Some(5_000),
        }
    }

    #[test]
    fn should_apply_hook_only_when_match_substring_is_present() {
        assert!(hook_applies(&hook("x", None, false), "git push"));
        assert!(hook_applies(&hook("x", Some("push"), false), "git push"));
        assert!(!hook_applies(&hook("x", Some("push"), false), "git status"));
        // An empty match filter is treated as "always".
        assert!(hook_applies(&hook("x", Some(""), false), "anything"));
    }

    #[tokio::test]
    async fn should_proceed_when_no_pre_exec_hook_blocks() {
        let hooks = vec![hook("true", None, true)];
        let decision = run_pre_exec(&hooks, "git push", &temp_dir()).await;
        assert_eq!(decision, PreExecDecision::Proceed);
    }

    #[tokio::test]
    async fn should_block_when_a_blocking_pre_exec_hook_fails() {
        let hooks = vec![hook("exit 3", Some("push"), true)];
        let decision = run_pre_exec(&hooks, "git push --force", &temp_dir()).await;
        assert!(matches!(decision, PreExecDecision::Blocked(_)));
    }

    #[tokio::test]
    async fn should_not_block_when_failing_hook_is_non_blocking() {
        let hooks = vec![hook("exit 1", None, false)];
        let decision = run_pre_exec(&hooks, "git push", &temp_dir()).await;
        assert_eq!(decision, PreExecDecision::Proceed);
    }

    #[tokio::test]
    async fn should_pass_exit_code_to_post_exec_without_blocking() {
        // A failing post-exec hook must not panic or block; this simply
        // exercises the path and confirms it returns.
        let hooks = vec![hook("test \"$OPENCLI_HOOK_EXIT_CODE\" = 7", None, false)];
        run_post_exec(&hooks, "make", &temp_dir(), 7).await;
    }
}
