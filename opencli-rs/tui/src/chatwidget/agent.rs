use std::sync::Arc;

use opencli_core::NewThread;
use opencli_core::OpenCLIThread;
use opencli_core::ThreadManager;
use opencli_core::config::Config;
use opencli_core::protocol::Event;
use opencli_core::protocol::EventMsg;
use opencli_core::protocol::Op;
use tokio::sync::mpsc::UnboundedSender;
use tokio::sync::mpsc::unbounded_channel;

use crate::app_event::AppEvent;
use crate::app_event_sender::AppEventSender;

/// Spawn the agent bootstrapper and op forwarding loop, returning the
/// `UnboundedSender<Op>` used by the UI to submit operations.
pub(crate) fn spawn_agent(
    config: Config,
    app_event_tx: AppEventSender,
    server: Arc<ThreadManager>,
) -> UnboundedSender<Op> {
    let (opencli_op_tx, mut opencli_op_rx) = unbounded_channel::<Op>();

    let app_event_tx_clone = app_event_tx;
    tokio::spawn(async move {
        let NewThread {
            thread,
            session_configured,
            ..
        } = match server.start_thread(config).await {
            Ok(v) => v,
            Err(err) => {
                let message = format!("Failed to initialize opencli: {err}");
                tracing::error!("{message}");
                app_event_tx_clone.send(AppEvent::OpenCLIEvent(Event {
                    id: "".to_string(),
                    msg: EventMsg::Error(err.to_error_event(None)),
                }));
                app_event_tx_clone.send(AppEvent::FatalExitRequest(message));
                tracing::error!("failed to initialize opencli: {err}");
                return;
            }
        };

        // Forward the captured `SessionConfigured` event so it can be rendered in the UI.
        let ev = opencli_core::protocol::Event {
            // The `id` does not matter for rendering, so we can use a fake value.
            id: "".to_string(),
            msg: opencli_core::protocol::EventMsg::SessionConfigured(session_configured),
        };
        app_event_tx_clone.send(AppEvent::OpenCLIEvent(ev));

        let thread_clone = thread.clone();
        tokio::spawn(async move {
            while let Some(op) = opencli_op_rx.recv().await {
                let id = thread_clone.submit(op).await;
                if let Err(e) = id {
                    tracing::error!("failed to submit op: {e}");
                }
            }
        });

        while let Ok(event) = thread.next_event().await {
            app_event_tx_clone.send(AppEvent::OpenCLIEvent(event));
        }
    });

    opencli_op_tx
}

/// Spawn agent loops for an existing thread (e.g., a forked thread).
/// Sends the provided `SessionConfiguredEvent` immediately, then forwards subsequent
/// events and accepts Ops for submission.
pub(crate) fn spawn_agent_from_existing(
    thread: std::sync::Arc<OpenCLIThread>,
    session_configured: opencli_core::protocol::SessionConfiguredEvent,
    app_event_tx: AppEventSender,
) -> UnboundedSender<Op> {
    let (opencli_op_tx, mut opencli_op_rx) = unbounded_channel::<Op>();

    let app_event_tx_clone = app_event_tx;
    tokio::spawn(async move {
        // Forward the captured `SessionConfigured` event so it can be rendered in the UI.
        let ev = opencli_core::protocol::Event {
            id: "".to_string(),
            msg: opencli_core::protocol::EventMsg::SessionConfigured(session_configured),
        };
        app_event_tx_clone.send(AppEvent::OpenCLIEvent(ev));

        let thread_clone = thread.clone();
        tokio::spawn(async move {
            while let Some(op) = opencli_op_rx.recv().await {
                let id = thread_clone.submit(op).await;
                if let Err(e) = id {
                    tracing::error!("failed to submit op: {e}");
                }
            }
        });

        while let Ok(event) = thread.next_event().await {
            app_event_tx_clone.send(AppEvent::OpenCLIEvent(event));
        }
    });

    opencli_op_tx
}

/// Spawn an op-forwarding loop for an existing thread without subscribing to events.
pub(crate) fn spawn_op_forwarder(thread: std::sync::Arc<OpenCLIThread>) -> UnboundedSender<Op> {
    let (opencli_op_tx, mut opencli_op_rx) = unbounded_channel::<Op>();

    tokio::spawn(async move {
        while let Some(op) = opencli_op_rx.recv().await {
            if let Err(e) = thread.submit(op).await {
                tracing::error!("failed to submit op: {e}");
            }
        }
    });

    opencli_op_tx
}
