use super::*;
use crate::truncate;
use crate::truncate::TruncationPolicy;
use opencli_git::GhostCommit;
use opencli_protocol::models::ContentItem;
use opencli_protocol::models::FunctionCallOutputContentItem;
use opencli_protocol::models::FunctionCallOutputPayload;
use opencli_protocol::models::LocalShellAction;
use opencli_protocol::models::LocalShellExecAction;
use opencli_protocol::models::LocalShellStatus;
use opencli_protocol::models::ReasoningItemContent;
use opencli_protocol::models::ReasoningItemReasoningSummary;
use pretty_assertions::assert_eq;
use regex_lite::Regex;

const EXEC_FORMAT_MAX_BYTES: usize = 10_000;
const EXEC_FORMAT_MAX_TOKENS: usize = 2_500;

fn assistant_msg(text: &str) -> ResponseItem {
    ResponseItem::Message {
        id: None,
        role: "assistant".to_string(),
        content: vec![ContentItem::OutputText {
            text: text.to_string(),
        }],
        end_turn: None,
    }
}

fn create_history_with_items(items: Vec<ResponseItem>) -> ContextManager {
    let mut h = ContextManager::new();
    // Use a generous but fixed token budget; tests only rely on truncation
    // behavior, not on a specific model's token limit.
    h.record_items(items.iter(), TruncationPolicy::Tokens(10_000));
    h
}

fn user_msg(text: &str) -> ResponseItem {
    ResponseItem::Message {
        id: None,
        role: "user".to_string(),
        content: vec![ContentItem::OutputText {
            text: text.to_string(),
        }],
        end_turn: None,
    }
}

fn user_input_text_msg(text: &str) -> ResponseItem {
    ResponseItem::Message {
        id: None,
        role: "user".to_string(),
        content: vec![ContentItem::InputText {
            text: text.to_string(),
        }],
        end_turn: None,
    }
}

fn reasoning_msg(text: &str) -> ResponseItem {
    ResponseItem::Reasoning {
        id: String::new(),
        summary: vec![ReasoningItemReasoningSummary::SummaryText {
            text: "summary".to_string(),
        }],
        content: Some(vec![ReasoningItemContent::ReasoningText {
            text: text.to_string(),
        }]),
        encrypted_content: None,
    }
}

fn reasoning_with_encrypted_content(len: usize) -> ResponseItem {
    ResponseItem::Reasoning {
        id: String::new(),
        summary: vec![ReasoningItemReasoningSummary::SummaryText {
            text: "summary".to_string(),
        }],
        content: None,
        encrypted_content: Some("a".repeat(len)),
    }
}

fn truncate_exec_output(content: &str) -> String {
    truncate::truncate_text(content, TruncationPolicy::Tokens(EXEC_FORMAT_MAX_TOKENS))
}

#[test]
fn filters_non_api_messages() {
    let mut h = ContextManager::default();
    let policy = TruncationPolicy::Tokens(10_000);
    // System message is not API messages; Other is ignored.
    let system = ResponseItem::Message {
        id: None,
        role: "system".to_string(),
        content: vec![ContentItem::OutputText {
            text: "ignored".to_string(),
        }],
        end_turn: None,
    };
    let reasoning = reasoning_msg("thinking...");
    h.record_items([&system, &reasoning, &ResponseItem::Other], policy);

    // User and assistant should be retained.
    let u = user_msg("hi");
    let a = assistant_msg("hello");
    h.record_items([&u, &a], policy);

    let items = h.raw_items();
    assert_eq!(
        items,
        vec![
            ResponseItem::Reasoning {
                id: String::new(),
                summary: vec![ReasoningItemReasoningSummary::SummaryText {
                    text: "summary".to_string(),
                }],
                content: Some(vec![ReasoningItemContent::ReasoningText {
                    text: "thinking...".to_string(),
                }]),
                encrypted_content: None,
            },
            ResponseItem::Message {
                id: None,
                role: "user".to_string(),
                content: vec![ContentItem::OutputText {
                    text: "hi".to_string()
                }],
                end_turn: None,
            },
            ResponseItem::Message {
                id: None,
                role: "assistant".to_string(),
                content: vec![ContentItem::OutputText {
                    text: "hello".to_string()
                }],
                end_turn: None,
            }
        ]
    );
}

#[test]
fn non_last_reasoning_tokens_return_zero_when_no_user_messages() {
    let history = create_history_with_items(vec![reasoning_with_encrypted_content(800)]);

    assert_eq!(history.get_non_last_reasoning_items_tokens(), 0);
}

#[test]
fn non_last_reasoning_tokens_ignore_entries_after_last_user() {
    let history = create_history_with_items(vec![
        reasoning_with_encrypted_content(900),
        user_msg("first"),
        reasoning_with_encrypted_content(1_000),
        user_msg("second"),
        reasoning_with_encrypted_content(2_000),
    ]);
    // first: (900 * 0.75 - 650) / 4 = 6.25 tokens
    // second: (1000 * 0.75 - 650) / 4 = 25 tokens
    // first + second = 62.5
    assert_eq!(history.get_non_last_reasoning_items_tokens(), 32);
}

#[test]
fn get_history_for_prompt_drops_ghost_commits() {
    let items = vec![ResponseItem::GhostSnapshot {
        ghost_commit: GhostCommit::new("ghost-1".to_string(), None, Vec::new(), Vec::new()),
    }];
    let history = create_history_with_items(items);
    let filtered = history.for_prompt();
    assert_eq!(filtered, vec![]);
}

#[test]
fn remove_first_item_removes_matching_output_for_function_call() {
    let items = vec![
        ResponseItem::FunctionCall {
            id: None,
            name: "do_it".to_string(),
            arguments: "{}".to_string(),
            call_id: "call-1".to_string(),
        },
        ResponseItem::FunctionCallOutput {
            call_id: "call-1".to_string(),
            output: FunctionCallOutputPayload {
                content: "ok".to_string(),
                ..Default::default()
            },
        },
    ];
    let mut h = create_history_with_items(items);
    h.remove_first_item();
    assert_eq!(h.raw_items(), vec![]);
}

#[test]
fn remove_first_item_removes_matching_call_for_output() {
    let items = vec![
        ResponseItem::FunctionCallOutput {
            call_id: "call-2".to_string(),
            output: FunctionCallOutputPayload {
                content: "ok".to_string(),
                ..Default::default()
            },
        },
        ResponseItem::FunctionCall {
            id: None,
            name: "do_it".to_string(),
            arguments: "{}".to_string(),
            call_id: "call-2".to_string(),
        },
    ];
    let mut h = create_history_with_items(items);
    h.remove_first_item();
    assert_eq!(h.raw_items(), vec![]);
}

#[test]
fn replace_last_turn_images_replaces_tool_output_images() {
    let items = vec![
        user_input_text_msg("hi"),
        ResponseItem::FunctionCallOutput {
            call_id: "call-1".to_string(),
            output: FunctionCallOutputPayload {
                content: "ok".to_string(),
                content_items: Some(vec![FunctionCallOutputContentItem::InputImage {
                    image_url: "data:image/png;base64,AAA".to_string(),
                }]),
                success: Some(true),
            },
        },
    ];
    let mut history = create_history_with_items(items);

    assert!(history.replace_last_turn_images("Invalid image"));

    assert_eq!(
        history.raw_items(),
        vec![
            user_input_text_msg("hi"),
            ResponseItem::FunctionCallOutput {
                call_id: "call-1".to_string(),
                output: FunctionCallOutputPayload {
                    content: "ok".to_string(),
                    content_items: Some(vec![FunctionCallOutputContentItem::InputText {
                        text: "Invalid image".to_string(),
                    }]),
                    success: Some(true),
                },
            },
        ]
    );
}

#[test]
fn replace_last_turn_images_does_not_touch_user_images() {
    let items = vec![ResponseItem::Message {
        id: None,
        role: "user".to_string(),
        content: vec![ContentItem::InputImage {
            image_url: "data:image/png;base64,AAA".to_string(),
        }],
        end_turn: None,
    }];
    let mut history = create_history_with_items(items.clone());

    assert!(!history.replace_last_turn_images("Invalid image"));
    assert_eq!(history.raw_items(), items);
}

#[test]
fn remove_first_item_handles_local_shell_pair() {
    let items = vec![
        ResponseItem::LocalShellCall {
            id: None,
            call_id: Some("call-3".to_string()),
            status: LocalShellStatus::Completed,
            action: LocalShellAction::Exec(LocalShellExecAction {
                command: vec!["echo".to_string(), "hi".to_string()],
                timeout_ms: None,
                working_directory: None,
                env: None,
                user: None,
            }),
        },
        ResponseItem::FunctionCallOutput {
            call_id: "call-3".to_string(),
            output: FunctionCallOutputPayload {
                content: "ok".to_string(),
                ..Default::default()
            },
        },
    ];
    let mut h = create_history_with_items(items);
    h.remove_first_item();
    assert_eq!(h.raw_items(), vec![]);
}

#[test]
fn drop_last_n_user_turns_preserves_prefix() {
    let items = vec![
        assistant_msg("session prefix item"),
        user_msg("u1"),
        assistant_msg("a1"),
        user_msg("u2"),
        assistant_msg("a2"),
    ];

    let mut history = create_history_with_items(items);
    history.drop_last_n_user_turns(1);
    assert_eq!(
        history.for_prompt(),
        vec![
            assistant_msg("session prefix item"),
            user_msg("u1"),
            assistant_msg("a1"),
        ]
    );

    let mut history = create_history_with_items(vec![
        assistant_msg("session prefix item"),
        user_msg("u1"),
        assistant_msg("a1"),
        user_msg("u2"),
        assistant_msg("a2"),
    ]);
    history.drop_last_n_user_turns(99);
    assert_eq!(
        history.for_prompt(),
        vec![assistant_msg("session prefix item")]
    );
}

#[test]
fn drop_last_n_user_turns_ignores_session_prefix_user_messages() {
    let items = vec![
        user_input_text_msg("<environment_context>ctx</environment_context>"),
        user_input_text_msg("<user_instructions>do the thing</user_instructions>"),
        user_input_text_msg(
            "# AGENTS.md instructions for test_directory\n\n<INSTRUCTIONS>\ntest_text\n</INSTRUCTIONS>",
        ),
        user_input_text_msg(
            "<skill>\n<name>demo</name>\n<path>skills/demo/SKILL.md</path>\nbody\n</skill>",
        ),
        user_input_text_msg("<user_shell_command>echo 42</user_shell_command>"),
        user_input_text_msg("turn 1 user"),
        assistant_msg("turn 1 assistant"),
        user_input_text_msg("turn 2 user"),
        assistant_msg("turn 2 assistant"),
    ];

    let mut history = create_history_with_items(items);
    history.drop_last_n_user_turns(1);

    let expected_prefix_and_first_turn = vec![
        user_input_text_msg("<environment_context>ctx</environment_context>"),
        user_input_text_msg("<user_instructions>do the thing</user_instructions>"),
        user_input_text_msg(
            "# AGENTS.md instructions for test_directory\n\n<INSTRUCTIONS>\ntest_text\n</INSTRUCTIONS>",
        ),
        user_input_text_msg(
            "<skill>\n<name>demo</name>\n<path>skills/demo/SKILL.md</path>\nbody\n</skill>",
        ),
        user_input_text_msg("<user_shell_command>echo 42</user_shell_command>"),
        user_input_text_msg("turn 1 user"),
        assistant_msg("turn 1 assistant"),
    ];

    assert_eq!(history.for_prompt(), expected_prefix_and_first_turn);

    let expected_prefix_only = vec![
        user_input_text_msg("<environment_context>ctx</environment_context>"),
        user_input_text_msg("<user_instructions>do the thing</user_instructions>"),
        user_input_text_msg(
            "# AGENTS.md instructions for test_directory\n\n<INSTRUCTIONS>\ntest_text\n</INSTRUCTIONS>",
        ),
        user_input_text_msg(
            "<skill>\n<name>demo</name>\n<path>skills/demo/SKILL.md</path>\nbody\n</skill>",
        ),
        user_input_text_msg("<user_shell_command>echo 42</user_shell_command>"),
    ];

    let mut history = create_history_with_items(vec![
        user_input_text_msg("<environment_context>ctx</environment_context>"),
        user_input_text_msg("<user_instructions>do the thing</user_instructions>"),
        user_input_text_msg(
            "# AGENTS.md instructions for test_directory\n\n<INSTRUCTIONS>\ntest_text\n</INSTRUCTIONS>",
        ),
        user_input_text_msg(
            "<skill>\n<name>demo</name>\n<path>skills/demo/SKILL.md</path>\nbody\n</skill>",
        ),
        user_input_text_msg("<user_shell_command>echo 42</user_shell_command>"),
        user_input_text_msg("turn 1 user"),
        assistant_msg("turn 1 assistant"),
        user_input_text_msg("turn 2 user"),
        assistant_msg("turn 2 assistant"),
    ]);
    history.drop_last_n_user_turns(2);
    assert_eq!(history.for_prompt(), expected_prefix_only);

    let mut history = create_history_with_items(vec![
        user_input_text_msg("<environment_context>ctx</environment_context>"),
        user_input_text_msg("<user_instructions>do the thing</user_instructions>"),
        user_input_text_msg(
            "# AGENTS.md instructions for test_directory\n\n<INSTRUCTIONS>\ntest_text\n</INSTRUCTIONS>",
        ),
        user_input_text_msg(
            "<skill>\n<name>demo</name>\n<path>skills/demo/SKILL.md</path>\nbody\n</skill>",
        ),
        user_input_text_msg("<user_shell_command>echo 42</user_shell_command>"),
        user_input_text_msg("turn 1 user"),
        assistant_msg("turn 1 assistant"),
        user_input_text_msg("turn 2 user"),
        assistant_msg("turn 2 assistant"),
    ]);
    history.drop_last_n_user_turns(3);
    assert_eq!(history.for_prompt(), expected_prefix_only);
}

#[test]
fn remove_first_item_handles_custom_tool_pair() {
    let items = vec![
        ResponseItem::CustomToolCall {
            id: None,
            status: None,
            call_id: "tool-1".to_string(),
            name: "my_tool".to_string(),
            input: "{}".to_string(),
        },
        ResponseItem::CustomToolCallOutput {
            call_id: "tool-1".to_string(),
            output: "ok".to_string(),
        },
    ];
    let mut h = create_history_with_items(items);
    h.remove_first_item();
    assert_eq!(h.raw_items(), vec![]);
}

#[test]
fn normalization_retains_local_shell_outputs() {
    let items = vec![
        ResponseItem::LocalShellCall {
            id: None,
            call_id: Some("shell-1".to_string()),
            status: LocalShellStatus::Completed,
            action: LocalShellAction::Exec(LocalShellExecAction {
                command: vec!["echo".to_string(), "hi".to_string()],
                timeout_ms: None,
                working_directory: None,
                env: None,
                user: None,
            }),
        },
        ResponseItem::FunctionCallOutput {
            call_id: "shell-1".to_string(),
            output: FunctionCallOutputPayload {
                content: "Total output lines: 1\n\nok".to_string(),
                ..Default::default()
            },
        },
    ];

    let history = create_history_with_items(items.clone());
    let normalized = history.for_prompt();
    assert_eq!(normalized, items);
}

#[test]
fn record_items_truncates_function_call_output_content() {
    let mut history = ContextManager::new();
    // Any reasonably small token budget works; the test only cares that
    // truncation happens and the marker is present.
    let policy = TruncationPolicy::Tokens(1_000);
    let long_line = "a very long line to trigger truncation\n";
    let long_output = long_line.repeat(2_500);
    let item = ResponseItem::FunctionCallOutput {
        call_id: "call-100".to_string(),
        output: FunctionCallOutputPayload {
            content: long_output.clone(),
            success: Some(true),
            ..Default::default()
        },
    };

    history.record_items([&item], policy);

    assert_eq!(history.items.len(), 1);
    match &history.items[0] {
        ResponseItem::FunctionCallOutput { output, .. } => {
            assert_ne!(output.content, long_output);
            assert!(
                output.content.contains("tokens truncated"),
                "expected token-based truncation marker, got {}",
                output.content
            );
            assert!(
                output.content.contains("tokens truncated"),
                "expected truncation marker, got {}",
                output.content
            );
        }
        other => panic!("unexpected history item: {other:?}"),
    }
}

#[test]
fn record_items_truncates_custom_tool_call_output_content() {
    let mut history = ContextManager::new();
    let policy = TruncationPolicy::Tokens(1_000);
    let line = "custom output that is very long\n";
    let long_output = line.repeat(2_500);
    let item = ResponseItem::CustomToolCallOutput {
        call_id: "tool-200".to_string(),
        output: long_output.clone(),
    };

    history.record_items([&item], policy);

    assert_eq!(history.items.len(), 1);
    match &history.items[0] {
        ResponseItem::CustomToolCallOutput { output, .. } => {
            assert_ne!(output, &long_output);
            assert!(
                output.contains("tokens truncated"),
                "expected token-based truncation marker, got {output}"
            );
            assert!(
                output.contains("tokens truncated") || output.contains("bytes truncated"),
                "expected truncation marker, got {output}"
            );
        }
        other => panic!("unexpected history item: {other:?}"),
    }
}

#[test]
fn record_items_respects_custom_token_limit() {
    let mut history = ContextManager::new();
    let policy = TruncationPolicy::Tokens(10);
    let long_output = "tokenized content repeated many times ".repeat(200);
    let item = ResponseItem::FunctionCallOutput {
        call_id: "call-custom-limit".to_string(),
        output: FunctionCallOutputPayload {
            content: long_output,
            success: Some(true),
            ..Default::default()
        },
    };

    history.record_items([&item], policy);

    let stored = match &history.items[0] {
        ResponseItem::FunctionCallOutput { output, .. } => output,
        other => panic!("unexpected history item: {other:?}"),
    };
    assert!(stored.content.contains("tokens truncated"));
}

fn assert_truncated_message_matches(message: &str, line: &str, expected_removed: usize) {
    let pattern = truncated_message_pattern(line);
    let regex = Regex::new(&pattern).unwrap_or_else(|err| {
        panic!("failed to compile regex {pattern}: {err}");
    });
    let captures = regex
        .captures(message)
        .unwrap_or_else(|| panic!("message failed to match pattern {pattern}: {message}"));
    let body = captures
        .name("body")
        .expect("missing body capture")
        .as_str();
    assert!(
        body.len() <= EXEC_FORMAT_MAX_BYTES,
        "body exceeds byte limit: {} bytes",
        body.len()
    );
    let removed: usize = captures
        .name("removed")
        .expect("missing removed capture")
        .as_str()
        .parse()
        .unwrap_or_else(|err| panic!("invalid removed tokens: {err}"));
    assert_eq!(removed, expected_removed, "mismatched removed token count");
}

fn truncated_message_pattern(line: &str) -> String {
    let escaped_line = regex_lite::escape(line);
    format!(r"(?s)^(?P<body>{escaped_line}.*?)(?:\r?)?…(?P<removed>\d+) tokens truncated…(?:.*)?$")
}

#[test]
fn format_exec_output_truncates_large_error() {
    let line = "very long execution error line that should trigger truncation\n";
    let large_error = line.repeat(2_500); // way beyond both byte and line limits

    let truncated = truncate_exec_output(&large_error);

    assert_truncated_message_matches(&truncated, line, 36250);
    assert_ne!(truncated, large_error);
}

#[test]
fn format_exec_output_marks_byte_truncation_without_omitted_lines() {
    let long_line = "a".repeat(EXEC_FORMAT_MAX_BYTES + 10000);
    let truncated = truncate_exec_output(&long_line);
    assert_ne!(truncated, long_line);
    assert_truncated_message_matches(&truncated, "a", 2500);
    assert!(
        !truncated.contains("omitted"),
        "line omission marker should not appear when no lines were dropped: {truncated}"
    );
}

#[test]
fn format_exec_output_returns_original_when_within_limits() {
    let content = "example output\n".repeat(10);
    assert_eq!(truncate_exec_output(&content), content);
}

#[test]
fn format_exec_output_reports_omitted_lines_and_keeps_head_and_tail() {
    let total_lines = 2_000;
    let filler = "x".repeat(64);
    let content: String = (0..total_lines)
        .map(|idx| format!("line-{idx}-{filler}\n"))
        .collect();

    let truncated = truncate_exec_output(&content);
    assert_truncated_message_matches(&truncated, "line-0-", 34_723);
    assert!(
        truncated.contains("line-0-"),
        "expected head line to remain: {truncated}"
    );

    let last_line = format!("line-{}-", total_lines - 1);
    assert!(
        truncated.contains(&last_line),
        "expected tail line to remain: {truncated}"
    );
}

#[test]
fn format_exec_output_prefers_line_marker_when_both_limits_exceeded() {
    let total_lines = 300;
    let long_line = "x".repeat(256);
    let content: String = (0..total_lines)
        .map(|idx| format!("line-{idx}-{long_line}\n"))
        .collect();

    let truncated = truncate_exec_output(&content);

    assert_truncated_message_matches(&truncated, "line-0-", 17_423);
}

#[cfg(not(debug_assertions))]
#[test]
fn normalize_adds_missing_output_for_function_call() {
    let items = vec![ResponseItem::FunctionCall {
        id: None,
        name: "do_it".to_string(),
        arguments: "{}".to_string(),
        call_id: "call-x".to_string(),
    }];
    let mut h = create_history_with_items(items);

    h.normalize_history();

    assert_eq!(
        h.raw_items(),
        vec![
            ResponseItem::FunctionCall {
                id: None,
                name: "do_it".to_string(),
                arguments: "{}".to_string(),
                call_id: "call-x".to_string(),
            },
            ResponseItem::FunctionCallOutput {
                call_id: "call-x".to_string(),
                output: FunctionCallOutputPayload {
                    content: "aborted".to_string(),
                    ..Default::default()
                },
            },
        ]
    );
}

#[cfg(not(debug_assertions))]
#[test]
fn normalize_adds_missing_output_for_custom_tool_call() {
    let items = vec![ResponseItem::CustomToolCall {
        id: None,
        status: None,
        call_id: "tool-x".to_string(),
        name: "custom".to_string(),
        input: "{}".to_string(),
    }];
    let mut h = create_history_with_items(items);

    h.normalize_history();

    assert_eq!(
        h.raw_items(),
        vec![
            ResponseItem::CustomToolCall {
                id: None,
                status: None,
                call_id: "tool-x".to_string(),
                name: "custom".to_string(),
                input: "{}".to_string(),
            },
            ResponseItem::CustomToolCallOutput {
                call_id: "tool-x".to_string(),
                output: "aborted".to_string(),
            },
        ]
    );
}

#[cfg(not(debug_assertions))]
#[test]
fn normalize_adds_missing_output_for_local_shell_call_with_id() {
    let items = vec![ResponseItem::LocalShellCall {
        id: None,
        call_id: Some("shell-1".to_string()),
        status: LocalShellStatus::Completed,
        action: LocalShellAction::Exec(LocalShellExecAction {
            command: vec!["echo".to_string(), "hi".to_string()],
            timeout_ms: None,
            working_directory: None,
            env: None,
            user: None,
        }),
    }];
    let mut h = create_history_with_items(items);

    h.normalize_history();

    assert_eq!(
        h.raw_items(),
        vec![
            ResponseItem::LocalShellCall {
                id: None,
                call_id: Some("shell-1".to_string()),
                status: LocalShellStatus::Completed,
                action: LocalShellAction::Exec(LocalShellExecAction {
                    command: vec!["echo".to_string(), "hi".to_string()],
                    timeout_ms: None,
                    working_directory: None,
                    env: None,
                    user: None,
                }),
            },
            ResponseItem::FunctionCallOutput {
                call_id: "shell-1".to_string(),
                output: FunctionCallOutputPayload {
                    content: "aborted".to_string(),
                    ..Default::default()
                },
            },
        ]
    );
}

#[cfg(not(debug_assertions))]
#[test]
fn normalize_removes_orphan_function_call_output() {
    let items = vec![ResponseItem::FunctionCallOutput {
        call_id: "orphan-1".to_string(),
        output: FunctionCallOutputPayload {
            content: "ok".to_string(),
            ..Default::default()
        },
    }];
    let mut h = create_history_with_items(items);

    h.normalize_history();

    assert_eq!(h.raw_items(), vec![]);
}

#[cfg(not(debug_assertions))]
#[test]
fn normalize_removes_orphan_custom_tool_call_output() {
    let items = vec![ResponseItem::CustomToolCallOutput {
        call_id: "orphan-2".to_string(),
        output: "ok".to_string(),
    }];
    let mut h = create_history_with_items(items);

    h.normalize_history();

    assert_eq!(h.raw_items(), vec![]);
}

#[cfg(not(debug_assertions))]
#[test]
fn normalize_mixed_inserts_and_removals() {
    let items = vec![
        // Will get an inserted output
        ResponseItem::FunctionCall {
            id: None,
            name: "f1".to_string(),
            arguments: "{}".to_string(),
            call_id: "c1".to_string(),
        },
        // Orphan output that should be removed
        ResponseItem::FunctionCallOutput {
            call_id: "c2".to_string(),
            output: FunctionCallOutputPayload {
                content: "ok".to_string(),
                ..Default::default()
            },
        },
        // Will get an inserted custom tool output
        ResponseItem::CustomToolCall {
            id: None,
            status: None,
            call_id: "t1".to_string(),
            name: "tool".to_string(),
            input: "{}".to_string(),
        },
        // Local shell call also gets an inserted function call output
        ResponseItem::LocalShellCall {
            id: None,
            call_id: Some("s1".to_string()),
            status: LocalShellStatus::Completed,
            action: LocalShellAction::Exec(LocalShellExecAction {
                command: vec!["echo".to_string()],
                timeout_ms: None,
                working_directory: None,
                env: None,
                user: None,
            }),
        },
    ];
    let mut h = create_history_with_items(items);

    h.normalize_history();

    assert_eq!(
        h.raw_items(),
        vec![
            ResponseItem::FunctionCall {
                id: None,
                name: "f1".to_string(),
                arguments: "{}".to_string(),
                call_id: "c1".to_string(),
            },
            ResponseItem::FunctionCallOutput {
                call_id: "c1".to_string(),
                output: FunctionCallOutputPayload {
                    content: "aborted".to_string(),
                    ..Default::default()
                },
            },
            ResponseItem::CustomToolCall {
                id: None,
                status: None,
                call_id: "t1".to_string(),
                name: "tool".to_string(),
                input: "{}".to_string(),
            },
            ResponseItem::CustomToolCallOutput {
                call_id: "t1".to_string(),
                output: "aborted".to_string(),
            },
            ResponseItem::LocalShellCall {
                id: None,
                call_id: Some("s1".to_string()),
                status: LocalShellStatus::Completed,
                action: LocalShellAction::Exec(LocalShellExecAction {
                    command: vec!["echo".to_string()],
                    timeout_ms: None,
                    working_directory: None,
                    env: None,
                    user: None,
                }),
            },
            ResponseItem::FunctionCallOutput {
                call_id: "s1".to_string(),
                output: FunctionCallOutputPayload {
                    content: "aborted".to_string(),
                    ..Default::default()
                },
            },
        ]
    );
}

#[test]
fn normalize_adds_missing_output_for_function_call_inserts_output() {
    let items = vec![ResponseItem::FunctionCall {
        id: None,
        name: "do_it".to_string(),
        arguments: "{}".to_string(),
        call_id: "call-x".to_string(),
    }];
    let mut h = create_history_with_items(items);
    h.normalize_history();
    assert_eq!(
        h.raw_items(),
        vec![
            ResponseItem::FunctionCall {
                id: None,
                name: "do_it".to_string(),
                arguments: "{}".to_string(),
                call_id: "call-x".to_string(),
            },
            ResponseItem::FunctionCallOutput {
                call_id: "call-x".to_string(),
                output: FunctionCallOutputPayload {
                    content: "aborted".to_string(),
                    ..Default::default()
                },
            },
        ]
    );
}

#[cfg(debug_assertions)]
#[test]
#[should_panic]
fn normalize_adds_missing_output_for_custom_tool_call_panics_in_debug() {
    let items = vec![ResponseItem::CustomToolCall {
        id: None,
        status: None,
        call_id: "tool-x".to_string(),
        name: "custom".to_string(),
        input: "{}".to_string(),
    }];
    let mut h = create_history_with_items(items);
    h.normalize_history();
}

#[cfg(debug_assertions)]
#[test]
#[should_panic]
fn normalize_adds_missing_output_for_local_shell_call_with_id_panics_in_debug() {
    let items = vec![ResponseItem::LocalShellCall {
        id: None,
        call_id: Some("shell-1".to_string()),
        status: LocalShellStatus::Completed,
        action: LocalShellAction::Exec(LocalShellExecAction {
            command: vec!["echo".to_string(), "hi".to_string()],
            timeout_ms: None,
            working_directory: None,
            env: None,
            user: None,
        }),
    }];
    let mut h = create_history_with_items(items);
    h.normalize_history();
}

#[cfg(debug_assertions)]
#[test]
#[should_panic]
fn normalize_removes_orphan_function_call_output_panics_in_debug() {
    let items = vec![ResponseItem::FunctionCallOutput {
        call_id: "orphan-1".to_string(),
        output: FunctionCallOutputPayload {
            content: "ok".to_string(),
            ..Default::default()
        },
    }];
    let mut h = create_history_with_items(items);
    h.normalize_history();
}

#[cfg(debug_assertions)]
#[test]
#[should_panic]
fn normalize_removes_orphan_custom_tool_call_output_panics_in_debug() {
    let items = vec![ResponseItem::CustomToolCallOutput {
        call_id: "orphan-2".to_string(),
        output: "ok".to_string(),
    }];
    let mut h = create_history_with_items(items);
    h.normalize_history();
}

#[cfg(debug_assertions)]
#[test]
#[should_panic]
fn normalize_mixed_inserts_and_removals_panics_in_debug() {
    let items = vec![
        ResponseItem::FunctionCall {
            id: None,
            name: "f1".to_string(),
            arguments: "{}".to_string(),
            call_id: "c1".to_string(),
        },
        ResponseItem::FunctionCallOutput {
            call_id: "c2".to_string(),
            output: FunctionCallOutputPayload {
                content: "ok".to_string(),
                ..Default::default()
            },
        },
        ResponseItem::CustomToolCall {
            id: None,
            status: None,
            call_id: "t1".to_string(),
            name: "tool".to_string(),
            input: "{}".to_string(),
        },
        ResponseItem::LocalShellCall {
            id: None,
            call_id: Some("s1".to_string()),
            status: LocalShellStatus::Completed,
            action: LocalShellAction::Exec(LocalShellExecAction {
                command: vec!["echo".to_string()],
                timeout_ms: None,
                working_directory: None,
                env: None,
                user: None,
            }),
        },
    ];
    let mut h = create_history_with_items(items);
    h.normalize_history();
}

#[test]
fn should_estimate_a_reopened_conversation_rather_than_call_it_empty() {
    // A reopened conversation has no recorded usage: nothing has been sent, so
    // nothing has been counted. Reporting zero meant auto-compaction never
    // fired and the whole history went out on the first prompt — measured
    // against a real 32K-window model, the reply took over two minutes and
    // was then retried eight times.
    let history = create_history_with_items(vec![
        user_msg(&"a long question ".repeat(400)),
        assistant_msg(&"a long answer ".repeat(400)),
    ]);

    let estimated = history.get_total_token_usage(false);
    assert!(
        estimated > 2_000,
        "a conversation of this size cannot report as empty, got {estimated}"
    );
}

#[test]
fn should_not_trust_a_recorded_count_smaller_than_the_history_it_describes() {
    // Resume seeds the count from the rollout — the size of the request that
    // was last sent, not of the history rebuilt beside it. Trusting it meant
    // an oversized request went out anyway.
    let mut history = create_history_with_items(vec![
        user_msg(&"a long question ".repeat(400)),
        assistant_msg(&"a long answer ".repeat(400)),
    ]);
    history.set_token_info(Some(TokenUsageInfo::full_context_window(500)));

    assert!(
        history.get_total_token_usage(false) > 2_000,
        "the history is what will be sent, whatever the last request cost"
    );
}

#[test]
fn should_report_nothing_for_a_conversation_that_really_is_empty() {
    let history = ContextManager::new();
    assert_eq!(history.get_total_token_usage(false), 0);
}

#[test]
fn should_not_count_the_json_around_the_words() {
    // The estimate decides when to compact, so it has to be close and not
    // merely safe. Counting the serialised item — field names, quotes, every
    // escaped newline — ran so far ahead of the truth that a conversation the
    // model reported as 17,000 tokens estimated past a 22,937 limit and
    // compacted again after every few commands.
    let text = "word ".repeat(2_000); // 10,000 characters, ~2,500 tokens
    let history = create_history_with_items(vec![assistant_msg(&text)]);

    // Measured against the model this runs on: English is about 4.65 bytes to
    // a token, so 10,000 characters is a little over 2,000. The estimate uses
    // three bytes and so reads a little high, which is the safe direction.
    let estimated = history.get_total_token_usage(false);
    assert!(
        (2_000..=4_000).contains(&estimated),
        "expected an estimate in the right order for 10,000 characters, got {estimated}"
    );
}

#[test]
fn should_price_a_picture_at_what_is_actually_sent() {
    // Priced at a flat few thousand bytes — a picture being worth about a
    // thousand tokens to a model that can see — compaction never fired, and
    // every turn carried the whole 286,682-character encoding again. What
    // goes down the wire is what it costs.
    let huge = "A".repeat(280_000);
    let with_image = ResponseItem::Message {
        id: None,
        role: "user".to_string(),
        content: vec![
            ContentItem::InputText {
                text: "look".to_string(),
            },
            ContentItem::InputImage {
                image_url: format!("data:image/png;base64,{huge}"),
            },
        ],
        end_turn: None,
    };
    let history = create_history_with_items(vec![with_image]);

    let estimated = history.get_total_token_usage(false);
    assert!(
        estimated > 50_000,
        "a picture this size cannot look cheap, got {estimated}"
    );
}

#[test]
fn should_count_what_a_request_carries_beyond_the_conversation() {
    // The gap that made compaction run once a turn: the conversation was
    // estimated at 14,986 tokens while the provider charged 25,000 for the
    // request, the difference being the tool schemas of four connectors. The
    // limit was 21,790, so one number was under it and the other over, and
    // compacting swapped which one was being read.
    let mut history = create_history_with_items(vec![user_msg(&"word ".repeat(2_000))]);
    let conversation_only = history.get_total_token_usage(false);

    history.learn_request_overhead(25_000, 14_986);

    assert_eq!(history.request_overhead(), 25_000 - 14_986);
    assert_eq!(
        history.get_total_token_usage(false),
        conversation_only + (25_000 - 14_986),
        "the estimate has to describe the same request the provider billed"
    );
}

#[test]
fn should_keep_the_largest_overhead_seen_rather_than_the_latest() {
    // A turn whose request happened to be cheap must not talk the session out
    // of an overhead it has already paid, because the understated figure would
    // land on exactly the turn that decides whether to compact.
    let mut history = create_history_with_items(vec![user_msg("hello")]);

    history.learn_request_overhead(25_000, 15_000);
    history.learn_request_overhead(18_000, 15_000);

    assert_eq!(history.request_overhead(), 10_000);
}

#[test]
fn should_ignore_an_overhead_that_measures_as_negative() {
    // The estimate is approximate and can overshoot the billed figure; that
    // says nothing about the tool schemas and must not be recorded as a
    // discount.
    let mut history = create_history_with_items(vec![user_msg("hello")]);

    history.learn_request_overhead(9_000, 12_000);

    assert_eq!(history.request_overhead(), 0);
}
