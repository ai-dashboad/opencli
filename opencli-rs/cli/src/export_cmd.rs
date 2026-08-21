//! `opencli export` — write a recorded session out as a readable Markdown
//! transcript. Reads the session's rollout file and keeps the user and
//! assistant messages in order.

use std::io::Write;
use std::path::Path;
use std::path::PathBuf;

use anyhow::Context;
use anyhow::Result;
use clap::Args;
use opencli_core::config::find_opencli_home;

#[derive(Debug, Args)]
pub struct ExportArgs {
    /// Session id (UUID) to export. When omitted, the most recent session is used.
    pub session_id: Option<String>,

    /// Write to this file instead of stdout.
    #[arg(long, value_name = "FILE")]
    pub out: Option<PathBuf>,
}

pub fn run_main(args: ExportArgs) -> Result<()> {
    let home = find_opencli_home().context("resolve config home")?;
    let sessions = home.join("sessions");

    let rollout = match &args.session_id {
        Some(id) => find_by_id(&sessions, id)
            .with_context(|| format!("no session found for id `{id}`"))?,
        None => latest_rollout(&sessions).context("no recorded sessions found")?,
    };

    let markdown = render_markdown(&rollout)?;

    match &args.out {
        Some(path) => {
            std::fs::write(path, &markdown)
                .with_context(|| format!("write {}", path.display()))?;
            eprintln!("exported to {}", path.display());
        }
        None => {
            std::io::stdout().write_all(markdown.as_bytes())?;
        }
    }
    Ok(())
}

fn render_markdown(rollout: &Path) -> Result<String> {
    let contents =
        std::fs::read_to_string(rollout).with_context(|| format!("read {}", rollout.display()))?;

    let mut out = String::new();
    out.push_str("# opencli session transcript\n\n");

    for line in contents.lines() {
        let Ok(value) = serde_json::from_str::<serde_json::Value>(line) else {
            continue;
        };
        if value.get("type").and_then(|t| t.as_str()) != Some("response_item") {
            continue;
        }
        let payload = &value["payload"];
        if payload.get("type").and_then(|t| t.as_str()) != Some("message") {
            continue;
        }
        let role = payload.get("role").and_then(|r| r.as_str()).unwrap_or("");
        // The developer role holds internal instructions; skip it in a
        // human-facing transcript.
        let heading = match role {
            "user" => "## User",
            "assistant" => "## Assistant",
            _ => continue,
        };
        let text = collect_text(&payload["content"]);
        if text.trim().is_empty() || is_injected_context(text.trim()) {
            continue;
        }
        out.push_str(heading);
        out.push_str("\n\n");
        out.push_str(text.trim());
        out.push_str("\n\n");
    }

    Ok(out)
}

/// True when a user-role message is actually injected context (AGENTS.md
/// instructions, environment blocks) rather than something the user typed.
fn is_injected_context(text: &str) -> bool {
    const MARKERS: &[&str] = &[
        "<INSTRUCTIONS>",
        "<user_instructions>",
        "<environment_context>",
        "# AGENTS.md instructions",
        "<user_shell>",
    ];
    MARKERS.iter().any(|marker| text.starts_with(marker))
}

/// Join the `text` fields of a message content array.
fn collect_text(content: &serde_json::Value) -> String {
    let Some(items) = content.as_array() else {
        return String::new();
    };
    items
        .iter()
        .filter_map(|item| item.get("text").and_then(|t| t.as_str()))
        .collect::<Vec<_>>()
        .join("")
}

fn latest_rollout(sessions: &Path) -> Option<PathBuf> {
    let mut newest: Option<(std::time::SystemTime, PathBuf)> = None;
    for path in rollout_files(sessions) {
        let Ok(modified) = path.metadata().and_then(|m| m.modified()) else {
            continue;
        };
        if newest.as_ref().is_none_or(|(t, _)| modified > *t) {
            newest = Some((modified, path));
        }
    }
    newest.map(|(_, path)| path)
}

fn find_by_id(sessions: &Path, id: &str) -> Option<PathBuf> {
    rollout_files(sessions).into_iter().find(|path| {
        path.file_name()
            .and_then(|name| name.to_str())
            .is_some_and(|name| name.contains(id))
    })
}

fn rollout_files(dir: &Path) -> Vec<PathBuf> {
    let mut out = Vec::new();
    let mut stack = vec![dir.to_path_buf()];
    while let Some(current) = stack.pop() {
        let Ok(entries) = std::fs::read_dir(&current) else {
            continue;
        };
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_dir() {
                stack.push(path);
            } else if path
                .file_name()
                .and_then(|name| name.to_str())
                .is_some_and(|name| name.starts_with("rollout-") && name.ends_with(".jsonl"))
            {
                out.push(path);
            }
        }
    }
    out
}
