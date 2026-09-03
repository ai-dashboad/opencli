use std::path::Path;
use std::time::Duration;

use async_trait::async_trait;
use serde::Deserialize;
use tokio::process::Command;
use tokio::time::timeout;

use crate::function_tool::FunctionCallError;
use crate::tools::context::ToolInvocation;
use crate::tools::context::ToolOutput;
use crate::tools::context::ToolPayload;
use crate::tools::handlers::parse_arguments;
use crate::tools::registry::ToolHandler;
use crate::tools::registry::ToolKind;

pub struct GrepFilesHandler;

const DEFAULT_LIMIT: usize = 100;
const MAX_LIMIT: usize = 2000;
const COMMAND_TIMEOUT: Duration = Duration::from_secs(30);

fn default_limit() -> usize {
    DEFAULT_LIMIT
}

#[derive(Deserialize)]
struct GrepFilesArgs {
    pattern: String,
    #[serde(default)]
    include: Option<String>,
    #[serde(default)]
    path: Option<String>,
    #[serde(default = "default_limit")]
    limit: usize,
    /// "content" (default) returns matching lines as `path:line:text`; "files"
    /// returns just the matching file paths, newest first.
    #[serde(default)]
    output_mode: Option<String>,
}

#[derive(Clone, Copy, PartialEq)]
enum SearchMode {
    Content,
    Files,
}

#[async_trait]
impl ToolHandler for GrepFilesHandler {
    fn kind(&self) -> ToolKind {
        ToolKind::Function
    }

    async fn handle(&self, invocation: ToolInvocation) -> Result<ToolOutput, FunctionCallError> {
        let ToolInvocation { payload, turn, .. } = invocation;

        let arguments = match payload {
            ToolPayload::Function { arguments } => arguments,
            _ => {
                return Err(FunctionCallError::RespondToModel(
                    "grep_files handler received unsupported payload".to_string(),
                ));
            }
        };

        let args: GrepFilesArgs = parse_arguments(&arguments)?;

        let pattern = args.pattern.trim();
        if pattern.is_empty() {
            return Err(FunctionCallError::RespondToModel(
                "pattern must not be empty".to_string(),
            ));
        }

        if args.limit == 0 {
            return Err(FunctionCallError::RespondToModel(
                "limit must be greater than zero".to_string(),
            ));
        }

        let limit = args.limit.min(MAX_LIMIT);
        let mode = match args.output_mode.as_deref().map(str::trim) {
            None | Some("") | Some("content") => SearchMode::Content,
            Some("files") => SearchMode::Files,
            Some(other) => {
                return Err(FunctionCallError::RespondToModel(format!(
                    "output_mode must be \"content\" or \"files\", got `{other}`"
                )));
            }
        };
        let search_path = turn.resolve_path(args.path.clone());

        verify_path_exists(&search_path).await?;

        let include = args.include.as_deref().map(str::trim).and_then(|val| {
            if val.is_empty() {
                None
            } else {
                Some(val.to_string())
            }
        });

        let search_results = run_rg_search(
            pattern,
            include.as_deref(),
            &search_path,
            limit,
            mode,
            &turn.cwd,
        )
        .await?;

        if search_results.is_empty() {
            Ok(ToolOutput::Function {
                content: "No matches found.".to_string(),
                content_items: None,
                success: Some(false),
            })
        } else {
            Ok(ToolOutput::Function {
                content: search_results.join("\n"),
                content_items: None,
                success: Some(true),
            })
        }
    }
}

async fn verify_path_exists(path: &Path) -> Result<(), FunctionCallError> {
    tokio::fs::metadata(path).await.map_err(|err| {
        FunctionCallError::RespondToModel(format!("unable to access `{}`: {err}", path.display()))
    })?;
    Ok(())
}

async fn run_rg_search(
    pattern: &str,
    include: Option<&str>,
    search_path: &Path,
    limit: usize,
    mode: SearchMode,
    cwd: &Path,
) -> Result<Vec<String>, FunctionCallError> {
    let mut command = Command::new("rg");
    command.current_dir(cwd);
    match mode {
        // Matching lines as `path:line:text`, so a single call answers "where is
        // X and what does that line say" without a follow-up read.
        SearchMode::Content => {
            command
                .arg("--line-number")
                .arg("--no-heading")
                .arg("--with-filename")
                .arg("--color=never");
        }
        // Just the files, newest first — useful for "which files mention X".
        SearchMode::Files => {
            command.arg("--files-with-matches").arg("--sortr=modified");
        }
    }
    command.arg("--regexp").arg(pattern).arg("--no-messages");

    if let Some(glob) = include {
        command.arg("--glob").arg(glob);
    }

    command.arg("--").arg(search_path);

    let output = timeout(COMMAND_TIMEOUT, command.output())
        .await
        .map_err(|_| {
            FunctionCallError::RespondToModel("rg timed out after 30 seconds".to_string())
        })?
        .map_err(|err| {
            FunctionCallError::RespondToModel(format!(
                "failed to launch rg: {err}. Ensure ripgrep is installed and on PATH."
            ))
        })?;

    match output.status.code() {
        Some(0) => Ok(parse_results(&output.stdout, limit)),
        Some(1) => Ok(Vec::new()),
        _ => {
            let stderr = String::from_utf8_lossy(&output.stderr);
            Err(FunctionCallError::RespondToModel(format!(
                "rg failed: {stderr}"
            )))
        }
    }
}

fn parse_results(stdout: &[u8], limit: usize) -> Vec<String> {
    let mut results = Vec::new();
    for line in stdout.split(|byte| *byte == b'\n') {
        if line.is_empty() {
            continue;
        }
        if let Ok(text) = std::str::from_utf8(line) {
            if text.is_empty() {
                continue;
            }
            results.push(text.to_string());
            if results.len() == limit {
                break;
            }
        }
    }
    results
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::process::Command as StdCommand;
    use tempfile::tempdir;

    #[test]
    fn parses_basic_results() {
        let stdout = b"/tmp/file_a.rs\n/tmp/file_b.rs\n";
        let parsed = parse_results(stdout, 10);
        assert_eq!(
            parsed,
            vec!["/tmp/file_a.rs".to_string(), "/tmp/file_b.rs".to_string()]
        );
    }

    #[test]
    fn parse_truncates_after_limit() {
        let stdout = b"/tmp/file_a.rs\n/tmp/file_b.rs\n/tmp/file_c.rs\n";
        let parsed = parse_results(stdout, 2);
        assert_eq!(
            parsed,
            vec!["/tmp/file_a.rs".to_string(), "/tmp/file_b.rs".to_string()]
        );
    }

    #[tokio::test]
    async fn content_mode_returns_matching_lines_with_line_numbers() -> anyhow::Result<()> {
        if !rg_available() {
            return Ok(());
        }
        let temp = tempdir().expect("create temp dir");
        let dir = temp.path();
        std::fs::write(dir.join("sample.py"), "def alpha():\n    return 42\n").unwrap();

        let results = run_rg_search("return", None, dir, 10, SearchMode::Content, dir).await?;
        assert_eq!(results.len(), 1);
        // `path:line:text` — the line number and content are present, so no
        // follow-up read is needed to see what matched.
        assert!(results[0].contains("sample.py:2:"), "got {:?}", results[0]);
        assert!(results[0].contains("return 42"), "got {:?}", results[0]);
        Ok(())
    }

    #[tokio::test]
    async fn run_search_returns_results() -> anyhow::Result<()> {
        if !rg_available() {
            return Ok(());
        }
        let temp = tempdir().expect("create temp dir");
        let dir = temp.path();
        std::fs::write(dir.join("match_one.txt"), "alpha beta gamma").unwrap();
        std::fs::write(dir.join("match_two.txt"), "alpha delta").unwrap();
        std::fs::write(dir.join("other.txt"), "omega").unwrap();

        let results = run_rg_search("alpha", None, dir, 10, SearchMode::Files, dir).await?;
        assert_eq!(results.len(), 2);
        assert!(results.iter().any(|path| path.ends_with("match_one.txt")));
        assert!(results.iter().any(|path| path.ends_with("match_two.txt")));
        Ok(())
    }

    #[tokio::test]
    async fn run_search_with_glob_filter() -> anyhow::Result<()> {
        if !rg_available() {
            return Ok(());
        }
        let temp = tempdir().expect("create temp dir");
        let dir = temp.path();
        std::fs::write(dir.join("match_one.rs"), "alpha beta gamma").unwrap();
        std::fs::write(dir.join("match_two.txt"), "alpha delta").unwrap();

        let results = run_rg_search("alpha", Some("*.rs"), dir, 10, SearchMode::Files, dir).await?;
        assert_eq!(results.len(), 1);
        assert!(results.iter().all(|path| path.ends_with("match_one.rs")));
        Ok(())
    }

    #[tokio::test]
    async fn run_search_respects_limit() -> anyhow::Result<()> {
        if !rg_available() {
            return Ok(());
        }
        let temp = tempdir().expect("create temp dir");
        let dir = temp.path();
        std::fs::write(dir.join("one.txt"), "alpha one").unwrap();
        std::fs::write(dir.join("two.txt"), "alpha two").unwrap();
        std::fs::write(dir.join("three.txt"), "alpha three").unwrap();

        let results = run_rg_search("alpha", None, dir, 2, SearchMode::Files, dir).await?;
        assert_eq!(results.len(), 2);
        Ok(())
    }

    #[tokio::test]
    async fn run_search_handles_no_matches() -> anyhow::Result<()> {
        if !rg_available() {
            return Ok(());
        }
        let temp = tempdir().expect("create temp dir");
        let dir = temp.path();
        std::fs::write(dir.join("one.txt"), "omega").unwrap();

        let results = run_rg_search("alpha", None, dir, 5, SearchMode::Content, dir).await?;
        assert!(results.is_empty());
        Ok(())
    }

    fn rg_available() -> bool {
        StdCommand::new("rg")
            .arg("--version")
            .output()
            .map(|output| output.status.success())
            .unwrap_or(false)
    }
}
