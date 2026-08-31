pub mod context;
pub mod events;
pub(crate) mod handlers;
pub mod orchestrator;
pub mod parallel;
pub mod registry;
pub mod router;
pub mod runtimes;
pub mod sandboxing;
pub mod spec;

use crate::exec::ExecToolCallOutput;
use crate::truncate::TruncationPolicy;
use crate::truncate::formatted_truncate_text;
use crate::truncate::truncate_text;
pub use router::ToolRouter;
use serde::Serialize;

/// Appended to the model instructions when the structured file tools are
/// enabled. The base prompt tells the model to search and read through the
/// shell (`rg`, `cat`); this steers it to the dedicated tools instead, whose
/// bounded, structured output is what keeps context clean and stops the model
/// from re-reading files it has already seen.
pub(crate) const STRUCTURED_FILE_TOOLS_GUIDANCE: &str = "

# File navigation — IMPORTANT

This session provides dedicated tools for exploring the workspace. They replace
the shell for reading, searching, and listing. This rule overrides any earlier
guidance that told you to use `rg`, `grep`, `cat`, `sed`, `ls`, or `find` in the
shell for these purposes.

- To search code, call `search_text`. It returns matching lines as
  `path:line:text`. Do NOT run `rg`/`grep` in the shell.
- To read a file, call `open_file` with the line range you need. Do NOT run
  `cat`/`sed`/`head`/`tail` in the shell, and do not read a whole file when a
  range will do.
- To list a directory, call `browse_dir`. Do NOT run `ls`/`find` in the shell.

Use the shell only to run programs — builds, tests, git, scripts. Never re-read
a file you have already read unless you changed it. Following this keeps your
context small and your work focused.";

// Telemetry preview limits: keep log events smaller than model budgets.
pub(crate) const TELEMETRY_PREVIEW_MAX_BYTES: usize = 2 * 1024; // 2 KiB
pub(crate) const TELEMETRY_PREVIEW_MAX_LINES: usize = 64; // lines
pub(crate) const TELEMETRY_PREVIEW_TRUNCATION_NOTICE: &str =
    "[... telemetry preview truncated ...]";

/// Format the combined exec output for sending back to the model.
/// Includes exit code and duration metadata; truncates large bodies safely.
pub fn format_exec_output_for_model_structured(
    exec_output: &ExecToolCallOutput,
    truncation_policy: TruncationPolicy,
) -> String {
    let ExecToolCallOutput {
        exit_code,
        duration,
        ..
    } = exec_output;

    #[derive(Serialize)]
    struct ExecMetadata {
        exit_code: i32,
        duration_seconds: f32,
    }

    #[derive(Serialize)]
    struct ExecOutput<'a> {
        output: &'a str,
        metadata: ExecMetadata,
    }

    // round to 1 decimal place
    let duration_seconds = ((duration.as_secs_f32()) * 10.0).round() / 10.0;

    let formatted_output = format_exec_output_str(exec_output, truncation_policy);

    let payload = ExecOutput {
        output: &formatted_output,
        metadata: ExecMetadata {
            exit_code: *exit_code,
            duration_seconds,
        },
    };

    #[expect(clippy::expect_used)]
    serde_json::to_string(&payload).expect("serialize ExecOutput")
}

pub fn format_exec_output_for_model_freeform(
    exec_output: &ExecToolCallOutput,
    truncation_policy: TruncationPolicy,
) -> String {
    // round to 1 decimal place
    let duration_seconds = ((exec_output.duration.as_secs_f32()) * 10.0).round() / 10.0;

    let content = build_content_with_timeout(exec_output);

    let total_lines = content.lines().count();

    let formatted_output = truncate_text(&content, truncation_policy);

    let mut sections = Vec::new();

    sections.push(format!("Exit code: {}", exec_output.exit_code));
    sections.push(format!("Wall time: {duration_seconds} seconds"));
    if total_lines != formatted_output.lines().count() {
        sections.push(format!("Total output lines: {total_lines}"));
    }

    sections.push("Output:".to_string());
    sections.push(formatted_output);

    sections.join("\n")
}

pub fn format_exec_output_str(
    exec_output: &ExecToolCallOutput,
    truncation_policy: TruncationPolicy,
) -> String {
    let content = build_content_with_timeout(exec_output);

    // Truncate for model consumption before serialization.
    formatted_truncate_text(&content, truncation_policy)
}

/// Extracts exec output content and prepends a timeout message if the command timed out.
fn build_content_with_timeout(exec_output: &ExecToolCallOutput) -> String {
    if exec_output.timed_out {
        format!(
            "command timed out after {} milliseconds\n{}",
            exec_output.duration.as_millis(),
            exec_output.aggregated_output.text
        )
    } else {
        exec_output.aggregated_output.text.clone()
    }
}
