//! Request builder for Anthropic's Messages API.
//!
//! Anthropic is not OpenAI-compatible, so this is a real translation rather
//! than a base-URL swap. The differences that matter:
//!
//! | | OpenAI Chat Completions | Anthropic Messages |
//! |---|---|---|
//! | system prompt | first `messages` entry | top-level `system` field |
//! | `max_tokens` | optional | **required** |
//! | tool schema | `{type, function:{name, parameters}}` | `{name, input_schema}` |
//! | tool call | `message.tool_calls[]` | `content:[{type:"tool_use"}]` |
//! | tool result | `{role:"tool", tool_call_id}` | `{role:"user", content:[{type:"tool_result"}]}` |
//! | auth | `Authorization: Bearer` | `x-api-key` + `anthropic-version` |

use crate::error::ApiError;
use http::HeaderMap;
use http::HeaderValue;
use opencli_protocol::models::ContentItem;
use opencli_protocol::models::ResponseItem;
use serde_json::Value;
use serde_json::json;

/// API version pinned in the header Anthropic requires on every request.
pub const ANTHROPIC_VERSION: &str = "2023-06-01";

/// Anthropic requires `max_tokens`; this is the ceiling used when the caller
/// does not specify one. Large enough not to truncate ordinary agent turns.
const DEFAULT_MAX_TOKENS: u64 = 8192;

pub struct AnthropicRequest {
    pub body: Value,
    pub headers: HeaderMap,
}

pub struct AnthropicRequestBuilder<'a> {
    model: &'a str,
    instructions: &'a str,
    input: &'a [ResponseItem],
    tools: &'a [Value],
    max_tokens: Option<u64>,
}

impl<'a> AnthropicRequestBuilder<'a> {
    pub fn new(
        model: &'a str,
        instructions: &'a str,
        input: &'a [ResponseItem],
        tools: &'a [Value],
    ) -> Self {
        Self {
            model,
            instructions,
            input,
            tools,
            max_tokens: None,
        }
    }

    pub fn max_tokens(mut self, max_tokens: Option<u64>) -> Self {
        self.max_tokens = max_tokens;
        self
    }

    pub fn build(self) -> Result<AnthropicRequest, ApiError> {
        let mut headers = HeaderMap::new();
        headers.insert("anthropic-version", HeaderValue::from_static(ANTHROPIC_VERSION));

        let body = json!({
            "model": self.model,
            // Required by the API, unlike Chat Completions where it is optional.
            "max_tokens": self.max_tokens.unwrap_or(DEFAULT_MAX_TOKENS),
            // The system prompt is a top-level field, not a message.
            "system": self.instructions,
            "messages": convert_messages(self.input),
            "tools": convert_tools(self.tools),
            "stream": true,
        });

        Ok(AnthropicRequest { body, headers })
    }
}

/// Translate OpenAI-style tool declarations into Anthropic's shape.
///
/// Entries that do not look like a function declaration are dropped rather than
/// passed through: Anthropic rejects the whole request on an unknown tool
/// field, which would take down the turn instead of just that tool.
pub(crate) fn convert_tools(tools: &[Value]) -> Vec<Value> {
    tools
        .iter()
        .filter_map(|tool| {
            let function = tool.get("function")?;
            let name = function.get("name")?.as_str()?;
            let description = function
                .get("description")
                .and_then(Value::as_str)
                .unwrap_or_default();
            let schema = function
                .get("parameters")
                .cloned()
                .unwrap_or_else(|| json!({"type": "object", "properties": {}}));
            Some(json!({
                "name": name,
                "description": description,
                "input_schema": schema,
            }))
        })
        .collect()
}

fn text_of(content: &[ContentItem]) -> String {
    content
        .iter()
        .filter_map(|item| match item {
            ContentItem::InputText { text } | ContentItem::OutputText { text } => {
                Some(text.as_str())
            }
            _ => None,
        })
        .collect::<Vec<_>>()
        .join("")
}

/// Build the `messages` array.
///
/// Anthropic requires strictly alternating user/assistant turns and carries
/// tool calls and their results as content blocks, so consecutive items of the
/// same role are merged rather than emitted separately.
pub(crate) fn convert_messages(input: &[ResponseItem]) -> Vec<Value> {
    let mut messages: Vec<Value> = Vec::new();

    for item in input {
        match item {
            ResponseItem::Message { role, content, .. } => {
                // A system message in history belongs in the top-level `system`
                // field, which the caller already set; skip it here rather than
                // sending a role Anthropic does not accept.
                if role == "system" {
                    continue;
                }
                let text = text_of(content);
                if text.is_empty() {
                    continue;
                }
                push_block(&mut messages, role, json!({"type": "text", "text": text}));
            }
            ResponseItem::FunctionCall {
                name,
                arguments,
                call_id,
                ..
            } => {
                // Anthropic wants parsed input, not a JSON string.
                let input: Value =
                    serde_json::from_str(arguments).unwrap_or_else(|_| json!({"raw": arguments}));
                push_block(
                    &mut messages,
                    "assistant",
                    json!({
                        "type": "tool_use",
                        "id": call_id,
                        "name": name,
                        "input": input,
                    }),
                );
            }
            ResponseItem::FunctionCallOutput { call_id, output } => {
                // Tool results are user-role content blocks here, not a
                // dedicated `tool` role.
                push_block(
                    &mut messages,
                    "user",
                    json!({
                        "type": "tool_result",
                        "tool_use_id": call_id,
                        "content": output.content,
                    }),
                );
            }
            _ => {}
        }
    }

    messages
}

/// Append a content block, merging into the previous message when the role
/// matches so the alternating-turn rule is not violated.
fn push_block(messages: &mut Vec<Value>, role: &str, block: Value) {
    if let Some(last) = messages.last_mut()
        && last.get("role").and_then(Value::as_str) == Some(role)
        && let Some(content) = last.get_mut("content").and_then(Value::as_array_mut)
    {
        content.push(block);
        return;
    }
    messages.push(json!({ "role": role, "content": [block] }));
}

#[cfg(test)]
mod tests {
    use super::*;
    use opencli_protocol::models::FunctionCallOutputPayload;

    fn user(text: &str) -> ResponseItem {
        ResponseItem::Message {
            id: None,
            role: "user".to_string(),
            content: vec![ContentItem::InputText {
                text: text.to_string(),
            }],
            end_turn: None,
        }
    }

    #[test]
    fn should_put_the_system_prompt_in_its_own_field() {
        let request = AnthropicRequestBuilder::new("claude", "be terse", &[user("hi")], &[])
            .build()
            .expect("build");

        assert_eq!(request.body["system"], "be terse");
        // Anthropic rejects a `system` role inside `messages`.
        let roles: Vec<&str> = request.body["messages"]
            .as_array()
            .expect("messages")
            .iter()
            .filter_map(|m| m["role"].as_str())
            .collect();
        assert_eq!(roles, vec!["user"]);
    }

    #[test]
    fn should_always_send_max_tokens_because_the_api_requires_it() {
        let request = AnthropicRequestBuilder::new("claude", "", &[user("hi")], &[])
            .build()
            .expect("build");
        assert!(request.body["max_tokens"].as_u64().is_some_and(|n| n > 0));
    }

    #[test]
    fn should_set_the_required_version_header() {
        let request = AnthropicRequestBuilder::new("claude", "", &[user("hi")], &[])
            .build()
            .expect("build");
        assert_eq!(
            request.headers.get("anthropic-version").map(|v| v.to_str().unwrap_or("")),
            Some(ANTHROPIC_VERSION)
        );
    }

    #[test]
    fn should_translate_tool_declarations_to_input_schema() {
        let tools = vec![json!({
            "type": "function",
            "function": {
                "name": "shell",
                "description": "run a command",
                "parameters": {"type": "object", "properties": {"cmd": {"type": "string"}}}
            }
        })];

        let converted = convert_tools(&tools);

        assert_eq!(converted.len(), 1);
        assert_eq!(converted[0]["name"], "shell");
        assert_eq!(converted[0]["input_schema"]["properties"]["cmd"]["type"], "string");
        // The OpenAI-only wrapper keys must be gone.
        assert!(converted[0].get("function").is_none());
        assert!(converted[0].get("parameters").is_none());
    }

    #[test]
    fn should_drop_tools_that_are_not_function_declarations() {
        // Anthropic fails the whole request on an unknown tool shape, so a
        // passthrough would cost the turn rather than just the tool.
        let tools = vec![json!({"type": "web_search"})];
        assert!(convert_tools(&tools).is_empty());
    }

    #[test]
    fn should_carry_a_tool_call_and_its_result_as_content_blocks() {
        let items = vec![
            user("list files"),
            ResponseItem::FunctionCall {
                id: None,
                name: "shell".to_string(),
                arguments: r#"{"cmd":"ls"}"#.to_string(),
                call_id: "call_1".to_string(),
            },
            ResponseItem::FunctionCallOutput {
                call_id: "call_1".to_string(),
                output: FunctionCallOutputPayload {
                    content: "a.txt".to_string(),
                    content_items: None,
                    success: Some(true),
                },
            },
        ];

        let messages = convert_messages(&items);

        assert_eq!(messages[1]["role"], "assistant");
        assert_eq!(messages[1]["content"][0]["type"], "tool_use");
        // Arguments must be parsed; Anthropic expects an object, not a string.
        assert_eq!(messages[1]["content"][0]["input"]["cmd"], "ls");

        assert_eq!(messages[2]["role"], "user");
        assert_eq!(messages[2]["content"][0]["type"], "tool_result");
        assert_eq!(messages[2]["content"][0]["tool_use_id"], "call_1");
    }

    #[test]
    fn should_merge_consecutive_same_role_items_into_one_message() {
        // Anthropic requires alternating turns; two assistant messages in a row
        // are rejected.
        let items = vec![
            ResponseItem::FunctionCall {
                id: None,
                name: "a".to_string(),
                arguments: "{}".to_string(),
                call_id: "1".to_string(),
            },
            ResponseItem::FunctionCall {
                id: None,
                name: "b".to_string(),
                arguments: "{}".to_string(),
                call_id: "2".to_string(),
            },
        ];

        let messages = convert_messages(&items);

        assert_eq!(messages.len(), 1, "both calls belong to one assistant turn");
        assert_eq!(messages[0]["content"].as_array().map(Vec::len), Some(2));
    }

    #[test]
    fn should_keep_malformed_tool_arguments_instead_of_dropping_the_call() {
        let items = vec![ResponseItem::FunctionCall {
            id: None,
            name: "shell".to_string(),
            arguments: "not json".to_string(),
            call_id: "1".to_string(),
        }];

        let messages = convert_messages(&items);

        // Losing the call entirely would desync the tool_use/tool_result pairing.
        assert_eq!(messages[0]["content"][0]["input"]["raw"], "not json");
    }
}
