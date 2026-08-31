//! WebSocket gateway in front of `opencli app-server`.
//!
//! The app server speaks JSON-RPC over stdio, which a browser cannot reach.
//! This crate spawns it as a child process and relays newline-delimited JSON
//! between its stdio and a WebSocket, so a web UI can drive the same protocol
//! the VS Code extension uses.
//!
//! Running it as a child rather than embedding the server keeps the change
//! small and isolates a crashing agent from the gateway, matching how
//! `stdio-to-uds` already bridges this protocol elsewhere in the tree.
//!
//! # Security
//!
//! A connected client can make the agent read files and run commands **on the
//! machine running the gateway**. Two deliberate constraints follow:
//!
//! - the listener binds loopback unless explicitly told otherwise, so it is not
//!   exposed to the network by accident;
//! - every connection must present a token, generated per run and printed once,
//!   so another local user (or a web page in your browser) cannot drive it.
//!
//! This is a single-user, self-hosted design. Serving multiple untrusted users
//! would need per-user sandboxing and is out of scope.

use anyhow::Context;
use anyhow::Result;
use axum::Router;
use axum::extract::Query;
use axum::extract::State;
use axum::extract::ws::Message;
use axum::extract::ws::WebSocket;
use axum::extract::ws::WebSocketUpgrade;
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::routing::get;
use serde::Deserialize;
use std::net::IpAddr;
use std::net::SocketAddr;
use std::path::PathBuf;
use std::process::Stdio;
use std::sync::Arc;
use tokio::io::AsyncBufReadExt;
use tokio::io::AsyncWriteExt;
use tokio::io::BufReader;
use tokio::sync::mpsc;

/// How the gateway should listen.
#[derive(Debug, Clone)]
pub struct ServeConfig {
    pub host: IpAddr,
    pub port: u16,
    /// Path to the binary to run as the app server. Defaults to the current
    /// executable so the gateway always matches the build it shipped with.
    pub server_bin: Option<PathBuf>,
    /// Skip token authentication. Only honoured for loopback binds.
    pub no_auth: bool,
    /// Config home holding the scheduled-task store. Defaults to `~/.opencli`.
    pub opencli_home: Option<PathBuf>,
}

struct GatewayState {
    token: Option<String>,
    server_bin: PathBuf,
    /// Where scheduled tasks are stored.
    opencli_home: PathBuf,
}

#[derive(Deserialize)]
struct ConnectParams {
    token: Option<String>,
}

/// Generate a URL-safe token for this run.
fn generate_token() -> String {
    use rand::Rng;
    const ALPHABET: &[u8] = b"abcdefghijklmnopqrstuvwxyz0123456789";
    let mut rng = rand::rng();
    (0..32)
        .map(|_| ALPHABET[rng.random_range(0..ALPHABET.len())] as char)
        .collect()
}

/// Config home used when the caller does not specify one.
fn default_opencli_home() -> PathBuf {
    std::env::var_os("OPENCLI_HOME")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|home| PathBuf::from(home).join(".opencli")))
        .unwrap_or_else(|| PathBuf::from(".opencli"))
}

/// Whether `host` is a loopback address.
fn is_loopback(host: &IpAddr) -> bool {
    host.is_loopback()
}

pub async fn serve(config: ServeConfig) -> Result<()> {
    let addr = SocketAddr::new(config.host, config.port);
    validate(&config)?;
    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .with_context(|| format!("bind {addr}"))?;
    serve_with_listener(config, listener, None).await
}

/// Reject a configuration that would expose an unauthenticated agent to the
/// network: without a token, anyone who can reach the port runs commands as
/// this user.
fn validate(config: &ServeConfig) -> Result<()> {
    if config.no_auth && !is_loopback(&config.host) {
        anyhow::bail!(
            "refusing to disable authentication on a non-loopback address ({}); \
             a client of this gateway can run commands on this machine",
            config.host
        );
    }
    Ok(())
}

/// Serve on an already-bound listener.
///
/// Split out so tests can bind port 0 and learn the generated token via
/// `token_tx` without scraping stdout.
pub async fn serve_with_listener(
    config: ServeConfig,
    listener: tokio::net::TcpListener,
    token_tx: Option<tokio::sync::oneshot::Sender<Option<String>>>,
) -> Result<()> {
    validate(&config)?;

    let server_bin = match config.server_bin.clone() {
        Some(path) => path,
        None => std::env::current_exe().context("locate the running binary")?,
    };
    let token = (!config.no_auth).then(generate_token);
    let opencli_home = config.opencli_home.clone().unwrap_or_else(default_opencli_home);
    let state = Arc::new(GatewayState {
        token: token.clone(),
        server_bin: server_bin.clone(),
        opencli_home: opencli_home.clone(),
    });

    // One scheduler per gateway, not per connection: tasks must run whether or
    // not a UI is attached, and duplicating it per socket would run each task
    // once per open window.
    tokio::spawn(schedule::run_scheduler(
        opencli_home.clone(),
        server_bin.clone(),
    ));
    // The same reasoning applies to background runs: one worker per gateway,
    // or every open window would start the same queued task.
    tokio::spawn(dispatch::run_worker(opencli_home, server_bin));

    let app = Router::new()
        .route("/healthz", get(|| async { "ok" }))
        .route("/ws", get(ws_handler))
        .with_state(state);

    let bound = listener.local_addr().context("resolve bound address")?;
    match token.as_deref() {
        Some(token) => {
            println!("OpenCLI gateway listening on ws://{bound}/ws?token={token}");
            println!("Anyone with this URL can run commands on this machine.");
        }
        None => println!("OpenCLI gateway listening on ws://{bound}/ws (authentication disabled)"),
    }
    if let Some(tx) = token_tx {
        let _ = tx.send(token);
    }

    axum::serve(listener, app).await.context("serve")?;
    Ok(())
}

async fn ws_handler(
    State(state): State<Arc<GatewayState>>,
    Query(params): Query<ConnectParams>,
    upgrade: WebSocketUpgrade,
) -> impl IntoResponse {
    if let Some(expected) = state.token.as_deref() {
        // Compare full strings; these are single-use local tokens, and a
        // mismatch is answered identically either way.
        if params.token.as_deref() != Some(expected) {
            return (StatusCode::UNAUTHORIZED, "invalid or missing token").into_response();
        }
    }
    let state = Arc::clone(&state);
    upgrade
        .on_upgrade(move |socket| async move {
            if let Err(err) = bridge(socket, state).await {
                tracing::error!("gateway session ended with error: {err:#}");
            }
        })
        .into_response()
}

/// Relay one WebSocket connection to a dedicated app-server process.
///
/// Each connection gets its own process so one client's crash or shutdown
/// cannot disturb another's.
async fn bridge(socket: WebSocket, state: Arc<GatewayState>) -> Result<()> {
    let mut child = tokio::process::Command::new(&state.server_bin)
        .arg("app-server")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::inherit())
        .spawn()
        .with_context(|| format!("spawn {} app-server", state.server_bin.display()))?;

    let mut stdin = child.stdin.take().context("app-server stdin")?;
    let stdout = child.stdout.take().context("app-server stdout")?;

    let (mut ws_tx, mut ws_rx) = {
        use futures_lite_split::split;
        split(socket)
    };

    // app-server stdout -> websocket
    let (out_tx, mut out_rx) = mpsc::channel::<String>(64);
    // Kept for replies the gateway answers itself (scheduling), which must go
    // out on the same socket as the agent's own messages.
    let out_tx_for_local = out_tx.clone();
    let reader = tokio::spawn(async move {
        let mut lines = BufReader::new(stdout).lines();
        while let Ok(Some(line)) = lines.next_line().await {
            if out_tx.send(line).await.is_err() {
                break;
            }
        }
    });

    let forward = tokio::spawn(async move {
        while let Some(line) = out_rx.recv().await {
            if ws_tx.send(Message::Text(line.into())).await.is_err() {
                break;
            }
        }
    });

    // websocket -> app-server stdin
    while let Some(Ok(message)) = ws_rx.recv().await {
        let text = match message {
            Message::Text(text) => text.to_string(),
            Message::Close(_) => break,
            // Ping/pong are handled by axum; other frames are not part of the
            // line-delimited JSON protocol.
            _ => continue,
        };
        // Scheduling and projects are gateway concerns, not agent ones: both
        // outlive any single thread, and the app server is scoped to one
        // conversation. Answer those methods here instead of relaying them to
        // a server that has no notion of them.
        let handled = schedule::handle(&text, &state.opencli_home)
            .or_else(|| project::handle(&text, &state.opencli_home))
            .or_else(|| memory::handle(&text, &state.opencli_home))
            .or_else(|| dispatch::handle(&text, &state.opencli_home));
        if let Some(reply) = handled {
            if out_tx_for_local.send(reply).await.is_err() {
                break;
            }
            continue;
        }
        if stdin.write_all(text.as_bytes()).await.is_err() {
            break;
        }
        if stdin.write_all(b"\n").await.is_err() {
            break;
        }
        if stdin.flush().await.is_err() {
            break;
        }
    }

    // Dropping stdin signals EOF so the app server exits on its own.
    drop(stdin);
    let _ = child.wait().await;
    reader.abort();
    forward.abort();
    Ok(())
}

/// Minimal split shim so this file does not pull in `futures` just to halve a
/// socket.
mod dispatch;
mod memory;
mod project;
mod schedule;

mod futures_lite_split {
    use axum::extract::ws::Message;
    use axum::extract::ws::WebSocket;
    use tokio::sync::mpsc;

    pub struct Tx(mpsc::Sender<Message>);
    pub struct Rx(mpsc::Receiver<Result<Message, axum::Error>>);

    impl Tx {
        pub async fn send(&mut self, message: Message) -> Result<(), ()> {
            self.0.send(message).await.map_err(|_| ())
        }
    }
    impl Rx {
        pub async fn recv(&mut self) -> Option<Result<Message, axum::Error>> {
            self.0.recv().await
        }
    }

    /// Drive the socket from one task, exposing channel halves to the caller.
    pub fn split(socket: WebSocket) -> (Tx, Rx) {
        let (to_socket_tx, mut to_socket_rx) = mpsc::channel::<Message>(64);
        let (from_socket_tx, from_socket_rx) = mpsc::channel(64);
        tokio::spawn(async move {
            let mut socket = socket;
            loop {
                tokio::select! {
                    outgoing = to_socket_rx.recv() => {
                        let Some(message) = outgoing else { break };
                        if socket.send(message).await.is_err() {
                            break;
                        }
                    }
                    incoming = socket.recv() => {
                        let Some(incoming) = incoming else { break };
                        if from_socket_tx.send(incoming).await.is_err() {
                            break;
                        }
                    }
                }
            }
        });
        (Tx(to_socket_tx), Rx(from_socket_rx))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn should_generate_distinct_urlsafe_tokens() {
        let a = generate_token();
        let b = generate_token();
        assert_ne!(a, b);
        assert_eq!(a.len(), 32);
        assert!(a.chars().all(|c| c.is_ascii_alphanumeric()));
    }

    #[tokio::test]
    async fn should_refuse_unauthenticated_serving_on_a_public_address() {
        let err = serve(ServeConfig {
            host: "0.0.0.0".parse().expect("addr"),
            port: 0,
            server_bin: None,
            no_auth: true,
            opencli_home: None,
        })
        .await
        .expect_err("must refuse");
        assert!(
            err.to_string().contains("refusing to disable authentication"),
            "{err}"
        );
    }

    #[test]
    fn should_treat_only_loopback_as_local() {
        assert!(is_loopback(&"127.0.0.1".parse().expect("addr")));
        assert!(is_loopback(&"::1".parse().expect("addr")));
        assert!(!is_loopback(&"0.0.0.0".parse().expect("addr")));
        assert!(!is_loopback(&"192.168.1.5".parse().expect("addr")));
    }
}
