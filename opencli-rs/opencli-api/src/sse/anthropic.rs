//! Translate Anthropic's Messages streaming events into [`ResponseEvent`].
//!
//! Anthropic streams named events rather than the single `data:` shape Chat
//! Completions uses:
//!
//! ```text
//! message_start          → Created
//! content_block_start    → begins a text or tool_use block
//! content_block_delta    → text_delta / input_json_delta
//! content_block_stop     → a completed block; tool_use becomes a FunctionCall
//! message_delta          → carries stop_reason and output token usage
//! message_stop           → Completed
//! ```
//!
//! Tool arguments arrive as a *partial JSON string* across many
//! `input_json_delta` events, so a tool call can only be emitted once its block
//! stops — accumulating is not an optimization here, it is required.

use crate::common::ResponseEvent;
use crate::common::ResponseStream;
use crate::error::ApiError;
use crate::telemetry::SseTelemetry;
use eventsource_stream::Eventsource;
use futures::Stream;
use futures::StreamExt;
use opencli_client::StreamResponse;
use opencli_protocol::models::ContentItem;
use opencli_protocol::models::ResponseItem;
use opencli_protocol::protocol::TokenUsage;
use serde_json::Value;
use std::sync::Arc;
use std::sync::OnceLock;
use std::time::Duration;
use tokio::sync::mpsc;
use tokio::time::Instant;
use tokio::time::timeout;
use tracing::trace;

/// A content block being accumulated across deltas.
#[derive(Debug, Clone)]
enum Block {
    Text(String),
    ToolUse {
        id: String,
        name: String,
        /// Partial JSON, concatenated from `input_json_delta` fragments.
        arguments: String,
    },
}

/// Incremental state for one streamed message.
#[derive(Debug, Default)]
pub struct AnthropicStreamState {
    blocks: Vec<Option<Block>>,
    message_id: String,
    input_tokens: i64,
    output_tokens: i64,
}

impl AnthropicStreamState {
    pub fn new() -> Self {
        Self::default()
    }

    /// Feed one parsed SSE payload; returns the events it produced.
    pub fn handle(&mut self, event: &Value) -> Vec<ResponseEvent> {
        let Some(kind) = event.get("type").and_then(Value::as_str) else {
            return Vec::new();
        };
        match kind {
            "message_start" => self.on_message_start(event),
            "content_block_start" => {
                self.on_block_start(event);
                Vec::new()
            }
            "content_block_delta" => self.on_block_delta(event),
            "content_block_stop" => self.on_block_stop(event),
            "message_delta" => {
                self.on_message_delta(event);
                Vec::new()
            }
            "message_stop" => self.on_message_stop(),
            // `ping` and unknown future events carry nothing the agent needs.
            _ => Vec::new(),
        }
    }

    fn on_message_start(&mut self, event: &Value) -> Vec<ResponseEvent> {
        if let Some(message) = event.get("message") {
            if let Some(id) = message.get("id").and_then(Value::as_str) {
                self.message_id = id.to_string();
            }
            if let Some(usage) = message.get("usage") {
                self.input_tokens = usage
                    .get("input_tokens")
                    .and_then(Value::as_i64)
                    .unwrap_or(0);
            }
        }
        vec![ResponseEvent::Created]
    }

    fn on_block_start(&mut self, event: &Value) {
        let index = block_index(event);
        let block = event.get("content_block").and_then(|b| {
            match b.get("type").and_then(Value::as_str)? {
                "text" => Some(Block::Text(String::new())),
                "tool_use" => Some(Block::ToolUse {
                    id: b
                        .get("id")
                        .and_then(Value::as_str)
                        .unwrap_or("")
                        .to_string(),
                    name: b
                        .get("name")
                        .and_then(Value::as_str)
                        .unwrap_or("")
                        .to_string(),
                    arguments: String::new(),
                }),
                _ => None,
            }
        });
        if self.blocks.len() <= index {
            self.blocks.resize(index + 1, None);
        }
        self.blocks[index] = block;
    }

    fn on_block_delta(&mut self, event: &Value) -> Vec<ResponseEvent> {
        let index = block_index(event);
        let Some(delta) = event.get("delta") else {
            return Vec::new();
        };
        let Some(slot) = self.blocks.get_mut(index).and_then(Option::as_mut) else {
            return Vec::new();
        };

        match (delta.get("type").and_then(Value::as_str), slot) {
            (Some("text_delta"), Block::Text(buffer)) => {
                let Some(text) = delta.get("text").and_then(Value::as_str) else {
                    return Vec::new();
                };
                buffer.push_str(text);
                vec![ResponseEvent::OutputTextDelta(text.to_string())]
            }
            // Tool arguments stream as partial JSON; nothing can be emitted
            // until the block stops and the fragments form valid JSON.
            (Some("input_json_delta"), Block::ToolUse { arguments, .. }) => {
                if let Some(fragment) = delta.get("partial_json").and_then(Value::as_str) {
                    arguments.push_str(fragment);
                }
                Vec::new()
            }
            _ => Vec::new(),
        }
    }

    fn on_block_stop(&mut self, event: &Value) -> Vec<ResponseEvent> {
        let index = block_index(event);
        let Some(block) = self.blocks.get_mut(index).and_then(Option::take) else {
            return Vec::new();
        };
        match block {
            Block::Text(text) if !text.is_empty() => {
                vec![ResponseEvent::OutputItemDone(ResponseItem::Message {
                    id: None,
                    role: "assistant".to_string(),
                    content: vec![ContentItem::OutputText { text }],
                    end_turn: None,
                })]
            }
            Block::ToolUse {
                id,
                name,
                arguments,
            } => {
                // An empty-argument call is legitimate for a no-parameter tool,
                // but the field must still be valid JSON downstream.
                let arguments = if arguments.trim().is_empty() {
                    "{}".to_string()
                } else {
                    arguments
                };
                vec![ResponseEvent::OutputItemDone(ResponseItem::FunctionCall {
                    id: None,
                    name,
                    arguments,
                    call_id: id,
                })]
            }
            Block::Text(_) => Vec::new(),
        }
    }

    fn on_message_delta(&mut self, event: &Value) {
        if let Some(usage) = event.get("usage")
            && let Some(output) = usage.get("output_tokens").and_then(Value::as_i64)
        {
            self.output_tokens = output;
        }
    }

    fn on_message_stop(&mut self) -> Vec<ResponseEvent> {
        vec![ResponseEvent::Completed {
            response_id: std::mem::take(&mut self.message_id),
            token_usage: Some(TokenUsage {
                input_tokens: self.input_tokens,
                cached_input_tokens: 0,
                output_tokens: self.output_tokens,
                reasoning_output_tokens: 0,
                total_tokens: self.input_tokens + self.output_tokens,
            }),
        }]
    }
}

fn block_index(event: &Value) -> usize {
    event
        .get("index")
        .and_then(Value::as_u64)
        .unwrap_or(0)
        .try_into()
        .unwrap_or(0)
}

pub(crate) fn spawn_anthropic_stream(
    stream_response: StreamResponse,
    idle_timeout: Duration,
    telemetry: Option<Arc<dyn SseTelemetry>>,
    _turn_state: Option<Arc<OnceLock<String>>>,
) -> ResponseStream {
    let (tx_event, rx_event) = mpsc::channel::<Result<ResponseEvent, ApiError>>(1600);
    tokio::spawn(async move {
        process_anthropic_sse(stream_response.bytes, tx_event, idle_timeout, telemetry).await;
    });
    ResponseStream { rx_event }
}

/// Drive [`AnthropicStreamState`] over a live SSE body.
///
/// Anthropic names its events (`event: content_block_delta`) but repeats the
/// name inside the JSON payload, so only the data is parsed — that keeps this
/// identical to how the state machine is unit-tested.
pub async fn process_anthropic_sse<S>(
    stream: S,
    tx_event: mpsc::Sender<Result<ResponseEvent, ApiError>>,
    idle_timeout: Duration,
    telemetry: Option<Arc<dyn SseTelemetry>>,
) where
    S: Stream<Item = Result<bytes::Bytes, opencli_client::TransportError>> + Unpin,
{
    let mut stream = stream.eventsource();
    let mut state = AnthropicStreamState::new();
    let mut completed_sent = false;

    loop {
        let start = Instant::now();
        let response = timeout(idle_timeout, stream.next()).await;
        if let Some(t) = telemetry.as_ref() {
            t.on_sse_poll(&response, start.elapsed());
        }
        let sse = match response {
            Ok(Some(Ok(sse))) => sse,
            Ok(Some(Err(err))) => {
                let _ = tx_event.send(Err(ApiError::Stream(err.to_string()))).await;
                return;
            }
            // A stream that ends without `message_stop` — a dropped connection —
            // must still complete the turn, or the agent waits forever.
            Ok(None) => {
                if !completed_sent {
                    let _ = tx_event
                        .send(Ok(ResponseEvent::Completed {
                            response_id: String::new(),
                            token_usage: None,
                        }))
                        .await;
                }
                return;
            }
            Err(_) => {
                let _ = tx_event
                    .send(Err(ApiError::Stream("idle timeout waiting for SSE".into())))
                    .await;
                return;
            }
        };

        trace!("Anthropic SSE event: {}", sse.data);
        let payload: Value = match serde_json::from_str(&sse.data) {
            Ok(payload) => payload,
            // Unparseable frames are skipped rather than fatal: a keep-alive or
            // a future event type should not kill an otherwise healthy turn.
            Err(_) => continue,
        };

        // An `error` event is terminal and carries the reason the turn failed;
        // reporting it beats letting the stream end as if it had succeeded.
        if payload.get("type").and_then(Value::as_str) == Some("error") {
            let message = payload
                .get("error")
                .and_then(|error| error.get("message"))
                .and_then(Value::as_str)
                .unwrap_or("the provider reported an error");
            let _ = tx_event
                .send(Err(ApiError::Stream(message.to_string())))
                .await;
            return;
        }

        for event in state.handle(&payload) {
            if matches!(event, ResponseEvent::Completed { .. }) {
                completed_sent = true;
            }
            if tx_event.send(Ok(event)).await.is_err() {
                return;
            }
        }
        if completed_sent {
            return;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn drain(state: &mut AnthropicStreamState, events: &[Value]) -> Vec<ResponseEvent> {
        events.iter().flat_map(|e| state.handle(e)).collect()
    }

    #[test]
    fn should_stream_text_deltas_and_close_with_a_message_item() {
        let mut state = AnthropicStreamState::new();
        let events = drain(
            &mut state,
            &[
                json!({"type":"message_start","message":{"id":"msg_1","usage":{"input_tokens":10}}}),
                json!({"type":"content_block_start","index":0,"content_block":{"type":"text"}}),
                json!({"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hel"}}),
                json!({"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"lo"}}),
                json!({"type":"content_block_stop","index":0}),
                json!({"type":"message_delta","usage":{"output_tokens":5}}),
                json!({"type":"message_stop"}),
            ],
        );

        let deltas: Vec<&str> = events
            .iter()
            .filter_map(|e| match e {
                ResponseEvent::OutputTextDelta(text) => Some(text.as_str()),
                _ => None,
            })
            .collect();
        assert_eq!(deltas, vec!["Hel", "lo"], "text must stream incrementally");

        let joined = events.iter().any(|e| matches!(
            e,
            ResponseEvent::OutputItemDone(ResponseItem::Message { content, .. })
                if matches!(content.first(), Some(ContentItem::OutputText { text }) if text == "Hello")
        ));
        assert!(joined, "the completed block must carry the joined text");
    }

    #[test]
    fn should_assemble_tool_arguments_from_partial_json_fragments() {
        // The whole point of buffering: each fragment is invalid JSON alone.
        let mut state = AnthropicStreamState::new();
        let events = drain(
            &mut state,
            &[
                json!({"type":"content_block_start","index":0,
                       "content_block":{"type":"tool_use","id":"toolu_1","name":"shell"}}),
                json!({"type":"content_block_delta","index":0,
                       "delta":{"type":"input_json_delta","partial_json":"{\"cmd\""}}),
                json!({"type":"content_block_delta","index":0,
                       "delta":{"type":"input_json_delta","partial_json":":\"ls\"}"}}),
                json!({"type":"content_block_stop","index":0}),
            ],
        );

        let call = events
            .iter()
            .find_map(|e| match e {
                ResponseEvent::OutputItemDone(ResponseItem::FunctionCall {
                    name,
                    arguments,
                    call_id,
                    ..
                }) => Some((name.clone(), arguments.clone(), call_id.clone())),
                _ => None,
            })
            .expect("a tool call should be emitted at block stop");

        assert_eq!(call.0, "shell");
        assert_eq!(call.2, "toolu_1");
        let parsed: Value = serde_json::from_str(&call.1).expect("arguments must be valid JSON");
        assert_eq!(parsed["cmd"], "ls");
    }

    #[test]
    fn should_emit_no_tool_call_before_the_block_stops() {
        let mut state = AnthropicStreamState::new();
        let events = drain(
            &mut state,
            &[
                json!({"type":"content_block_start","index":0,
                       "content_block":{"type":"tool_use","id":"t1","name":"x"}}),
                json!({"type":"content_block_delta","index":0,
                       "delta":{"type":"input_json_delta","partial_json":"{\"a\""}}),
            ],
        );
        assert!(
            events.is_empty(),
            "partial JSON must not be surfaced as a call"
        );
    }

    #[test]
    fn should_default_empty_tool_arguments_to_an_object() {
        let mut state = AnthropicStreamState::new();
        let events = drain(
            &mut state,
            &[
                json!({"type":"content_block_start","index":0,
                       "content_block":{"type":"tool_use","id":"t1","name":"noargs"}}),
                json!({"type":"content_block_stop","index":0}),
            ],
        );
        let arguments = events
            .iter()
            .find_map(|e| match e {
                ResponseEvent::OutputItemDone(ResponseItem::FunctionCall { arguments, .. }) => {
                    Some(arguments.clone())
                }
                _ => None,
            })
            .expect("call emitted");
        assert_eq!(arguments, "{}", "downstream parses this as JSON");
    }

    #[test]
    fn should_report_token_usage_on_completion() {
        let mut state = AnthropicStreamState::new();
        let events = drain(
            &mut state,
            &[
                json!({"type":"message_start","message":{"id":"msg_9","usage":{"input_tokens":100}}}),
                json!({"type":"message_delta","usage":{"output_tokens":25}}),
                json!({"type":"message_stop"}),
            ],
        );

        let usage = events
            .iter()
            .find_map(|e| match e {
                ResponseEvent::Completed {
                    response_id,
                    token_usage,
                } => Some((response_id.clone(), token_usage.clone())),
                _ => None,
            })
            .expect("completion emitted");
        assert_eq!(usage.0, "msg_9");
        let usage = usage.1.expect("usage present");
        assert_eq!(usage.input_tokens, 100);
        assert_eq!(usage.output_tokens, 25);
        assert_eq!(usage.total_tokens, 125);
    }

    #[test]
    fn should_ignore_pings_and_unknown_events() {
        let mut state = AnthropicStreamState::new();
        let events = drain(
            &mut state,
            &[json!({"type":"ping"}), json!({"type":"something_new"})],
        );
        assert!(events.is_empty());
    }

    #[test]
    fn should_keep_parallel_tool_blocks_separate() {
        // Two tools stream interleaved by index; mixing their arguments would
        // produce invalid JSON for both.
        let mut state = AnthropicStreamState::new();
        let events = drain(
            &mut state,
            &[
                json!({"type":"content_block_start","index":0,
                       "content_block":{"type":"tool_use","id":"t0","name":"first"}}),
                json!({"type":"content_block_start","index":1,
                       "content_block":{"type":"tool_use","id":"t1","name":"second"}}),
                json!({"type":"content_block_delta","index":0,
                       "delta":{"type":"input_json_delta","partial_json":"{\"a\":1}"}}),
                json!({"type":"content_block_delta","index":1,
                       "delta":{"type":"input_json_delta","partial_json":"{\"b\":2}"}}),
                json!({"type":"content_block_stop","index":0}),
                json!({"type":"content_block_stop","index":1}),
            ],
        );

        let calls: Vec<(String, String)> = events
            .iter()
            .filter_map(|e| match e {
                ResponseEvent::OutputItemDone(ResponseItem::FunctionCall {
                    name,
                    arguments,
                    ..
                }) => Some((name.clone(), arguments.clone())),
                _ => None,
            })
            .collect();
        assert_eq!(calls.len(), 2);
        assert_eq!(calls[0], ("first".to_string(), "{\"a\":1}".to_string()));
        assert_eq!(calls[1], ("second".to_string(), "{\"b\":2}".to_string()));
    }
}
