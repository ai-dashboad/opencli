use std::time::Duration;

use anyhow::Result;
use async_trait::async_trait;
use bytes::Bytes;
use opencli_api::AggregateStreamExt;
use opencli_api::AuthProvider;
use opencli_api::Provider;
use opencli_api::ResponseEvent;
use opencli_api::ResponsesClient;
use opencli_api::WireApi;
use opencli_api::requests::responses::Compression;
use opencli_client::HttpTransport;
use opencli_client::Request;
use opencli_client::Response;
use opencli_client::StreamResponse;
use opencli_client::TransportError;
use opencli_protocol::models::ContentItem;
use opencli_protocol::models::ResponseItem;
use futures::StreamExt;
use http::HeaderMap;
use http::StatusCode;
use pretty_assertions::assert_eq;
use serde_json::Value;

#[derive(Clone)]
struct FixtureSseTransport {
    body: String,
}

impl FixtureSseTransport {
    fn new(body: String) -> Self {
        Self { body }
    }
}

#[async_trait]
impl HttpTransport for FixtureSseTransport {
    async fn execute(&self, _req: Request) -> Result<Response, TransportError> {
        Err(TransportError::Build("execute should not run".to_string()))
    }

    async fn stream(&self, _req: Request) -> Result<StreamResponse, TransportError> {
        let stream = futures::stream::iter(vec![Ok::<Bytes, TransportError>(Bytes::from(
            self.body.clone(),
        ))]);
        Ok(StreamResponse {
            status: StatusCode::OK,
            headers: HeaderMap::new(),
            bytes: Box::pin(stream),
        })
    }
}

#[derive(Clone, Default)]
struct NoAuth;

impl AuthProvider for NoAuth {
    fn bearer_token(&self) -> Option<String> {
        None
    }
}

fn provider(name: &str, wire: WireApi) -> Provider {
    Provider {
        name: name.to_string(),
        base_url: "https://example.com/v1".to_string(),
        query_params: None,
        wire,
        headers: HeaderMap::new(),
        retry: opencli_api::provider::RetryConfig {
            max_attempts: 1,
            base_delay: Duration::from_millis(1),
            retry_429: false,
            retry_5xx: false,
            retry_transport: true,
        },
        stream_idle_timeout: Duration::from_millis(50),
    }
}

fn build_responses_body(events: Vec<Value>) -> String {
    let mut body = String::new();
    for e in events {
        let kind = e
            .get("type")
            .and_then(|v| v.as_str())
            .unwrap_or_else(|| panic!("fixture event missing type in SSE fixture: {e}"));
        if e.as_object().map(|o| o.len() == 1).unwrap_or(false) {
            body.push_str(&format!("event: {kind}\n\n"));
        } else {
            body.push_str(&format!("event: {kind}\ndata: {e}\n\n"));
        }
    }
    body
}

#[tokio::test]
async fn responses_stream_parses_items_and_completed_end_to_end() -> Result<()> {
    let item1 = serde_json::json!({
        "type": "response.output_item.done",
        "item": {
            "type": "message",
            "role": "assistant",
            "content": [{"type": "output_text", "text": "Hello"}]
        }
    });

    let item2 = serde_json::json!({
        "type": "response.output_item.done",
        "item": {
            "type": "message",
            "role": "assistant",
            "content": [{"type": "output_text", "text": "World"}]
        }
    });

    let completed = serde_json::json!({
        "type": "response.completed",
        "response": { "id": "resp1" }
    });

    let body = build_responses_body(vec![item1, item2, completed]);
    let transport = FixtureSseTransport::new(body);
    let client = ResponsesClient::new(transport, provider("openai", WireApi::Responses), NoAuth);

    let mut stream = client
        .stream(
            serde_json::json!({"echo": true}),
            HeaderMap::new(),
            Compression::None,
            None,
        )
        .await?;

    let mut events = Vec::new();
    while let Some(ev) = stream.next().await {
        events.push(ev?);
    }

    let events: Vec<ResponseEvent> = events
        .into_iter()
        .filter(|ev| !matches!(ev, ResponseEvent::RateLimits(_)))
        .collect();

    assert_eq!(events.len(), 3);

    match &events[0] {
        ResponseEvent::OutputItemDone(ResponseItem::Message { role, .. }) => {
            assert_eq!(role, "assistant");
        }
        other => panic!("unexpected first event: {other:?}"),
    }

    match &events[1] {
        ResponseEvent::OutputItemDone(ResponseItem::Message { role, .. }) => {
            assert_eq!(role, "assistant");
        }
        other => panic!("unexpected second event: {other:?}"),
    }

    match &events[2] {
        ResponseEvent::Completed {
            response_id,
            token_usage,
        } => {
            assert_eq!(response_id, "resp1");
            assert!(token_usage.is_none());
        }
        other => panic!("unexpected third event: {other:?}"),
    }

    Ok(())
}

#[tokio::test]
async fn responses_stream_aggregates_output_text_deltas() -> Result<()> {
    let delta1 = serde_json::json!({
        "type": "response.output_text.delta",
        "delta": "Hello, "
    });

    let delta2 = serde_json::json!({
        "type": "response.output_text.delta",
        "delta": "world"
    });

    let completed = serde_json::json!({
        "type": "response.completed",
        "response": { "id": "resp-agg" }
    });

    let body = build_responses_body(vec![delta1, delta2, completed]);
    let transport = FixtureSseTransport::new(body);
    let client = ResponsesClient::new(transport, provider("openai", WireApi::Responses), NoAuth);

    let stream = client
        .stream(
            serde_json::json!({"echo": true}),
            HeaderMap::new(),
            Compression::None,
            None,
        )
        .await?;

    let mut stream = stream.aggregate();
    let mut events = Vec::new();
    while let Some(ev) = stream.next().await {
        events.push(ev?);
    }

    let events: Vec<ResponseEvent> = events
        .into_iter()
        .filter(|ev| !matches!(ev, ResponseEvent::RateLimits(_)))
        .collect();

    // Aggregating assembles the whole message *and* passes the pieces on as
    // they arrive. It used to do only the first, which is what left every
    // local model with no streaming at all — the mode was chosen by a flag
    // about whether to show the model's thinking.
    let streamed: Vec<&str> = events
        .iter()
        .filter_map(|event| match event {
            ResponseEvent::OutputTextDelta(delta) => Some(delta.as_str()),
            _ => None,
        })
        .collect();
    assert_eq!(streamed, vec!["Hello, ", "world"]);

    let assembled = events.iter().find_map(|event| match event {
        ResponseEvent::OutputItemDone(ResponseItem::Message { content, .. }) => Some(
            content
                .iter()
                .filter_map(|item| match item {
                    ContentItem::OutputText { text } => Some(text.as_str()),
                    _ => None,
                })
                .collect::<String>(),
        ),
        _ => None,
    });
    assert_eq!(assembled.as_deref(), Some("Hello, world"));

    match events.last() {
        Some(ResponseEvent::Completed { response_id, .. }) => {
            assert_eq!(response_id, "resp-agg");
        }
        other => panic!("the stream should finish with a completion: {other:?}"),
    }

    Ok(())
}

/// Capture the request a client actually sends, so header behaviour can be
/// asserted rather than assumed.
#[derive(Clone, Default)]
struct RecordingTransport {
    body: String,
    seen: std::sync::Arc<std::sync::Mutex<Option<Request>>>,
}

#[async_trait]
impl HttpTransport for RecordingTransport {
    async fn execute(&self, _req: Request) -> Result<Response, TransportError> {
        Err(TransportError::Build("execute should not run".to_string()))
    }

    async fn stream(&self, req: Request) -> Result<StreamResponse, TransportError> {
        *self.seen.lock().expect("lock") = Some(req);
        let stream = futures::stream::iter(vec![Ok::<Bytes, TransportError>(Bytes::from(
            self.body.clone(),
        ))]);
        Ok(StreamResponse {
            status: StatusCode::OK,
            headers: HeaderMap::new(),
            bytes: Box::pin(stream),
        })
    }
}

#[derive(Clone)]
struct StaticKey(&'static str);

impl AuthProvider for StaticKey {
    fn bearer_token(&self) -> Option<String> {
        Some(self.0.to_string())
    }
}

/// Build an Anthropic SSE body. Anthropic names each event and repeats the name
/// inside the payload.
fn build_anthropic_body(events: Vec<Value>) -> String {
    let mut body = String::new();
    for event in events {
        let kind = event
            .get("type")
            .and_then(|value| value.as_str())
            .expect("fixture event missing type");
        body.push_str(&format!("event: {kind}\ndata: {event}\n\n"));
    }
    body
}

async fn collect(mut stream: opencli_api::ResponseStream) -> Vec<Result<ResponseEvent, opencli_api::ApiError>> {
    let mut events = Vec::new();
    while let Some(event) = stream.next().await {
        events.push(event);
    }
    events
}

#[tokio::test]
async fn should_stream_text_and_a_tool_call_from_anthropic_events() -> Result<()> {
    let body = build_anthropic_body(vec![
        serde_json::json!({"type": "message_start", "message": {"id": "msg_1", "usage": {"input_tokens": 5}}}),
        serde_json::json!({"type": "content_block_start", "index": 0, "content_block": {"type": "text"}}),
        serde_json::json!({"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": "Hi"}}),
        serde_json::json!({"type": "content_block_stop", "index": 0}),
        serde_json::json!({"type": "content_block_start", "index": 1,
            "content_block": {"type": "tool_use", "id": "tool_1", "name": "ping"}}),
        // Tool arguments arrive as partial JSON and are only valid once joined.
        serde_json::json!({"type": "content_block_delta", "index": 1,
            "delta": {"type": "input_json_delta", "partial_json": "{\"host\":"}}),
        serde_json::json!({"type": "content_block_delta", "index": 1,
            "delta": {"type": "input_json_delta", "partial_json": "\"a\"}"}}),
        serde_json::json!({"type": "content_block_stop", "index": 1}),
        serde_json::json!({"type": "message_delta", "delta": {"stop_reason": "tool_use"},
            "usage": {"output_tokens": 9}}),
        serde_json::json!({"type": "message_stop"}),
    ]);

    let client = opencli_api::AnthropicClient::new(
        FixtureSseTransport::new(body),
        provider("anthropic", WireApi::Anthropic),
        NoAuth,
    );
    let events = collect(client.stream(serde_json::json!({}), HeaderMap::new()).await?).await;
    let events: Vec<ResponseEvent> = events.into_iter().collect::<Result<_, _>>()?;

    assert!(matches!(events.first(), Some(ResponseEvent::Created)));
    assert!(
        events
            .iter()
            .any(|event| matches!(event, ResponseEvent::OutputTextDelta(text) if text == "Hi")),
        "the text delta should reach the agent"
    );
    let call = events
        .iter()
        .find_map(|event| match event {
            ResponseEvent::OutputItemDone(ResponseItem::FunctionCall { name, arguments, .. }) => {
                Some((name.clone(), arguments.clone()))
            }
            _ => None,
        })
        .expect("the tool call should be emitted once its block stops");
    assert_eq!(call.0, "ping");
    assert_eq!(call.1, r#"{"host":"a"}"#);
    assert!(matches!(events.last(), Some(ResponseEvent::Completed { .. })));
    Ok(())
}

#[tokio::test]
async fn should_report_an_anthropic_error_event_instead_of_completing_silently() -> Result<()> {
    // Ending the stream as if it succeeded would leave the user with an empty
    // reply and no reason for it.
    let body = build_anthropic_body(vec![
        serde_json::json!({"type": "message_start", "message": {"id": "msg_1"}}),
        serde_json::json!({"type": "error",
            "error": {"type": "overloaded_error", "message": "Overloaded"}}),
    ]);

    let client = opencli_api::AnthropicClient::new(
        FixtureSseTransport::new(body),
        provider("anthropic", WireApi::Anthropic),
        NoAuth,
    );
    let events = collect(client.stream(serde_json::json!({}), HeaderMap::new()).await?).await;

    let error = events.last().expect("an event").as_ref().expect_err("an error");
    assert!(error.to_string().contains("Overloaded"), "got: {error}");
    Ok(())
}

#[tokio::test]
async fn should_complete_the_turn_when_the_stream_ends_without_message_stop() -> Result<()> {
    // A dropped connection must not leave the agent waiting forever.
    let body = build_anthropic_body(vec![
        serde_json::json!({"type": "message_start", "message": {"id": "msg_1"}}),
        serde_json::json!({"type": "content_block_start", "index": 0, "content_block": {"type": "text"}}),
        serde_json::json!({"type": "content_block_delta", "index": 0,
            "delta": {"type": "text_delta", "text": "partial"}}),
    ]);

    let client = opencli_api::AnthropicClient::new(
        FixtureSseTransport::new(body),
        provider("anthropic", WireApi::Anthropic),
        NoAuth,
    );
    let events = collect(client.stream(serde_json::json!({}), HeaderMap::new()).await?).await;
    let events: Vec<ResponseEvent> = events.into_iter().collect::<Result<_, _>>()?;

    assert!(matches!(events.last(), Some(ResponseEvent::Completed { .. })));
    Ok(())
}

#[tokio::test]
async fn should_authenticate_anthropic_with_x_api_key_not_a_bearer_token() -> Result<()> {
    // Anthropic rejects `Authorization: Bearer` as unauthenticated.
    let transport = RecordingTransport {
        body: build_anthropic_body(vec![serde_json::json!({"type": "message_stop"})]),
        ..Default::default()
    };
    let seen = transport.seen.clone();

    let client = opencli_api::AnthropicClient::new(
        transport,
        provider("anthropic", WireApi::Anthropic),
        StaticKey("sk-ant-secret"),
    );
    let _ = collect(client.stream(serde_json::json!({}), HeaderMap::new()).await?).await;

    let request = seen.lock().expect("lock").clone().expect("a request was sent");
    assert_eq!(
        request.headers.get("x-api-key").map(|value| value.to_str().unwrap_or("")),
        Some("sk-ant-secret")
    );
    assert!(
        request.headers.get(http::header::AUTHORIZATION).is_none(),
        "a bearer token must not be sent to Anthropic"
    );
    assert!(request.url.ends_with("/messages"), "got: {}", request.url);
    Ok(())
}

#[tokio::test]
async fn should_still_authenticate_chat_providers_with_a_bearer_token() -> Result<()> {
    // The Anthropic branch must not change how every other provider is called.
    let transport = RecordingTransport {
        body: "data: [DONE]\n\n".to_string(),
        ..Default::default()
    };
    let seen = transport.seen.clone();

    let client = opencli_api::ChatClient::new(
        transport,
        provider("openai", WireApi::Chat),
        StaticKey("sk-openai"),
    );
    let _ = collect(client.stream(serde_json::json!({}), HeaderMap::new()).await?).await;

    let request = seen.lock().expect("lock").clone().expect("a request was sent");
    assert_eq!(
        request
            .headers
            .get(http::header::AUTHORIZATION)
            .map(|value| value.to_str().unwrap_or("")),
        Some("Bearer sk-openai")
    );
    assert!(request.headers.get("x-api-key").is_none());
    Ok(())
}
