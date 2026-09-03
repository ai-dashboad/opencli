use crate::auth::AuthProvider;
use crate::auth::add_auth_headers;
use crate::common::ResponseStream;
use crate::error::ApiError;
use crate::provider::Provider;
use crate::telemetry::SseTelemetry;
use crate::telemetry::run_with_request_telemetry;
use http::HeaderMap;
use http::Method;
use opencli_client::HttpTransport;
use opencli_client::RequestCompression;
use opencli_client::RequestTelemetry;
use opencli_client::StreamResponse;
use opencli_client::TransportError;
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
    if let TransportError::Http {
        body: Some(body), ..
    } = &err
        && let Ok(value) = serde_json::from_str::<Value>(body)
    {
        let error = unwrap_nested_error(value.get("error").unwrap_or(&value));
        let code = error.get("code").and_then(|c| c.as_str());
        let kind = error.get("type").and_then(|t| t.as_str());
        let message = error.get("message").and_then(|m| m.as_str()).unwrap_or("");
        let is_context = code == Some("context_length_exceeded")
            || kind == Some("exceed_context_size_error")
            || message.contains("context window")
            || message.contains("context length")
            // llama.cpp and Ollama say "context size", and say it in prose.
            || message.contains("context size");
        if is_context {
            let context_limit = error
                .get("context_limit_tokens")
                .and_then(serde_json::Value::as_u64)
                .or_else(|| {
                    value
                        .get("context_limit_tokens")
                        .and_then(serde_json::Value::as_u64)
                })
                .or_else(|| limit_from_message(message));
            return ApiError::ContextWindowExceeded { context_limit };
        }
    }
    ApiError::Transport(err)
}

/// Look inside an error whose `message` is itself an encoded error.
///
/// llama.cpp behind Ollama reports
/// `{"error":{"message":"{\"error\":{\"type\":\"exceed_context_size_error\"…}}"}}`
/// — the real error as a string in the field where prose is expected. Read as
/// prose it matches nothing, so an over-long request looked like an ordinary
/// bad request and the turn failed instead of compacting.
fn unwrap_nested_error(error: &Value) -> Value {
    let Some(text) = error.get("message").and_then(|m| m.as_str()) else {
        return error.clone();
    };
    let Ok(inner) = serde_json::from_str::<Value>(text) else {
        return error.clone();
    };
    inner.get("error").unwrap_or(&inner).clone()
}

/// The window a provider named in prose, when it named one at all.
///
/// "request (36058 tokens) exceeds the available context size (32768 tokens)"
/// carries the real limit and nothing else does; without it the window has to
/// be guessed from the request that just overflowed.
fn limit_from_message(message: &str) -> Option<u64> {
    let at = message.find("context size")?;
    let rest = &message[at..];
    let open = rest.find('(')? + at + 1;
    let close = message[open..].find(" tokens")? + open;
    message[open..close].trim().parse().ok()
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
    fn should_recognise_the_way_a_local_server_says_it() {
        // Captured from llama.cpp behind Ollama: the real error arrives as a
        // JSON string inside the `message` field, and says "context size"
        // rather than "context window". Read as prose it matched nothing, so
        // an over-long request looked like an ordinary bad request — the turn
        // failed instead of compacting and retrying.
        let body = r#"{"error":{"message":"{\"error\":{\"code\":400,\"message\":\"request (36058 tokens) exceeds the available context size (32768 tokens), try increasing it\",\"type\":\"exceed_context_size_error\"}}"}}"#;
        match classify_transport_error(http_err(body)) {
            ApiError::ContextWindowExceeded { context_limit } => {
                assert_eq!(context_limit, Some(32_768), "the window it named");
            }
            other => panic!("expected ContextWindowExceeded, got {other:?}"),
        }
    }

    #[test]
    fn should_read_the_window_out_of_prose() {
        assert_eq!(
            limit_from_message(
                "request (36058 tokens) exceeds the available context size (32768 tokens)"
            ),
            Some(32_768)
        );
        assert_eq!(limit_from_message("something else entirely"), None);
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
