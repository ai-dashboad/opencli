use crate::protocol::v2::ThreadItem;
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
use crate::protocol::v2::McpToolCallStatus;
use opencli_protocol::models::ResponseItem;
use opencli_protocol::protocol::RolloutItem;

/// Flatten a recorded reasoning item into the text a reader sees.
fn reasoning_text(
    summary: &[opencli_protocol::models::ReasoningItemReasoningSummary],
    content: Option<&[opencli_protocol::models::ReasoningItemContent]>,
) -> String {
    let mut parts: Vec<&str> = summary
        .iter()
        .map(|entry| match entry {
            opencli_protocol::models::ReasoningItemReasoningSummary::SummaryText { text } => {
                text.as_str()
            }
        })
        .collect();
    if let Some(content) = content {
        parts.extend(content.iter().map(|entry| match entry {
            opencli_protocol::models::ReasoningItemContent::ReasoningText { text }
            | opencli_protocol::models::ReasoningItemContent::Text { text } => text.as_str(),
        }));
    }
    parts.retain(|part| !part.trim().is_empty());
    parts.join("\n\n")
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
pub fn build_turns_from_rollout(items: &[RolloutItem]) -> Vec<Turn> {
    let mut builder = ThreadHistoryBuilder::new();
    for item in items {
        match item {
            RolloutItem::EventMsg(event) => builder.handle_event(event),
            RolloutItem::ResponseItem(response) => builder.handle_response_item(response),
            _ => {}
        }
    }
    builder.finish()
}

struct ThreadHistoryBuilder {
    turns: Vec<Turn>,
    current_turn: Option<PendingTurn>,
    next_turn_index: i64,
    next_item_index: i64,
    /// Calls whose output has not been seen yet, oldest first.
    open_calls: Vec<String>,
}

impl ThreadHistoryBuilder {
    fn new() -> Self {
        Self {
            turns: Vec::new(),
            current_turn: None,
            next_turn_index: 1,
            next_item_index: 1,
            open_calls: Vec::new(),
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
                    self.ensure_turn().items.push(ThreadItem::Reasoning {
                        id,
                        summary: Vec::new(),
                        content: vec![text],
                    });
                }
            }
            _ => {}
        }
    }

    /// Turn a recorded tool call into the item a reader sees.
    ///
    /// The shell's arguments are a JSON string holding the command; anything
    /// else is a tool call named by the tool. A call that cannot be read is
    /// skipped rather than shown as an empty row.
    fn handle_function_call(&mut self, name: &str, arguments: &str, call_id: &str) {
        let parsed: Option<serde_json::Value> = serde_json::from_str(arguments).ok();

        let is_shell = name == "shell" || name == "local_shell" || name == "shell_command";
        if is_shell {
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
            if command.is_empty() {
                return;
            }
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
    /// recorded in order, so the oldest unanswered call is the right one.
    fn attach_output(&mut self, call_id: &str, output: &str) {
        let Some(at) = self.open_calls.iter().position(|open| open == call_id) else {
            return;
        };
        self.open_calls.remove(at);

        let Some(turn) = self.current_turn.as_mut() else {
            return;
        };
        for item in turn.items.iter_mut().rev() {
            if let ThreadItem::CommandExecution {
                aggregated_output, ..
            } = item
                && aggregated_output.is_none()
            {
                *aggregated_output = Some(output.to_string());
                return;
            }
        }
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

        let turns = build_turns_from_rollout(&items);
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

        let turns = build_turns_from_rollout(&items);
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

        let turns = build_turns_from_rollout(&items);
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
    fn should_skip_a_call_whose_arguments_cannot_be_read() {
        // A row with no command in it says nothing; better none at all.
        let items = vec![RolloutItem::ResponseItem(ResponseItem::FunctionCall {
            id: None,
            name: "shell".to_string(),
            arguments: "not json".to_string(),
            call_id: "call-1".to_string(),
        })];
        assert!(build_turns_from_rollout(&items).is_empty());
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
            }
        );
        assert_eq!(
            turn.items[3],
            ThreadItem::Reasoning {
                id: "item-4".into(),
                summary: vec!["second summary".into()],
                content: Vec::new(),
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
