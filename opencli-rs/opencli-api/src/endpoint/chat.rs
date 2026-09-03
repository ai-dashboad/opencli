use crate::ChatRequest;
use crate::auth::AuthProvider;
use crate::common::Prompt as ApiPrompt;
use crate::common::ResponseEvent;
use crate::common::ResponseStream;
use crate::endpoint::streaming::StreamingClient;
use crate::error::ApiError;
use crate::provider::Provider;
use crate::provider::WireApi;
use crate::sse::chat::spawn_chat_stream;
use crate::telemetry::SseTelemetry;
use futures::Stream;
use http::HeaderMap;
use opencli_client::HttpTransport;
use opencli_client::RequestCompression;
use opencli_client::RequestTelemetry;
use opencli_protocol::models::ContentItem;
use opencli_protocol::models::ReasoningItemContent;
use opencli_protocol::models::ResponseItem;
use opencli_protocol::protocol::SessionSource;
use serde_json::Value;
use std::collections::VecDeque;
use std::pin::Pin;
use std::sync::Arc;
use std::task::Context;
use std::task::Poll;

pub struct ChatClient<T: HttpTransport, A: AuthProvider> {
    streaming: StreamingClient<T, A>,
}

impl<T: HttpTransport, A: AuthProvider> ChatClient<T, A> {
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

    pub async fn stream_request(&self, request: ChatRequest) -> Result<ResponseStream, ApiError> {
        self.stream(request.body, request.headers).await
    }

    pub async fn stream_prompt(
        &self,
        model: &str,
        prompt: &ApiPrompt,
        conversation_id: Option<String>,
        session_source: Option<SessionSource>,
    ) -> Result<ResponseStream, ApiError> {
        use crate::requests::ChatRequestBuilder;

        let request =
            ChatRequestBuilder::new(model, &prompt.instructions, &prompt.input, &prompt.tools)
                .conversation_id(conversation_id)
                .session_source(session_source)
                .build(self.streaming.provider())?;

        self.stream_request(request).await
    }

    fn path(&self) -> &'static str {
        match self.streaming.provider().wire {
            WireApi::Chat => "chat/completions",
            _ => "responses",
        }
    }

    pub async fn stream(
        &self,
        body: Value,
        extra_headers: HeaderMap,
    ) -> Result<ResponseStream, ApiError> {
        self.streaming
            .stream(
                self.path(),
                body,
                extra_headers,
                RequestCompression::None,
                spawn_chat_stream,
                None,
            )
            .await
    }
}

#[derive(Copy, Clone, Eq, PartialEq)]
/// What to do with the model's *thinking* as it arrives.
///
/// The answer itself is always streamed; only reasoning is at stake here.
pub enum AggregateMode {
    /// Keep the thinking to itself, and report only the finished answer
    /// alongside the streamed text.
    AggregatedOnly,
    /// Pass the thinking on as well, for a caller that shows it.
    Streaming,
}

/// Stream adapter that merges token deltas into a single assistant message per turn.
pub struct AggregatedStream {
    inner: ResponseStream,
    cumulative: String,
    cumulative_reasoning: String,
    pending: VecDeque<ResponseEvent>,
    mode: AggregateMode,
}

impl Stream for AggregatedStream {
    type Item = Result<ResponseEvent, ApiError>;

    fn poll_next(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Option<Self::Item>> {
        let this = self.get_mut();

        if let Some(ev) = this.pending.pop_front() {
            return Poll::Ready(Some(Ok(ev)));
        }

        loop {
            match Pin::new(&mut this.inner).poll_next(cx) {
                Poll::Pending => return Poll::Pending,
                Poll::Ready(None) => return Poll::Ready(None),
                Poll::Ready(Some(Err(e))) => return Poll::Ready(Some(Err(e))),
                Poll::Ready(Some(Ok(ResponseEvent::OutputItemDone(item)))) => {
                    let is_assistant_message = matches!(
                        &item,
                        ResponseItem::Message { role, .. } if role == "assistant"
                    );

                    if is_assistant_message {
                        match this.mode {
                            AggregateMode::AggregatedOnly => {
                                if this.cumulative.is_empty()
                                    && let ResponseItem::Message { content, .. } = &item
                                    && let Some(text) = content.iter().find_map(|c| match c {
                                        ContentItem::OutputText { text } => Some(text),
                                        _ => None,
                                    })
                                {
                                    this.cumulative.push_str(text);
                                }
                                continue;
                            }
                            AggregateMode::Streaming => {
                                if this.cumulative.is_empty() {
                                    return Poll::Ready(Some(Ok(ResponseEvent::OutputItemDone(
                                        item,
                                    ))));
                                } else {
                                    continue;
                                }
                            }
                        }
                    }

                    return Poll::Ready(Some(Ok(ResponseEvent::OutputItemDone(item))));
                }
                Poll::Ready(Some(Ok(ResponseEvent::ServerReasoningIncluded(included)))) => {
                    return Poll::Ready(Some(Ok(ResponseEvent::ServerReasoningIncluded(included))));
                }
                Poll::Ready(Some(Ok(ResponseEvent::RateLimits(snapshot)))) => {
                    return Poll::Ready(Some(Ok(ResponseEvent::RateLimits(snapshot))));
                }
                Poll::Ready(Some(Ok(ResponseEvent::ModelsEtag(etag)))) => {
                    return Poll::Ready(Some(Ok(ResponseEvent::ModelsEtag(etag))));
                }
                Poll::Ready(Some(Ok(ResponseEvent::Completed {
                    response_id,
                    token_usage,
                }))) => {
                    let mut emitted_any = false;

                    if !this.cumulative_reasoning.is_empty() {
                        let aggregated_reasoning = ResponseItem::Reasoning {
                            id: String::new(),
                            summary: Vec::new(),
                            content: Some(vec![ReasoningItemContent::ReasoningText {
                                text: std::mem::take(&mut this.cumulative_reasoning),
                            }]),
                            encrypted_content: None,
                        };
                        this.pending
                            .push_back(ResponseEvent::OutputItemDone(aggregated_reasoning));
                        emitted_any = true;
                    }

                    if !this.cumulative.is_empty() {
                        let aggregated_message = ResponseItem::Message {
                            id: None,
                            role: "assistant".to_string(),
                            content: vec![ContentItem::OutputText {
                                text: std::mem::take(&mut this.cumulative),
                            }],
                            end_turn: None,
                        };
                        this.pending
                            .push_back(ResponseEvent::OutputItemDone(aggregated_message));
                        emitted_any = true;
                    }

                    if emitted_any {
                        this.pending.push_back(ResponseEvent::Completed {
                            response_id: response_id.clone(),
                            token_usage: token_usage.clone(),
                        });
                        if let Some(ev) = this.pending.pop_front() {
                            return Poll::Ready(Some(Ok(ev)));
                        }
                    }

                    return Poll::Ready(Some(Ok(ResponseEvent::Completed {
                        response_id,
                        token_usage,
                    })));
                }
                Poll::Ready(Some(Ok(ResponseEvent::Created))) => {
                    continue;
                }
                Poll::Ready(Some(Ok(ResponseEvent::OutputTextDelta(delta)))) => {
                    this.cumulative.push_str(&delta);
                    // The answer is always passed on, in both modes.
                    //
                    // Withholding it was the difference between a reply that
                    // appears a word at a time and one that appears all at
                    // once after minutes of nothing — and it was decided by a
                    // flag about whether to show the model's *thinking*, which
                    // is a different question entirely. Every local model
                    // speaks this wire, so every local model was affected.
                    return Poll::Ready(Some(Ok(ResponseEvent::OutputTextDelta(delta))));
                }
                Poll::Ready(Some(Ok(ResponseEvent::ReasoningContentDelta {
                    delta,
                    content_index,
                }))) => {
                    this.cumulative_reasoning.push_str(&delta);
                    if matches!(this.mode, AggregateMode::Streaming) {
                        return Poll::Ready(Some(Ok(ResponseEvent::ReasoningContentDelta {
                            delta,
                            content_index,
                        })));
                    } else {
                        continue;
                    }
                }
                Poll::Ready(Some(Ok(ResponseEvent::ReasoningSummaryDelta { .. }))) => continue,
                Poll::Ready(Some(Ok(ResponseEvent::ReasoningSummaryPartAdded { .. }))) => {
                    continue;
                }
                Poll::Ready(Some(Ok(ResponseEvent::OutputItemAdded(item)))) => {
                    return Poll::Ready(Some(Ok(ResponseEvent::OutputItemAdded(item))));
                }
            }
        }
    }
}

pub trait AggregateStreamExt {
    fn aggregate(self) -> AggregatedStream;

    fn streaming_mode(self) -> ResponseStream;
}

impl AggregateStreamExt for ResponseStream {
    fn aggregate(self) -> AggregatedStream {
        AggregatedStream::new(self, AggregateMode::AggregatedOnly)
    }

    fn streaming_mode(self) -> ResponseStream {
        self
    }
}

impl AggregatedStream {
    fn new(inner: ResponseStream, mode: AggregateMode) -> Self {
        AggregatedStream {
            inner,
            cumulative: String::new(),
            cumulative_reasoning: String::new(),
            pending: VecDeque::new(),
            mode,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use futures::StreamExt;

    /// Feed a fixed set of events through the adapter and collect what came out.
    async fn through(mode: AggregateMode, events: Vec<ResponseEvent>) -> Vec<ResponseEvent> {
        let (tx, rx_event) = tokio::sync::mpsc::channel(16);
        for event in events {
            tx.send(Ok(event)).await.expect("queue an event");
        }
        drop(tx);

        let mut stream = AggregatedStream::new(ResponseStream { rx_event }, mode);
        let mut out = Vec::new();
        while let Some(event) = stream.next().await {
            out.push(event.expect("no error"));
        }
        out
    }

    #[tokio::test]
    async fn should_stream_the_answer_whether_or_not_thinking_is_shown() {
        // A flag about showing the model's *thinking* was deciding whether the
        // answer arrived a word at a time or all at once after minutes of
        // nothing. Every local model speaks this wire, so every local model
        // was affected.
        for mode in [AggregateMode::AggregatedOnly, AggregateMode::Streaming] {
            let out = through(
                mode,
                vec![
                    ResponseEvent::OutputTextDelta("Hello".into()),
                    ResponseEvent::OutputTextDelta(" there".into()),
                ],
            )
            .await;

            let streamed: Vec<&str> = out
                .iter()
                .filter_map(|event| match event {
                    ResponseEvent::OutputTextDelta(delta) => Some(delta.as_str()),
                    _ => None,
                })
                .collect();
            assert_eq!(streamed, vec!["Hello", " there"]);
        }
    }

    #[tokio::test]
    async fn should_keep_thinking_to_itself_unless_it_was_asked_for() {
        let count = |out: &[ResponseEvent]| {
            out.iter()
                .filter(|event| matches!(event, ResponseEvent::ReasoningContentDelta { .. }))
                .count()
        };
        let thinking = || {
            vec![ResponseEvent::ReasoningContentDelta {
                delta: "thinking".into(),
                content_index: 0,
            }]
        };

        assert_eq!(
            count(&through(AggregateMode::AggregatedOnly, thinking()).await),
            0,
            "hidden when it was not asked for"
        );
        assert_eq!(
            count(&through(AggregateMode::Streaming, thinking()).await),
            1,
            "passed on when it was"
        );
    }
}
