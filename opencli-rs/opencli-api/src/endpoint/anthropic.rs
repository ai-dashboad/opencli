//! Streaming client for Anthropic's Messages API.
//!
//! A thin wrapper, like [`crate::endpoint::chat::ChatClient`]: the transport,
//! retries, and telemetry all live in `StreamingClient`. What differs is the
//! path (`messages`), the request shape (see [`crate::requests::anthropic`]),
//! and the event grammar (see [`crate::sse::anthropic`]).

use crate::auth::AuthProvider;
use crate::common::Prompt as ApiPrompt;
use crate::common::ResponseStream;
use crate::endpoint::streaming::StreamingClient;
use crate::error::ApiError;
use crate::provider::Provider;
use crate::requests::anthropic::AnthropicRequest;
use crate::requests::anthropic::AnthropicRequestBuilder;
use crate::sse::anthropic::spawn_anthropic_stream;
use crate::telemetry::SseTelemetry;
use http::HeaderMap;
use opencli_client::HttpTransport;
use opencli_client::RequestCompression;
use opencli_client::RequestTelemetry;
use serde_json::Value;
use std::sync::Arc;

pub struct AnthropicClient<T: HttpTransport, A: AuthProvider> {
    streaming: StreamingClient<T, A>,
}

impl<T: HttpTransport, A: AuthProvider> AnthropicClient<T, A> {
    pub fn new(transport: T, provider: Provider, auth: A) -> Self {
        Self {
            streaming: StreamingClient::new(transport, provider, auth),
        }
    }

    pub fn with_telemetry(
        self,
        request: Option<Arc<dyn RequestTelemetry>>,
        sse: Option<Arc<dyn SseTelemetry>>,
    ) -> Self {
        Self {
            streaming: self.streaming.with_telemetry(request, sse),
        }
    }

    pub async fn stream_request(
        &self,
        request: AnthropicRequest,
    ) -> Result<ResponseStream, ApiError> {
        self.stream(request.body, request.headers).await
    }

    pub async fn stream_prompt(
        &self,
        model: &str,
        prompt: &ApiPrompt,
        max_tokens: Option<u64>,
    ) -> Result<ResponseStream, ApiError> {
        let request =
            AnthropicRequestBuilder::new(model, &prompt.instructions, &prompt.input, &prompt.tools)
                .max_tokens(max_tokens)
                .build()?;
        self.stream_request(request).await
    }

    pub async fn stream(
        &self,
        body: Value,
        extra_headers: HeaderMap,
    ) -> Result<ResponseStream, ApiError> {
        self.streaming
            .stream(
                "messages",
                body,
                extra_headers,
                RequestCompression::None,
                spawn_anthropic_stream,
                None,
            )
            .await
    }
}
