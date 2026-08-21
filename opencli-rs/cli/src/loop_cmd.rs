//! `opencli loop` — run a prompt on a recurring interval.
//!
//! Each tick runs the prompt through a fresh `opencli exec` subprocess. Useful
//! for babysitting a build, polling a deploy, or any "check this every N
//! minutes" task. Stop with Ctrl-C.

use std::process::Stdio;
use std::time::Duration;

use anyhow::Context;
use anyhow::Result;
use anyhow::bail;
use clap::Args;
use tokio::process::Command;

#[derive(Debug, Args)]
pub struct LoopArgs {
    /// Interval between runs, e.g. `30s`, `5m`, `1h`. Defaults to minutes when
    /// no unit is given.
    pub interval: String,

    /// The prompt to run each tick.
    pub prompt: String,

    /// Stop after this many runs. Runs forever when omitted.
    #[arg(long, value_name = "N")]
    pub max: Option<u64>,
}

pub async fn run_main(args: LoopArgs) -> Result<()> {
    let interval = parse_interval(&args.interval)?;
    let exe = std::env::current_exe().context("resolve opencli executable path")?;

    println!(
        "Looping every {}s (Ctrl-C to stop){}",
        interval.as_secs(),
        args.max
            .map(|max| format!(", up to {max} runs"))
            .unwrap_or_default()
    );

    let mut run = 0u64;
    loop {
        run += 1;
        println!("\n=== run {run} ===");
        let status = Command::new(&exe)
            .arg("exec")
            .arg(&args.prompt)
            .stdin(Stdio::null())
            .status()
            .await
            .context("run loop iteration")?;
        if !status.success() {
            eprintln!("(run {run} exited with a non-zero status)");
        }

        if args.max.is_some_and(|max| run >= max) {
            println!("\nReached {run} runs; stopping.");
            break;
        }
        tokio::time::sleep(interval).await;
    }
    Ok(())
}

/// Parse an interval like `30s`, `5m`, `2h`. A bare number is minutes.
fn parse_interval(raw: &str) -> Result<Duration> {
    let raw = raw.trim();
    if raw.is_empty() {
        bail!("interval must not be empty");
    }
    let (number, unit_seconds) = match raw.chars().last() {
        Some('s') => (&raw[..raw.len() - 1], 1),
        Some('m') => (&raw[..raw.len() - 1], 60),
        Some('h') => (&raw[..raw.len() - 1], 3600),
        Some(c) if c.is_ascii_digit() => (raw, 60),
        _ => bail!("invalid interval `{raw}`: use forms like 30s, 5m, 1h"),
    };
    let value: u64 = number
        .trim()
        .parse()
        .with_context(|| format!("invalid interval number in `{raw}`"))?;
    if value == 0 {
        bail!("interval must be greater than zero");
    }
    Ok(Duration::from_secs(value * unit_seconds))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn should_parse_interval_units() {
        assert_eq!(parse_interval("30s").unwrap(), Duration::from_secs(30));
        assert_eq!(parse_interval("5m").unwrap(), Duration::from_secs(300));
        assert_eq!(parse_interval("2h").unwrap(), Duration::from_secs(7200));
        // A bare number is minutes.
        assert_eq!(parse_interval("10").unwrap(), Duration::from_secs(600));
    }

    #[test]
    fn should_reject_bad_intervals() {
        assert!(parse_interval("").is_err());
        assert!(parse_interval("0s").is_err());
        assert!(parse_interval("abc").is_err());
    }
}
