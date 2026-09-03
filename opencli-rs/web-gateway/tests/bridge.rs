//! Gateway bridge tests.
//!
//! These drive the real WebSocket server against a stand-in "app server" so the
//! relay is exercised without needing a model provider: the bridge's job is to
//! move newline-delimited JSON in both directions, and that is what is asserted
//! here.

#![allow(clippy::expect_used)]

use opencli_web_gateway::ServeConfig;
use opencli_web_gateway::serve_with_listener;
use std::net::SocketAddr;
use std::time::Duration;

/// A script that echoes each line back with a marker, standing in for
/// `opencli app-server`.
fn echo_server_script(dir: &std::path::Path) -> std::path::PathBuf {
    let path = dir.join("echo-server");
    std::fs::write(
        &path,
        "#!/bin/sh\n\
         # Ignore the `app-server` argument the gateway passes.\n\
         while IFS= read -r line; do printf 'echoed:%s\\n' \"$line\"; done\n",
    )
    .expect("write script");
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o755))
            .expect("chmod script");
    }
    path
}

async fn start_gateway(no_auth: bool) -> (SocketAddr, Option<String>, tempfile::TempDir) {
    let dir = tempfile::tempdir().expect("tempdir");
    let script = echo_server_script(dir.path());
    let dir_path = dir.path().to_path_buf();
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0")
        .await
        .expect("bind");
    let addr = listener.local_addr().expect("addr");

    let (token_tx, token_rx) = tokio::sync::oneshot::channel();
    tokio::spawn(async move {
        let _ = serve_with_listener(
            ServeConfig {
                host: addr.ip(),
                port: addr.port(),
                server_bin: Some(script),
                no_auth,
                opencli_home: Some(dir_path.clone()),
            },
            listener,
            Some(token_tx),
        )
        .await;
    });
    let token = token_rx.await.expect("token published");
    (addr, token, dir)
}

#[tokio::test]
async fn should_relay_messages_between_websocket_and_the_app_server() {
    let (addr, token, _dir) = start_gateway(false).await;
    let token = token.expect("token when auth is enabled");
    let url = format!("ws://{addr}/ws?token={token}");

    let (mut socket, _) = tokio_tungstenite::connect_async(&url)
        .await
        .expect("connect");

    use futures::SinkExt;
    use futures::StreamExt;
    socket
        .send(tokio_tungstenite::tungstenite::Message::Text(
            r#"{"method":"ping","id":1}"#.into(),
        ))
        .await
        .expect("send");

    let reply = tokio::time::timeout(Duration::from_secs(10), socket.next())
        .await
        .expect("no timeout")
        .expect("stream open")
        .expect("frame");

    let text = reply.into_text().expect("text frame");
    assert_eq!(
        text.trim(),
        r#"echoed:{"method":"ping","id":1}"#,
        "the bridge must deliver the line verbatim and return the reply"
    );
}

#[tokio::test]
async fn should_reject_a_connection_without_the_token() {
    let (addr, _token, _dir) = start_gateway(false).await;

    let result = tokio_tungstenite::connect_async(format!("ws://{addr}/ws")).await;

    assert!(
        result.is_err(),
        "an unauthenticated connection must be refused"
    );
}

#[tokio::test]
async fn should_allow_connections_when_auth_is_disabled_on_loopback() {
    let (addr, token, _dir) = start_gateway(true).await;
    assert!(token.is_none(), "no token is issued when auth is disabled");

    let result = tokio_tungstenite::connect_async(format!("ws://{addr}/ws")).await;

    assert!(result.is_ok(), "loopback with --no-auth should connect");
}
