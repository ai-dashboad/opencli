use crate::auth::AuthProvider;
use crate::auth::add_auth_headers;
use crate::common::ResponseStream;
use crate::error::ApiError;
use crate::provider::Provider;
use crate::telemetry::SseTelemetry;
use crate::telemetry::run_with_request_telemetry;
use opencli_client::HttpTransport;
use opencli_client::RequestCompression;
use opencli_client::RequestTelemetry;
use opencli_client::StreamResponse;
use opencli_client::TransportError;
use http::HeaderMap;
use http::Method;
use serde_json::Value;
use std::sync::Arc;
use std::sync::OnceLock;
use std::time::Duration;

pub(crate) struct StreamingClient<T: HttpTransport, A: AuthProvider> {
    transport: T,
    provider: Provider,
    auth: A,
    request_telemetry: Option<Arc<dyn RequestTelemetry>>,
    sse_telemetry: Option<Arc<dyn SseTelemetry>>,
}

type StreamSpawner = fn(
    StreamResponse,
    Duration,
    Option<Arc<dyn SseTelemetry>>,
    Option<Arc<OnceLock<String>>>,
) -> ResponseStream;

impl<T: HttpTransport, A: AuthProvider> StreamingClient<T, A> {
    pub(crate) fn new(transport: T, provider: Provider, auth: A) -> Self {
        Self {
            transport,
            provider,
            auth,
            request_telemetry: None,
            sse_telemetry: None,
        }
    }

    pub(crate) fn with_telemetry(
        mut self,
        request: Option<Arc<dyn RequestTelemetry>>,
        sse: Option<Arc<dyn SseTelemetry>>,
    ) -> Self {
        self.request_telemetry = request;
        self.sse_telemetry = sse;
        self
    }

    pub(crate) fn provider(&self) -> &Provider {
        &self.provider
    }

    pub(crate) async fn stream(
        &self,
        path: &str,
        body: Value,
        extra_headers: HeaderMap,
        compression: RequestCompression,
        spawner: StreamSpawner,
        turn_state: Option<Arc<OnceLock<String>>>,
    ) -> Result<ResponseStream, ApiError> {
        let builder = || {
            let mut req = self.provider.build_request(Method::POST, path);
            req.headers.extend(extra_headers.clone());
            req.headers.insert(
                http::header::ACCEPT,
                http::HeaderValue::from_static("text/event-stream"),
            );
            req.body = Some(body.clone());
            req.compression = compression;
            add_auth_headers(&self.auth, req, &self.provider.wire)
        };

        let stream_response = run_with_request_telemetry(
            self.provider.retry.to_policy(),
            self.request_telemetry.clone(),
            builder,
            |req| self.transport.stream(req),
        )
        .await
        .map_err(classify_transport_error)?;

        Ok(spawner(
            stream_response,
            self.provider.stream_idle_timeout,
            self.sse_telemetry.clone(),
            turn_state,
        ))
    }
}

/// Map a transport error to a semantic API error. A non-success HTTP response
/// whose body reports `context_length_exceeded` is turned into
/// `ContextWindowExceeded`, carrying the provider's real window when present,
/// so it is handled (compact + retry, learn the window) rather than retried
/// blindly as a generic failure.
fn classify_transport_error(err: TransportError) -> ApiError {
    if let TransportError::Http { body: Some(body), .. } = &err
        && let Ok(value) = serde_json::from_str::<Value>(body)
    {
        let error = value.get("error").unwrap_or(&value);
        let code = error.get("code").and_then(|c| c.as_str());
        let message = error.get("message").and_then(|m| m.as_str()).unwrap_or("");
        let is_context = code == Some("context_length_exceeded")
            || message.contains("context window")
            || message.contains("context length");
        if is_context {
            let context_limit = error
                .get("context_limit_tokens")
                .and_then(|v| v.as_u64())
                .or_else(|| value.get("context_limit_tokens").and_then(|v| v.as_u64()));
            return ApiError::ContextWindowExceeded { context_limit };
        }
    }
    ApiError::Transport(err)
}

#[cfg(test)]
mod tests {
    use super::*;
    use http::StatusCode;

    fn http_err(body: &str) -> TransportError {
        TransportError::Http {
            status: StatusCode::BAD_REQUEST,
            url: None,
            headers: None,
            body: Some(body.to_string()),
        }
    }

    #[test]
    fn should_classify_context_length_error_and_extract_limit() {
        let body = r#"{"error":{"type":"invalid_request_error","code":"context_length_exceeded","message":"This request exceeds glm-5.2's context window of 202752 tokens.","context_limit_tokens":202752}}"#;
        match classify_transport_error(http_err(body)) {
            ApiError::ContextWindowExceeded { context_limit } => {
                assert_eq!(context_limit, Some(202_752));
            }
            other => panic!("expected ContextWindowExceeded, got {other:?}"),
        }
    }

    #[test]
    fn should_pass_through_unrelated_http_errors() {
        let body = r#"{"error":{"code":"invalid_api_key","message":"bad key"}}"#;
        assert!(matches!(
            classify_transport_error(http_err(body)),
            ApiError::Transport(_)
        ));
    }
}
