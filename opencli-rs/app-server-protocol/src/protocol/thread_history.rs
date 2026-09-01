use crate::protocol::v2::ThreadItem;
use crate::protocol::v2::ThreadTokenUsage;
use crate::protocol::v2::Turn;
use crate::protocol::v2::TurnError;
use crate::protocol::v2::TurnStatus;
use crate::protocol::v2::UserInput;
use opencli_protocol::protocol::AgentReasoningEvent;
use opencli_protocol::protocol::AgentReasoningRawContentEvent;
use opencli_protocol::protocol::EventMsg;
use opencli_protocol::protocol::ItemCompletedEvent;
use opencli_protocol::protocol::ThreadRolledBackEvent;
use opencli_protocol::protocol::TurnAbortedEvent;
use opencli_protocol::protocol::UserMessageEvent;
use crate::protocol::v2::CommandExecutionStatus;
use crate::protocol::v2::McpToolCallResult;
use crate::protocol::v2::McpToolCallStatus;
use opencli_protocol::models::ResponseItem;
use opencli_protocol::protocol::RolloutItem;
use opencli_protocol::protocol::RolloutLine;

/// Shown where a conversation was compacted.
///
/// Written as a sentence rather than a marker the interface has to know about,
/// so it survives a front end that has never heard of compaction.
const COMPACTION_NOTICE: &str =
    "— Earlier messages were summarised here to fit the model's context. \
     The full transcript is still on disk.";

/// What a recorded tool output carries, once opened.
struct RecordedOutput {
    text: String,
    exit_code: Option<i32>,
    duration_ms: Option<i64>,
}

/// Take a command's result out of the envelope it was stored in.
///
/// A recorded output is `{"output": "...", "metadata": {"exit_code": 0,
/// "duration_seconds": 0.2}}`. Showing it verbatim buries a directory listing
/// inside a JSON string complete with its escaped newlines — and reading only
/// the text threw away the two facts that say how the command went, so a
/// failure reopened as something indistinguishable from a success.
///
/// Anything that is not that shape is passed through unchanged, since a tool
/// returning plain text is returning plain text.
fn unwrap_output(raw: &str) -> RecordedOutput {
    let Ok(value) = serde_json::from_str::<serde_json::Value>(raw) else {
        return RecordedOutput {
            text: raw.to_string(),
            exit_code: None,
            duration_ms: None,
        };
    };
    let Some(text) = value.get("output").and_then(serde_json::Value::as_str) else {
        return RecordedOutput {
            text: raw.to_string(),
            exit_code: None,
            duration_ms: None,
        };
    };

    let metadata = value.get("metadata");
    RecordedOutput {
        text: text.to_string(),
        exit_code: metadata
            .and_then(|m| m.get("exit_code"))
            .and_then(serde_json::Value::as_i64)
            .and_then(|code| i32::try_from(code).ok()),
        duration_ms: metadata
            .and_then(|m| m.get("duration_seconds"))
            .and_then(serde_json::Value::as_f64)
            .map(|seconds| (seconds * 1000.0).round() as i64),
    }
}

/// Flatten a recorded reasoning item into the text a reader sees.
///
/// A summary is a list of separate points and is joined with blank lines
/// between them. `content` is not: it is one piece of thinking recorded in the
/// fragments it streamed as, so joining those with blank lines put every word
/// on a line of its own — "The\n\n user\n\n is\n\n saying".
fn reasoning_text(
    summary: &[opencli_protocol::models::ReasoningItemReasoningSummary],
    content: Option<&[opencli_protocol::models::ReasoningItemContent]>,
) -> String {
    let points: Vec<&str> = summary
        .iter()
        .map(|entry| match entry {
            opencli_protocol::models::ReasoningItemReasoningSummary::SummaryText { text } => {
                text.as_str()
            }
        })
        .filter(|text| !text.trim().is_empty())
        .collect();

    let body: String = content
        .unwrap_or_default()
        .iter()
        .map(|entry| match entry {
            opencli_protocol::models::ReasoningItemContent::ReasoningText { text }
            | opencli_protocol::models::ReasoningItemContent::Text { text } => text.as_str(),
        })
        .collect();

    let mut whole = points.join("\n\n");
    if !body.trim().is_empty() {
        if !whole.is_empty() {
            whole.push_str("\n\n");
        }
        whole.push_str(body.trim_end());
    }
    whole
}

/// Convert persisted [`EventMsg`] entries into a sequence of [`Turn`] values.
///
/// The purpose of this is to convert the EventMsgs persisted in a rollout file
/// into a sequence of Turns and ThreadItems, which allows the client to render
/// the historical messages when resuming a thread.
pub fn build_turns_from_event_msgs(events: &[EventMsg]) -> Vec<Turn> {
    let mut builder = ThreadHistoryBuilder::new();
    for event in events {
        builder.handle_event(event);
    }
    builder.finish()
}

/// Convert a whole rollout — events *and* response items — into turns.
///
/// A reopened conversation showed only the messages, never the commands the
/// agent ran or what it thought, because those are not persisted as events at
/// all. They are `ResponseItem`s, and a reader that kept only `EventMsg`
/// discarded every one of them: across the sessions this was found on, 1,302
/// calls, 1,300 outputs and 422 pieces of reasoning, all present on disk and
/// none of them reaching the screen.
/// What a rollout says the conversation cost, if it says anything.
///
/// The last figure recorded wins: each is the running total at that moment,
/// so the newest is the total for the whole conversation.
pub fn token_usage_from_rollout(lines: &[RolloutLine]) -> Option<ThreadTokenUsage> {
    lines.iter().rev().find_map(|line| match &line.item {
        RolloutItem::EventMsg(EventMsg::TokenCount(event)) => {
            event.info.clone().map(ThreadTokenUsage::from)
        }
        _ => None,
    })
}

pub fn build_turns_from_rollout(lines: &[RolloutLine]) -> Vec<Turn> {
    let mut builder = ThreadHistoryBuilder::new();
    let mut previous: Option<&str> = None;

    for line in lines {
        match &line.item {
            RolloutItem::EventMsg(event) => builder.handle_event(event),
            RolloutItem::ResponseItem(response) => {
                // How long a thought took is not recorded anywhere, but when it
                // finished is: a reasoning record is written on completion, so
                // the gap back to whatever preceded it is the time the model
                // spent producing it. Approximate — it includes the request's
                // own latency — and the only measurement there is.
                builder.thought_took = matches!(response, ResponseItem::Reasoning { .. })
                    .then(|| gap_ms(previous, &line.timestamp))
                    .flatten();
                builder.handle_response_item(response);
            }
            _ => {}
        }
        previous = Some(&line.timestamp);
    }
    builder.finish()
}

/// Milliseconds between two recorded moments, when both can be read.
fn gap_ms(from: Option<&str>, to: &str) -> Option<i64> {
    let from = chrono::DateTime::parse_from_rfc3339(from?).ok()?;
    let to = chrono::DateTime::parse_from_rfc3339(to).ok()?;
    let gap = (to - from).num_milliseconds();
    (gap >= 0).then_some(gap)
}

struct ThreadHistoryBuilder {
    turns: Vec<Turn>,
    current_turn: Option<PendingTurn>,
    next_turn_index: i64,
    next_item_index: i64,
    /// Calls whose output has not been seen yet, oldest first.
    open_calls: Vec<String>,
    /// How long the reasoning item being read took, when it can be worked out.
    thought_took: Option<i64>,
}

impl ThreadHistoryBuilder {
    fn new() -> Self {
        Self {
            turns: Vec::new(),
            current_turn: None,
            next_turn_index: 1,
            next_item_index: 1,
            open_calls: Vec::new(),
            thought_took: None,
        }
    }

    fn finish(mut self) -> Vec<Turn> {
        self.finish_current_turn();
        self.turns
    }

    /// This function should handle all EventMsg variants that can be persisted in a rollout file.
    /// See `should_persist_event_msg` in `opencli-rs/core/rollout/policy.rs`.
    fn handle_event(&mut self, event: &EventMsg) {
        match event {
            EventMsg::UserMessage(payload) => self.handle_user_message(payload),
            EventMsg::AgentMessage(payload) => self.handle_agent_message(payload.message.clone()),
            EventMsg::AgentReasoning(payload) => self.handle_agent_reasoning(payload),
            EventMsg::AgentReasoningRawContent(payload) => {
                self.handle_agent_reasoning_raw_content(payload)
            }
            EventMsg::ItemCompleted(payload) => self.handle_item_completed(payload),
            EventMsg::TokenCount(_) => {}
            EventMsg::EnteredReviewMode(_) => {}
            EventMsg::ExitedReviewMode(_) => {}
            EventMsg::ThreadRolledBack(payload) => self.handle_thread_rollback(payload),
            EventMsg::UndoCompleted(_) => {}
            EventMsg::ContextCompacted(_) => self.handle_context_compacted(),
            EventMsg::TurnAborted(payload) => self.handle_turn_aborted(payload),
            _ => {}
        }
    }

    fn handle_user_message(&mut self, payload: &UserMessageEvent) {
        self.finish_current_turn();
        let mut turn = self.new_turn();
        let id = self.next_item_id();
        let content = self.build_user_inputs(payload);
        turn.items.push(ThreadItem::UserMessage { id, content });
        self.current_turn = Some(turn);
    }

    fn handle_agent_message(&mut self, text: String) {
        if text.is_empty() {
            return;
        }

        let id = self.next_item_id();
        self.ensure_turn()
            .items
            .push(ThreadItem::AgentMessage { id, text });
    }

    fn handle_agent_reasoning(&mut self, payload: &AgentReasoningEvent) {
        if payload.text.is_empty() {
            return;
        }

        // If the last item is a reasoning item, add the new text to the summary.
        if let Some(ThreadItem::Reasoning { summary, .. }) = self.ensure_turn().items.last_mut() {
            summary.push(payload.text.clone());
            return;
        }

        // Otherwise, create a new reasoning item.
        let id = self.next_item_id();
        self.ensure_turn().items.push(ThreadItem::Reasoning {
            id,
            summary: vec![payload.text.clone()],
            content: Vec::new(),
            // A live thought is timed by the client, which sees it start.
            duration_ms: None,
        });
    }

    fn handle_agent_reasoning_raw_content(&mut self, payload: &AgentReasoningRawContentEvent) {
        if payload.text.is_empty() {
            return;
        }

        // If the last item is a reasoning item, add the new text to the content.
        if let Some(ThreadItem::Reasoning { content, .. }) = self.ensure_turn().items.last_mut() {
            content.push(payload.text.clone());
            return;
        }

        // Otherwise, create a new reasoning item.
        let id = self.next_item_id();
        self.ensure_turn().items.push(ThreadItem::Reasoning {
            id,
            summary: Vec::new(),
            content: vec![payload.text.clone()],
            duration_ms: None,
        });
    }

    fn handle_item_completed(&mut self, payload: &ItemCompletedEvent) {
        if let opencli_protocol::items::TurnItem::Plan(plan) = &payload.item {
            if plan.text.is_empty() {
                return;
            }
            let id = self.next_item_id();
            self.ensure_turn().items.push(ThreadItem::Plan {
                id,
                text: plan.text.clone(),
            });
        }
    }

    /// A recorded response item: what the agent called, what came back, and
    /// what it was thinking.
    ///
    /// Only the shapes a reader can do something with. A call whose output has
    /// not been seen yet is shown as still running, which is what it was when
    /// the conversation ended if it ended there.
    fn handle_response_item(&mut self, item: &ResponseItem) {
        match item {
            ResponseItem::FunctionCall {
                name,
                arguments,
                call_id,
                ..
            } => self.handle_function_call(name, arguments, call_id),
            ResponseItem::FunctionCallOutput { call_id, output } => {
                self.attach_output(call_id, &output.content);
            }
            ResponseItem::Reasoning {
                summary, content, ..
            } => {
                let text = reasoning_text(summary, content.as_deref());
                if !text.is_empty() {
                    let id = self.next_item_id();
                    let took = self.thought_took.take();
                    self.ensure_turn().items.push(ThreadItem::Reasoning {
                        id,
                        summary: Vec::new(),
                        content: vec![text],
                        duration_ms: took,
                    });
                }
            }
            _ => {}
        }
    }

    /// Turn a recorded tool call into the item a reader sees.
    ///
    /// Whether it is a command is decided by its **shape**, not its name. This
    /// build calls the shell `run`, `local_shell` or `run_command` depending on
    /// configuration, and a list of names written from memory got two of the
    /// three wrong — every command in an old conversation was then filed as an
    /// unknown tool and shown without the command in it. Arguments carrying a
    /// `command` is the thing that actually makes it one.
    fn handle_function_call(&mut self, name: &str, arguments: &str, call_id: &str) {
        let parsed: Option<serde_json::Value> = serde_json::from_str(arguments).ok();

        {
            let command = parsed
                .as_ref()
                .and_then(|value| value.get("command"))
                .map(|value| match value {
                    serde_json::Value::Array(parts) => parts
                        .iter()
                        .filter_map(serde_json::Value::as_str)
                        .collect::<Vec<_>>()
                        .join(" "),
                    other => other.as_str().unwrap_or_default().to_string(),
                })
                .unwrap_or_default();
            if !command.is_empty() {
                let description = parsed
                    .as_ref()
                    .and_then(|value| value.get("description"))
                    .and_then(serde_json::Value::as_str)
                    .map(str::to_string);

                self.open_calls.push(call_id.to_string());
                let id = self.next_item_id();
                self.ensure_turn().items.push(ThreadItem::CommandExecution {
                    id,
                    command,
                    cwd: std::path::PathBuf::new(),
                    process_id: None,
                    status: CommandExecutionStatus::Completed,
                    command_actions: Vec::new(),
                    description,
                    aggregated_output: None,
                    exit_code: None,
                    duration_ms: None,
                });
                return;
            }
        }

        self.open_calls.push(call_id.to_string());
        let id = self.next_item_id();
        self.ensure_turn().items.push(ThreadItem::McpToolCall {
            id,
            server: String::new(),
            tool: name.to_string(),
            status: McpToolCallStatus::Completed,
            arguments: parsed.unwrap_or(serde_json::Value::Null),
            result: None,
            error: None,
            duration_ms: None,
        });
    }

    /// Put a tool's output on the call it belongs to.
    ///
    /// Matched by position rather than by id, because the recorded item does
    /// not carry the id the reader gave it. Calls and their outputs are
    /// recorded in order, so the **oldest** unanswered call is the right one —
    /// searching from the newest end gave every command the next one's output.
    fn attach_output(&mut self, call_id: &str, output: &str) {
        let Some(at) = self.open_calls.iter().position(|open| open == call_id) else {
            return;
        };
        self.open_calls.remove(at);

        let Some(turn) = self.current_turn.as_mut() else {
            return;
        };
        let opened = unwrap_output(output);

        for item in turn.items.iter_mut() {
            match item {
                ThreadItem::CommandExecution {
                    aggregated_output,
                    exit_code,
                    duration_ms,
                    status,
                    ..
                } if aggregated_output.is_none() => {
                    // A failure reopened as a success until these were read.
                    *status = if opened.exit_code.unwrap_or(0) == 0 {
                        CommandExecutionStatus::Completed
                    } else {
                        CommandExecutionStatus::Failed
                    };
                    *exit_code = opened.exit_code;
                    *duration_ms = opened.duration_ms;
                    *aggregated_output = Some(opened.text);
                    return;
                }
                // A tool that is not a command has an answer too. Attaching it
                // only to commands left `open_file` and the rest with nothing
                // under them.
                ThreadItem::McpToolCall { result, .. } if result.is_none() => {
                    *result = Some(McpToolCallResult {
                        content: vec![mcp_types::ContentBlock::TextContent(
                            mcp_types::TextContent {
                                r#type: "text".to_string(),
                                text: opened.text,
                                annotations: None,
                            },
                        )],
                        structured_content: None,
                    });
                    return;
                }
                _ => {}
            }
        }
    }

    /// Say that the conversation was compacted here.
    ///
    /// Compaction replaces the earlier exchange with a summary. Without a
    /// marker, reopening one looks like the beginning of the conversation
    /// simply went missing — a reader has no way to tell a lost transcript
    /// from a summarised one, and assumes the worse of the two.
    fn handle_context_compacted(&mut self) {
        let id = self.next_item_id();
        self.ensure_turn().items.push(ThreadItem::AgentMessage {
            id,
            text: COMPACTION_NOTICE.to_string(),
        });
    }

    fn handle_turn_aborted(&mut self, _payload: &TurnAbortedEvent) {
        let Some(turn) = self.current_turn.as_mut() else {
            return;
        };
        turn.status = TurnStatus::Interrupted;
    }

    fn handle_thread_rollback(&mut self, payload: &ThreadRolledBackEvent) {
        self.finish_current_turn();

        let n = usize::try_from(payload.num_turns).unwrap_or(usize::MAX);
        if n >= self.turns.len() {
            self.turns.clear();
        } else {
            self.turns.truncate(self.turns.len().saturating_sub(n));
        }

        // Re-number subsequent synthetic ids so the pruned history is consistent.
        self.next_turn_index =
            i64::try_from(self.turns.len().saturating_add(1)).unwrap_or(i64::MAX);
        let item_count: usize = self.turns.iter().map(|t| t.items.len()).sum();
        self.next_item_index = i64::try_from(item_count.saturating_add(1)).unwrap_or(i64::MAX);
    }

    fn finish_current_turn(&mut self) {
        if let Some(turn) = self.current_turn.take() {
            if turn.items.is_empty() {
                return;
            }
            self.turns.push(turn.into());
        }
    }

    fn new_turn(&mut self) -> PendingTurn {
        PendingTurn {
            id: self.next_turn_id(),
            items: Vec::new(),
            error: None,
            status: TurnStatus::Completed,
        }
    }

    fn ensure_turn(&mut self) -> &mut PendingTurn {
        if self.current_turn.is_none() {
            let turn = self.new_turn();
            return self.current_turn.insert(turn);
        }

        if let Some(turn) = self.current_turn.as_mut() {
            return turn;
        }

        unreachable!("current turn must exist after initialization");
    }

    fn next_turn_id(&mut self) -> String {
        let id = format!("turn-{}", self.next_turn_index);
        self.next_turn_index += 1;
        id
    }

    fn next_item_id(&mut self) -> String {
        let id = format!("item-{}", self.next_item_index);
        self.next_item_index += 1;
        id
    }

    fn build_user_inputs(&self, payload: &UserMessageEvent) -> Vec<UserInput> {
        let mut content = Vec::new();
        if !payload.message.trim().is_empty() {
            content.push(UserInput::Text {
                text: payload.message.clone(),
                text_elements: payload
                    .text_elements
                    .iter()
                    .cloned()
                    .map(Into::into)
                    .collect(),
            });
        }
        if let Some(images) = &payload.images {
            for image in images {
                content.push(UserInput::Image { url: image.clone() });
            }
        }
        for path in &payload.local_images {
            content.push(UserInput::LocalImage { path: path.clone() });
        }
        content
    }
}

struct PendingTurn {
    id: String,
    items: Vec<ThreadItem>,
    error: Option<TurnError>,
    status: TurnStatus,
}

impl From<PendingTurn> for Turn {
    fn from(value: PendingTurn) -> Self {
        Self {
            id: value.id,
            items: value.items,
            error: value.error,
            status: value.status,
        }
    }
}

#[cfg(test)]
mod tests {

    /// Records, as a rollout file holds them: an item and when it was written.
    ///
    /// A second apart, because the gap between two records is what a restored
    /// thought's duration is measured from.
    fn recorded(items: Vec<RolloutItem>) -> Vec<RolloutLine> {
        items
            .into_iter()
            .enumerate()
            .map(|(at, item)| RolloutLine {
                timestamp: format!("2026-09-01T09:28:{:02}.000Z", at),
                item,
            })
            .collect()
    }

    #[test]
    fn should_show_the_commands_a_reopened_conversation_ran() {
        // These are recorded as ResponseItems, not events. A reader that kept
        // only events discarded every one of them, so reopening a chat showed
        // the messages and nothing the agent had actually done.
        use opencli_protocol::models::FunctionCallOutputPayload;

        let items = vec![
            RolloutItem::EventMsg(EventMsg::UserMessage(UserMessageEvent {
                message: "run the tests".to_string(),
                images: None,
                local_images: Vec::new(),
                text_elements: Vec::new(),
            })),
            RolloutItem::ResponseItem(ResponseItem::FunctionCall {
                id: None,
                name: "shell".to_string(),
                arguments: r#"{"command":["bash","-lc","cargo test"],"description":"Run the tests"}"#
                    .to_string(),
                call_id: "call-1".to_string(),
            }),
            RolloutItem::ResponseItem(ResponseItem::FunctionCallOutput {
                call_id: "call-1".to_string(),
                output: FunctionCallOutputPayload {
                    content: "test result: ok. 1022 passed".to_string(),
                    content_items: None,
                    success: Some(true),
                },
            }),
        ];

        let turns = build_turns_from_rollout(&recorded(items.clone()));
        let found = turns
            .iter()
            .flat_map(|turn| turn.items.iter())
            .find_map(|item| match item {
                ThreadItem::CommandExecution {
                    command,
                    description,
                    aggregated_output,
                    ..
                } => Some((command.clone(), description.clone(), aggregated_output.clone())),
                _ => None,
            })
            .expect("the command is in the history");

        assert_eq!(found.0, "bash -lc cargo test");
        assert_eq!(found.1.as_deref(), Some("Run the tests"));
        assert_eq!(found.2.as_deref(), Some("test result: ok. 1022 passed"));
    }

    #[test]
    fn should_show_what_it_was_thinking() {
        use opencli_protocol::models::ReasoningItemContent;

        let items = vec![RolloutItem::ResponseItem(ResponseItem::Reasoning {
            id: String::new(),
            summary: Vec::new(),
            content: Some(vec![ReasoningItemContent::ReasoningText {
                text: "The uptime is the evidence.".to_string(),
            }]),
            encrypted_content: None,
        })];

        let turns = build_turns_from_rollout(&recorded(items.clone()));
        let thought = turns
            .iter()
            .flat_map(|turn| turn.items.iter())
            .find_map(|item| match item {
                ThreadItem::Reasoning { content, .. } => Some(content.join("")),
                _ => None,
            });
        assert_eq!(thought.as_deref(), Some("The uptime is the evidence."));
    }

    #[test]
    fn should_leave_a_call_that_never_answered_without_output() {
        // A conversation that ended mid-command is a real thing on disk; it
        // must not borrow the next command's output.
        let items = vec![RolloutItem::ResponseItem(ResponseItem::FunctionCall {
            id: None,
            name: "shell".to_string(),
            arguments: r#"{"command":["sleep","600"]}"#.to_string(),
            call_id: "call-1".to_string(),
        })];

        let turns = build_turns_from_rollout(&recorded(items.clone()));
        let output = turns
            .iter()
            .flat_map(|turn| turn.items.iter())
            .find_map(|item| match item {
                ThreadItem::CommandExecution {
                    aggregated_output, ..
                } => Some(aggregated_output.clone()),
                _ => None,
            });
        assert_eq!(output, Some(None));
    }

    #[test]
    fn should_say_how_long_a_reopened_thought_took() {
        // Nothing records a thought's duration, so a reopened conversation
        // showed no time against thinking at all. The record's own timestamp,
        // against the one before it, is how long the model was busy.
        use opencli_protocol::models::ReasoningItemContent;

        let lines = vec![
            RolloutLine {
                timestamp: "2026-09-01T09:28:38.500Z".to_string(),
                item: RolloutItem::EventMsg(EventMsg::UserMessage(UserMessageEvent {
                    message: "hello".to_string(),
                    images: None,
                    local_images: Vec::new(),
                    text_elements: Vec::new(),
                })),
            },
            RolloutLine {
                timestamp: "2026-09-01T09:28:45.900Z".to_string(),
                item: RolloutItem::ResponseItem(ResponseItem::Reasoning {
                    id: String::new(),
                    summary: Vec::new(),
                    content: Some(vec![ReasoningItemContent::ReasoningText {
                        text: "Thinking it over.".to_string(),
                    }]),
                    encrypted_content: None,
                }),
            },
        ];

        let took = build_turns_from_rollout(&lines)
            .iter()
            .flat_map(|turn| turn.items.iter())
            .find_map(|item| match item {
                ThreadItem::Reasoning { duration_ms, .. } => Some(*duration_ms),
                _ => None,
            });
        assert_eq!(took, Some(Some(7_400)));
    }

    #[test]
    fn should_leave_a_thought_untimed_when_nothing_came_before_it() {
        // The first record in a file has no gap to measure, and a made-up
        // duration reads as fact. Better to say nothing.
        use opencli_protocol::models::ReasoningItemContent;

        let lines = vec![RolloutLine {
            timestamp: "2026-09-01T09:28:38.500Z".to_string(),
            item: RolloutItem::ResponseItem(ResponseItem::Reasoning {
                id: String::new(),
                summary: Vec::new(),
                content: Some(vec![ReasoningItemContent::ReasoningText {
                    text: "First thing.".to_string(),
                }]),
                encrypted_content: None,
            }),
        }];

        let took = build_turns_from_rollout(&lines)
            .iter()
            .flat_map(|turn| turn.items.iter())
            .find_map(|item| match item {
                ThreadItem::Reasoning { duration_ms, .. } => Some(*duration_ms),
                _ => None,
            });
        assert_eq!(took, Some(None));
    }

    #[test]
    fn should_join_the_fragments_thinking_streamed_as() {
        // `content` is one piece of thinking recorded in the pieces it arrived
        // in. Joining those with blank lines put every word on its own line.
        use opencli_protocol::models::ReasoningItemContent;

        let items = vec![RolloutItem::ResponseItem(ResponseItem::Reasoning {
            id: String::new(),
            summary: Vec::new(),
            content: Some(
                ["The", " user", " is", " saying"]
                    .into_iter()
                    .map(|text| ReasoningItemContent::ReasoningText {
                        text: text.to_string(),
                    })
                    .collect(),
            ),
            encrypted_content: None,
        })];

        let thought = build_turns_from_rollout(&recorded(items.clone()))
            .iter()
            .flat_map(|turn| turn.items.iter())
            .find_map(|item| match item {
                ThreadItem::Reasoning { content, .. } => Some(content.join("")),
                _ => None,
            });
        assert_eq!(thought.as_deref(), Some("The user is saying"));
    }

    #[test]
    fn should_keep_separate_summary_points_apart() {
        // A summary is a list of points, not fragments of one.
        use opencli_protocol::models::ReasoningItemReasoningSummary;

        let items = vec![RolloutItem::ResponseItem(ResponseItem::Reasoning {
            id: String::new(),
            summary: vec![
                ReasoningItemReasoningSummary::SummaryText {
                    text: "First point.".to_string(),
                },
                ReasoningItemReasoningSummary::SummaryText {
                    text: "Second point.".to_string(),
                },
            ],
            content: None,
            encrypted_content: None,
        })];

        let thought = build_turns_from_rollout(&recorded(items.clone()))
            .iter()
            .flat_map(|turn| turn.items.iter())
            .find_map(|item| match item {
                ThreadItem::Reasoning { content, .. } => Some(content.join("")),
                _ => None,
            });
        assert_eq!(thought.as_deref(), Some("First point.\n\nSecond point."));
    }

    #[test]
    fn should_give_each_command_its_own_output() {
        // Searching from the newest end gave every command the *next* one's
        // output, which is worse than none: it reads as fact.
        use opencli_protocol::models::FunctionCallOutputPayload;

        let call = |id: &str, cmd: &str| {
            RolloutItem::ResponseItem(ResponseItem::FunctionCall {
                id: None,
                name: "run".to_string(),
                arguments: format!(r#"{{"command":["bash","-lc","{cmd}"]}}"#),
                call_id: id.to_string(),
            })
        };
        let output = |id: &str, text: &str| {
            RolloutItem::ResponseItem(ResponseItem::FunctionCallOutput {
                call_id: id.to_string(),
                output: FunctionCallOutputPayload {
                    content: format!(r#"{{"output":"{text}"}}"#),
                    content_items: None,
                    success: Some(true),
                },
            })
        };

        let turns = build_turns_from_rollout(&recorded(vec![
            call("a", "ls"),
            output("a", "first"),
            call("b", "pwd"),
            output("b", "second"),
        ]));

        let paired: Vec<(String, Option<String>)> = turns
            .iter()
            .flat_map(|turn| turn.items.iter())
            .filter_map(|item| match item {
                ThreadItem::CommandExecution {
                    command,
                    aggregated_output,
                    ..
                } => Some((command.clone(), aggregated_output.clone())),
                _ => None,
            })
            .collect();

        assert_eq!(
            paired,
            vec![
                ("bash -lc ls".to_string(), Some("first".to_string())),
                ("bash -lc pwd".to_string(), Some("second".to_string())),
            ]
        );
    }

    #[test]
    fn should_show_what_a_command_printed_not_the_envelope_around_it() {
        // Stored as `{"output": "...", "metadata": {...}}`. Shown verbatim, a
        // directory listing arrives inside a JSON string, escapes and all.
        let opened =
            unwrap_output(r#"{"output":"total 8\ndrwxr-xr-x","metadata":{"exit_code":0,"duration_seconds":0.2}}"#);
        assert_eq!(opened.text, "total 8\ndrwxr-xr-x");
        assert_eq!(opened.exit_code, Some(0));
        assert_eq!(opened.duration_ms, Some(200));

        // A tool that returns plain text is returning plain text.
        assert_eq!(unwrap_output("just text").text, "just text");
        assert_eq!(unwrap_output(r#"{"other":"shape"}"#).text, r#"{"other":"shape"}"#);
    }

    #[test]
    fn should_say_where_a_conversation_was_compacted() {
        // Without this, reopening a compacted chat looks like the beginning
        // simply went missing, and a reader assumes the transcript was lost.
        use opencli_protocol::protocol::ContextCompactedEvent;

        let turns = build_turns_from_rollout(&recorded(vec![
            RolloutItem::EventMsg(EventMsg::AgentMessage(
                opencli_protocol::protocol::AgentMessageEvent {
                    message: "before".to_string(),
                },
            )),
            RolloutItem::EventMsg(EventMsg::ContextCompacted(ContextCompactedEvent)),
        ]));

        let said: Vec<String> = turns
            .iter()
            .flat_map(|turn| turn.items.iter())
            .filter_map(|item| match item {
                ThreadItem::AgentMessage { text, .. } => Some(text.clone()),
                _ => None,
            })
            .collect();

        assert_eq!(said.len(), 2);
        assert!(said[1].contains("summarised"), "got: {}", said[1]);
        assert!(said[1].contains("still on disk"), "got: {}", said[1]);
    }

    #[test]
    fn should_report_what_a_reopened_conversation_cost() {
        // The figure is recorded on every turn and none of it was read back,
        // so a chat that had spent a hundred thousand tokens reopened
        // reporting nothing at all.
        use opencli_protocol::protocol::TokenCountEvent;
        use opencli_protocol::protocol::TokenUsage as CoreTokenUsage;
        use opencli_protocol::protocol::TokenUsageInfo;

        let usage = |total: i64| {
            RolloutItem::EventMsg(EventMsg::TokenCount(TokenCountEvent {
                info: Some(TokenUsageInfo {
                    total_token_usage: CoreTokenUsage {
                        input_tokens: 0,
                        cached_input_tokens: 0,
                        output_tokens: 0,
                        reasoning_output_tokens: 0,
                        total_tokens: total,
                    },
                    last_token_usage: CoreTokenUsage {
                        input_tokens: 0,
                        cached_input_tokens: 0,
                        output_tokens: 0,
                        reasoning_output_tokens: 0,
                        total_tokens: 10,
                    },
                    model_context_window: Some(32768),
                }),
                rate_limits: None,
            }))
        };

        // Each figure is the running total at that moment, so the last wins.
        let found = token_usage_from_rollout(&recorded(vec![usage(500), usage(101_420)])).expect("a total");
        assert_eq!(found.total.total_tokens, 101_420);
        assert_eq!(found.model_context_window, Some(32768));

        assert!(token_usage_from_rollout(&recorded(vec![])).is_none());
    }

    #[test]
    fn should_remember_that_a_command_failed() {
        // Reopened, a failure was indistinguishable from a success: the exit
        // code and the timing sit in the output's metadata and were dropped.
        use opencli_protocol::models::FunctionCallOutputPayload;

        let turns = build_turns_from_rollout(&recorded(vec![
            RolloutItem::ResponseItem(ResponseItem::FunctionCall {
                id: None,
                name: "run".to_string(),
                arguments: r#"{"command":["bash","-lc","exit 2"]}"#.to_string(),
                call_id: "call-1".to_string(),
            }),
            RolloutItem::ResponseItem(ResponseItem::FunctionCallOutput {
                call_id: "call-1".to_string(),
                output: FunctionCallOutputPayload {
                    content: r#"{"output":"boom","metadata":{"exit_code":2,"duration_seconds":1.5}}"#
                        .to_string(),
                    content_items: None,
                    success: Some(false),
                },
            }),
        ]));

        let found = turns
            .iter()
            .flat_map(|turn| turn.items.iter())
            .find_map(|item| match item {
                ThreadItem::CommandExecution {
                    status,
                    exit_code,
                    duration_ms,
                    ..
                } => Some((status.clone(), *exit_code, *duration_ms)),
                _ => None,
            })
            .expect("the command is there");

        assert_eq!(found.0, CommandExecutionStatus::Failed);
        assert_eq!(found.1, Some(2));
        assert_eq!(found.2, Some(1500));
    }

    #[test]
    fn should_keep_the_answer_a_tool_that_is_not_a_command_gave() {
        // Attaching output only to commands left `open_file` and the rest
        // with nothing under them.
        use opencli_protocol::models::FunctionCallOutputPayload;

        let turns = build_turns_from_rollout(&recorded(vec![
            RolloutItem::ResponseItem(ResponseItem::FunctionCall {
                id: None,
                name: "open_file".to_string(),
                arguments: r#"{"path":"src/main.rs"}"#.to_string(),
                call_id: "call-1".to_string(),
            }),
            RolloutItem::ResponseItem(ResponseItem::FunctionCallOutput {
                call_id: "call-1".to_string(),
                output: FunctionCallOutputPayload {
                    content: r#"{"output":"fn main() {}"}"#.to_string(),
                    content_items: None,
                    success: Some(true),
                },
            }),
        ]));

        let answered = turns
            .iter()
            .flat_map(|turn| turn.items.iter())
            .find_map(|item| match item {
                ThreadItem::McpToolCall { result, .. } => result.clone(),
                _ => None,
            })
            .expect("the tool's answer is kept");
        assert_eq!(answered.content.len(), 1);
    }

    #[test]
    fn should_recognise_a_command_whatever_the_shell_tool_is_called() {
        // This build names it `run`, `local_shell` or `run_command` depending
        // on configuration. A list of names written from memory got two of the
        // three wrong, and every command in an old conversation was then filed
        // as an unknown tool with no command in it.
        for name in ["run", "local_shell", "run_command", "shell", "something_new"] {
            let items = vec![RolloutItem::ResponseItem(ResponseItem::FunctionCall {
                id: None,
                name: name.to_string(),
                arguments: r#"{"command":["bash","-lc","ls"],"workdir":"/"}"#.to_string(),
                call_id: "call-1".to_string(),
            })];

            let found = build_turns_from_rollout(&recorded(items.clone()))
                .iter()
                .flat_map(|turn| turn.items.iter())
                .find_map(|item| match item {
                    ThreadItem::CommandExecution { command, .. } => Some(command.clone()),
                    _ => None,
                });
            assert_eq!(found.as_deref(), Some("bash -lc ls"), "tool named `{name}`");
        }
    }

    #[test]
    fn should_still_file_a_real_tool_call_as_one() {
        // Deciding by shape must not swallow tool calls that are not commands.
        let items = vec![RolloutItem::ResponseItem(ResponseItem::FunctionCall {
            id: None,
            name: "get_design_context".to_string(),
            arguments: r#"{"node":"12:34"}"#.to_string(),
            call_id: "call-1".to_string(),
        })];

        let tool = build_turns_from_rollout(&recorded(items.clone()))
            .iter()
            .flat_map(|turn| turn.items.iter())
            .find_map(|item| match item {
                ThreadItem::McpToolCall { tool, .. } => Some(tool.clone()),
                _ => None,
            });
        assert_eq!(tool.as_deref(), Some("get_design_context"));
    }

    #[test]
    fn should_still_report_a_call_whose_arguments_cannot_be_read() {
        // Deciding by shape means an unreadable call cannot be identified as a
        // command — but something did run, and saying so by name beats
        // pretending the conversation never touched a tool.
        let items = vec![RolloutItem::ResponseItem(ResponseItem::FunctionCall {
            id: None,
            name: "run".to_string(),
            arguments: "not json".to_string(),
            call_id: "call-1".to_string(),
        })];

        let tool = build_turns_from_rollout(&recorded(items.clone()))
            .iter()
            .flat_map(|turn| turn.items.iter())
            .find_map(|item| match item {
                ThreadItem::McpToolCall { tool, .. } => Some(tool.clone()),
                _ => None,
            });
        assert_eq!(tool.as_deref(), Some("run"));
    }
    use super::*;
    use opencli_protocol::protocol::AgentMessageEvent;
    use opencli_protocol::protocol::AgentReasoningEvent;
    use opencli_protocol::protocol::AgentReasoningRawContentEvent;
    use opencli_protocol::protocol::ThreadRolledBackEvent;
    use opencli_protocol::protocol::TurnAbortReason;
    use opencli_protocol::protocol::TurnAbortedEvent;
    use opencli_protocol::protocol::UserMessageEvent;
    use pretty_assertions::assert_eq;

    #[test]
    fn builds_multiple_turns_with_reasoning_items() {
        let events = vec![
            EventMsg::UserMessage(UserMessageEvent {
                message: "First turn".into(),
                images: Some(vec!["https://example.com/one.png".into()]),
                text_elements: Vec::new(),
                local_images: Vec::new(),
            }),
            EventMsg::AgentMessage(AgentMessageEvent {
                message: "Hi there".into(),
            }),
            EventMsg::AgentReasoning(AgentReasoningEvent {
                text: "thinking".into(),
            }),
            EventMsg::AgentReasoningRawContent(AgentReasoningRawContentEvent {
                text: "full reasoning".into(),
            }),
            EventMsg::UserMessage(UserMessageEvent {
                message: "Second turn".into(),
                images: None,
                text_elements: Vec::new(),
                local_images: Vec::new(),
            }),
            EventMsg::AgentMessage(AgentMessageEvent {
                message: "Reply two".into(),
            }),
        ];

        let turns = build_turns_from_event_msgs(&events);
        assert_eq!(turns.len(), 2);

        let first = &turns[0];
        assert_eq!(first.id, "turn-1");
        assert_eq!(first.status, TurnStatus::Completed);
        assert_eq!(first.items.len(), 3);
        assert_eq!(
            first.items[0],
            ThreadItem::UserMessage {
                id: "item-1".into(),
                content: vec![
                    UserInput::Text {
                        text: "First turn".into(),
                        text_elements: Vec::new(),
                    },
                    UserInput::Image {
                        url: "https://example.com/one.png".into(),
                    }
                ],
            }
        );
        assert_eq!(
            first.items[1],
            ThreadItem::AgentMessage {
                id: "item-2".into(),
                text: "Hi there".into(),
            }
        );
        assert_eq!(
            first.items[2],
            ThreadItem::Reasoning {
                id: "item-3".into(),
                summary: vec!["thinking".into()],
                content: vec!["full reasoning".into()],
                duration_ms: None,
            }
        );

        let second = &turns[1];
        assert_eq!(second.id, "turn-2");
        assert_eq!(second.items.len(), 2);
        assert_eq!(
            second.items[0],
            ThreadItem::UserMessage {
                id: "item-4".into(),
                content: vec![UserInput::Text {
                    text: "Second turn".into(),
                    text_elements: Vec::new(),
                }],
            }
        );
        assert_eq!(
            second.items[1],
            ThreadItem::AgentMessage {
                id: "item-5".into(),
                text: "Reply two".into(),
            }
        );
    }

    #[test]
    fn splits_reasoning_when_interleaved() {
        let events = vec![
            EventMsg::UserMessage(UserMessageEvent {
                message: "Turn start".into(),
                images: None,
                text_elements: Vec::new(),
                local_images: Vec::new(),
            }),
            EventMsg::AgentReasoning(AgentReasoningEvent {
                text: "first summary".into(),
            }),
            EventMsg::AgentReasoningRawContent(AgentReasoningRawContentEvent {
                text: "first content".into(),
            }),
            EventMsg::AgentMessage(AgentMessageEvent {
                message: "interlude".into(),
            }),
            EventMsg::AgentReasoning(AgentReasoningEvent {
                text: "second summary".into(),
            }),
        ];

        let turns = build_turns_from_event_msgs(&events);
        assert_eq!(turns.len(), 1);
        let turn = &turns[0];
        assert_eq!(turn.items.len(), 4);

        assert_eq!(
            turn.items[1],
            ThreadItem::Reasoning {
                id: "item-2".into(),
                summary: vec!["first summary".into()],
                content: vec!["first content".into()],
                duration_ms: None,
            }
        );
        assert_eq!(
            turn.items[3],
            ThreadItem::Reasoning {
                id: "item-4".into(),
                summary: vec!["second summary".into()],
                content: Vec::new(),
                duration_ms: None,
            }
        );
    }

    #[test]
    fn marks_turn_as_interrupted_when_aborted() {
        let events = vec![
            EventMsg::UserMessage(UserMessageEvent {
                message: "Please do the thing".into(),
                images: None,
                text_elements: Vec::new(),
                local_images: Vec::new(),
            }),
            EventMsg::AgentMessage(AgentMessageEvent {
                message: "Working...".into(),
            }),
            EventMsg::TurnAborted(TurnAbortedEvent {
                reason: TurnAbortReason::Replaced,
            }),
            EventMsg::UserMessage(UserMessageEvent {
                message: "Let's try again".into(),
                images: None,
                text_elements: Vec::new(),
                local_images: Vec::new(),
            }),
            EventMsg::AgentMessage(AgentMessageEvent {
                message: "Second attempt complete.".into(),
            }),
        ];

        let turns = build_turns_from_event_msgs(&events);
        assert_eq!(turns.len(), 2);

        let first_turn = &turns[0];
        assert_eq!(first_turn.status, TurnStatus::Interrupted);
        assert_eq!(first_turn.items.len(), 2);
        assert_eq!(
            first_turn.items[0],
            ThreadItem::UserMessage {
                id: "item-1".into(),
                content: vec![UserInput::Text {
                    text: "Please do the thing".into(),
                    text_elements: Vec::new(),
                }],
            }
        );
        assert_eq!(
            first_turn.items[1],
            ThreadItem::AgentMessage {
                id: "item-2".into(),
                text: "Working...".into(),
            }
        );

        let second_turn = &turns[1];
        assert_eq!(second_turn.status, TurnStatus::Completed);
        assert_eq!(second_turn.items.len(), 2);
        assert_eq!(
            second_turn.items[0],
            ThreadItem::UserMessage {
                id: "item-3".into(),
                content: vec![UserInput::Text {
                    text: "Let's try again".into(),
                    text_elements: Vec::new(),
                }],
            }
        );
        assert_eq!(
            second_turn.items[1],
            ThreadItem::AgentMessage {
                id: "item-4".into(),
                text: "Second attempt complete.".into(),
            }
        );
    }

    #[test]
    fn drops_last_turns_on_thread_rollback() {
        let events = vec![
            EventMsg::UserMessage(UserMessageEvent {
                message: "First".into(),
                images: None,
                text_elements: Vec::new(),
                local_images: Vec::new(),
            }),
            EventMsg::AgentMessage(AgentMessageEvent {
                message: "A1".into(),
            }),
            EventMsg::UserMessage(UserMessageEvent {
                message: "Second".into(),
                images: None,
                text_elements: Vec::new(),
                local_images: Vec::new(),
            }),
            EventMsg::AgentMessage(AgentMessageEvent {
                message: "A2".into(),
            }),
            EventMsg::ThreadRolledBack(ThreadRolledBackEvent { num_turns: 1 }),
            EventMsg::UserMessage(UserMessageEvent {
                message: "Third".into(),
                images: None,
                text_elements: Vec::new(),
                local_images: Vec::new(),
            }),
            EventMsg::AgentMessage(AgentMessageEvent {
                message: "A3".into(),
            }),
        ];

        let turns = build_turns_from_event_msgs(&events);
        let expected = vec![
            Turn {
                id: "turn-1".into(),
                status: TurnStatus::Completed,
                error: None,
                items: vec![
                    ThreadItem::UserMessage {
                        id: "item-1".into(),
                        content: vec![UserInput::Text {
                            text: "First".into(),
                            text_elements: Vec::new(),
                        }],
                    },
                    ThreadItem::AgentMessage {
                        id: "item-2".into(),
                        text: "A1".into(),
                    },
                ],
            },
            Turn {
                id: "turn-2".into(),
                status: TurnStatus::Completed,
                error: None,
                items: vec![
                    ThreadItem::UserMessage {
                        id: "item-3".into(),
                        content: vec![UserInput::Text {
                            text: "Third".into(),
                            text_elements: Vec::new(),
                        }],
                    },
                    ThreadItem::AgentMessage {
                        id: "item-4".into(),
                        text: "A3".into(),
                    },
                ],
            },
        ];
        assert_eq!(turns, expected);
    }

    #[test]
    fn thread_rollback_clears_all_turns_when_num_turns_exceeds_history() {
        let events = vec![
            EventMsg::UserMessage(UserMessageEvent {
                message: "One".into(),
                images: None,
                text_elements: Vec::new(),
                local_images: Vec::new(),
            }),
            EventMsg::AgentMessage(AgentMessageEvent {
                message: "A1".into(),
            }),
            EventMsg::UserMessage(UserMessageEvent {
                message: "Two".into(),
                images: None,
                text_elements: Vec::new(),
                local_images: Vec::new(),
            }),
            EventMsg::AgentMessage(AgentMessageEvent {
                message: "A2".into(),
            }),
            EventMsg::ThreadRolledBack(ThreadRolledBackEvent { num_turns: 99 }),
        ];

        let turns = build_turns_from_event_msgs(&events);
        assert_eq!(turns, Vec::<Turn>::new());
    }
}
