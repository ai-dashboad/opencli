//! Entry-point for the `opencli-exec` binary.
//!
//! When this CLI is invoked normally, it parses the standard `opencli-exec` CLI
//! options and launches the non-interactive OpenCLI agent. However, if it is
//! invoked with arg0 as `opencli-linux-sandbox`, we instead treat the invocation
//! as a request to run the logic for the standalone `opencli-linux-sandbox`
//! executable (i.e., parse any -s args and then run a *sandboxed* command under
//! Landlock + seccomp.
//!
//! This allows us to ship a completely separate set of functionality as part
//! of the `opencli-exec` binary.
use clap::Parser;
use opencli_arg0::arg0_dispatch_or_else;
use opencli_common::CliConfigOverrides;
use opencli_exec::Cli;
use opencli_exec::run_main;

#[derive(Parser, Debug)]
struct TopCli {
    #[clap(flatten)]
    config_overrides: CliConfigOverrides,

    #[clap(flatten)]
    inner: Cli,
}

fn main() -> anyhow::Result<()> {
    arg0_dispatch_or_else(|opencli_linux_sandbox_exe| async move {
        let top_cli = TopCli::parse();
        // Merge root-level overrides into inner CLI struct so downstream logic remains unchanged.
        let mut inner = top_cli.inner;
        inner
            .config_overrides
            .raw_overrides
            .splice(0..0, top_cli.config_overrides.raw_overrides);

        run_main(inner, opencli_linux_sandbox_exe).await?;
        Ok(())
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use pretty_assertions::assert_eq;

    #[test]
    fn top_cli_parses_resume_prompt_after_config_flag() {
        const PROMPT: &str = "echo resume-with-global-flags-after-subcommand";
        let cli = TopCli::parse_from([
            "opencli-exec",
            "resume",
            "--last",
            "--json",
            "--model",
            "test-model-pro",
            "--config",
            "reasoning_level=xhigh",
            "--dangerously-bypass-approvals-and-sandbox",
            "--skip-git-repo-check",
            PROMPT,
        ]);

        let Some(opencli_exec::Command::Resume(args)) = cli.inner.command else {
            panic!("expected resume command");
        };
        let effective_prompt = args.prompt.clone().or_else(|| {
            if args.last {
                args.session_id.clone()
            } else {
                None
            }
        });
        assert_eq!(effective_prompt.as_deref(), Some(PROMPT));
        assert_eq!(cli.config_overrides.raw_overrides.len(), 1);
        assert_eq!(
            cli.config_overrides.raw_overrides[0],
            "reasoning_level=xhigh"
        );
    }
}
