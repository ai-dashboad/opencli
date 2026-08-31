// Release builds must not pop a console window on Windows.
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

//! OpenCLI desktop client.
//!
//! The window renders the same UI the browser build serves; the difference is
//! that the agent gateway runs in-process here. On startup the app binds a
//! loopback port, starts the WebSocket gateway from `opencli-web-gateway`, and
//! hands the resulting URL (including its one-time token) to the frontend over
//! Tauri IPC. Nothing is exposed beyond loopback, and the token still gates the
//! socket, so a stray page in a browser cannot drive the agent.

use std::path::PathBuf;
use std::sync::Mutex;
use tauri::Manager;

/// The gateway endpoint, published once the listener is bound.
#[derive(Default)]
struct GatewayUrl(Mutex<Option<String>>);

/// Locate the `opencli` binary that backs the agent.
///
/// Checked in order: alongside this executable (how a bundled app ships it),
/// then `PATH` (how a developer runs it from a source checkout). Returning an
/// error here is better than starting a window that fails on first message.
fn locate_opencli() -> anyhow::Result<PathBuf> {
    let exe = std::env::current_exe()?;
    if let Some(dir) = exe.parent() {
        let sibling = dir.join(if cfg!(windows) { "opencli.exe" } else { "opencli" });
        if sibling.is_file() {
            return Ok(sibling);
        }
    }
    which_on_path("opencli").ok_or_else(|| {
        anyhow::anyhow!(
            "could not find the `opencli` binary next to this app or on PATH; \
             build it with `cargo build --release -p opencli-cli --bin opencli`"
        )
    })
}

fn which_on_path(name: &str) -> Option<PathBuf> {
    let path = std::env::var_os("PATH")?;
    std::env::split_paths(&path)
        .map(|dir| dir.join(name))
        .find(|candidate| candidate.is_file())
}

/// Frontend entry point: where to connect, token included.
#[tauri::command]
fn gateway_url(state: tauri::State<'_, GatewayUrl>) -> Result<String, String> {
    state
        .0
        .lock()
        .map_err(|_| "gateway state poisoned".to_string())?
        .clone()
        .ok_or_else(|| "the agent gateway is still starting".to_string())
}

/// Directory the agent should start in.
///
/// A desktop launch has no shell to inherit a working directory from, and an
/// app that opens onto a form asking for a path is not usable. Home is a safe,
/// always-valid default; the user can change it in the UI.
#[tauri::command]
fn default_cwd() -> String {
    std::env::var("HOME")
        .ok()
        .filter(|home| !home.is_empty())
        .unwrap_or_else(|| "/".to_string())
}

/// Ask the OS for a directory, returning `None` if the user cancelled.
///
/// Deliberately shells out to the platform's own chooser rather than taking a
/// dialog dependency: adding one forces this crate's lock file to be
/// re-resolved, and resolving it independently of the main workspace picks
/// versions of shared transitive dependencies that do not compile together.
///
/// Unsupported platforms return `None`, which leaves the typed path in place
/// rather than blocking the user.
#[tauri::command]
fn choose_directory(start: Option<String>) -> Result<Option<String>, String> {
    #[cfg(target_os = "macos")]
    {
        // `POSIX path of` yields a plain path; without it AppleScript returns
        // an HFS-style alias with colons, which is not a usable cwd.
        let script = match start.as_deref().filter(|path| !path.is_empty()) {
            Some(path) => format!(
                "POSIX path of (choose folder default location POSIX file \"{}\")",
                path.replace('"', "")
            ),
            None => "POSIX path of (choose folder)".to_string(),
        };
        let output = std::process::Command::new("osascript")
            .arg("-e")
            .arg(&script)
            .output()
            .map_err(|err| format!("could not open the folder chooser: {err}"))?;
        if !output.status.success() {
            // A cancelled dialog exits non-zero; that is not an error.
            return Ok(None);
        }
        let path = String::from_utf8_lossy(&output.stdout).trim().to_string();
        return Ok(if path.is_empty() { None } else { Some(path) });
    }

    #[cfg(not(target_os = "macos"))]
    {
        let _ = start;
        Ok(None)
    }
}

fn main() {
    tauri::Builder::default()
        .manage(GatewayUrl::default())
        .invoke_handler(tauri::generate_handler![
            gateway_url,
            default_cwd,
            choose_directory
        ])
        .setup(|app| {
            let handle = app.handle().clone();
            let server_bin = locate_opencli()?;

            tauri::async_runtime::spawn(async move {
                // Port 0: let the OS pick, so two instances cannot collide.
                let listener = match tokio::net::TcpListener::bind("127.0.0.1:0").await {
                    Ok(listener) => listener,
                    Err(err) => {
                        tracing::error!("could not bind a local port for the gateway: {err}");
                        return;
                    }
                };
                let addr = match listener.local_addr() {
                    Ok(addr) => addr,
                    Err(err) => {
                        tracing::error!("could not resolve the gateway address: {err}");
                        return;
                    }
                };

                let (token_tx, token_rx) = tokio::sync::oneshot::channel();
                let config = opencli_web_gateway::ServeConfig {
                    host: addr.ip(),
                    port: addr.port(),
                    server_bin: Some(server_bin),
                    no_auth: false,
                    opencli_home: None,
                };

                let publisher = handle.clone();
                tauri::async_runtime::spawn(async move {
                    if let Ok(Some(token)) = token_rx.await {
                        let url = format!("ws://{addr}/ws?token={token}");
                        if let Some(state) = publisher.try_state::<GatewayUrl>() {
                            if let Ok(mut slot) = state.0.lock() {
                                *slot = Some(url);
                            }
                        }
                    }
                });

                if let Err(err) =
                    opencli_web_gateway::serve_with_listener(config, listener, Some(token_tx)).await
                {
                    tracing::error!("gateway stopped: {err:#}");
                }
            });
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running the OpenCLI desktop app");
}
