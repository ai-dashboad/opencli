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

/// Ask the OS for one or more files, returning their paths.
///
/// The browser gives a `File` with no path, so a file can only be referenced —
/// rather than inlined — when the host supplies one.
#[tauri::command]
fn choose_files() -> Result<Vec<String>, String> {
    #[cfg(target_os = "macos")]
    {
        // `with multiple selections allowed` returns a list; joining on a
        // newline keeps paths intact, which a comma would not.
        let script = "set chosen to choose file with multiple selections allowed\n\
                      set out to \"\"\n\
                      repeat with f in chosen\n\
                      set out to out & POSIX path of f & linefeed\n\
                      end repeat\n\
                      return out";
        let output = std::process::Command::new("osascript")
            .arg("-e")
            .arg(script)
            .output()
            .map_err(|err| format!("could not open the file chooser: {err}"))?;
        if !output.status.success() {
            // A cancelled dialog exits non-zero; that is not an error.
            return Ok(Vec::new());
        }
        return Ok(String::from_utf8_lossy(&output.stdout)
            .lines()
            .map(str::trim)
            .filter(|path| !path.is_empty())
            .map(str::to_string)
            .collect());
    }

    #[cfg(not(target_os = "macos"))]
    Ok(Vec::new())
}

/// The version this app was built as, for the UI to show and compare.
///
/// Read from the crate rather than passed in from the frontend: the web build
/// and the desktop build share a bundle, and only one of them is a release with
/// a version at all.
#[tauri::command]
fn app_version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

/// A release newer than the running one, if there is one.
#[derive(serde::Serialize)]
struct Available {
    version: String,
    notes: Option<String>,
}

/// Ask the release feed whether there is a newer version.
///
/// Driven from Rust rather than from the frontend's plugin bindings: installing
/// reports progress over a Tauri channel, and hand-rolling that from a page
/// with no `@tauri-apps` packages is more moving parts than the three commands
/// here. It also keeps the window's granted capabilities down to what it
/// actually uses.
#[tauri::command]
async fn check_update(app: tauri::AppHandle) -> Result<Option<Available>, String> {
    use tauri_plugin_updater::UpdaterExt;
    let updater = app.updater().map_err(|err| err.to_string())?;
    let update = updater.check().await.map_err(|err| err.to_string())?;
    Ok(update.map(|update| Available {
        version: update.version.clone(),
        notes: update.body.clone(),
    }))
}

/// Download and install the newer version, reporting progress as it goes.
///
/// The app is not restarted here. Replacing itself under a conversation the
/// user is in the middle of is the wrong moment to choose for them, so the
/// frontend offers the restart and waits.
#[tauri::command]
async fn install_update(app: tauri::AppHandle) -> Result<(), String> {
    use tauri::Emitter;
    use tauri_plugin_updater::UpdaterExt;

    let updater = app.updater().map_err(|err| err.to_string())?;
    let Some(update) = updater.check().await.map_err(|err| err.to_string())? else {
        return Err("there is no update to install".to_string());
    };

    let progress = app.clone();
    let mut downloaded = 0usize;
    update
        .download_and_install(
            move |chunk, total| {
                downloaded += chunk;
                // A download with no declared length reports `None`; the UI
                // shows an indeterminate bar rather than inventing a fraction.
                let _ = progress.emit("update://progress", (downloaded as u64, total));
            },
            || {},
        )
        .await
        .map_err(|err| err.to_string())?;
    Ok(())
}

/// Show a file the agent wrote in the platform's file manager.
///
/// Selecting the file rather than opening it: the question behind the button is
/// "where did that go", and opening a file in whatever is registered for its
/// extension answers a different one.
#[tauri::command]
fn reveal_path(path: String) -> Result<(), String> {
    let mut command = if cfg!(target_os = "macos") {
        let mut command = std::process::Command::new("open");
        command.arg("-R").arg(&path);
        command
    } else if cfg!(target_os = "windows") {
        let mut command = std::process::Command::new("explorer");
        command.arg(format!("/select,{path}"));
        command
    } else {
        // No portable "select this file" on Linux; the folder it is in is the
        // closest thing every desktop environment agrees on.
        let parent = std::path::Path::new(&path)
            .parent()
            .map(|dir| dir.to_string_lossy().into_owned())
            .unwrap_or_else(|| path.clone());
        let mut command = std::process::Command::new("xdg-open");
        command.arg(parent);
        command
    };
    command
        .spawn()
        .map(|_| ())
        .map_err(|err| format!("could not show {path}: {err}"))
}

/// Restart into the version that was just installed.
#[tauri::command]
fn restart_app(app: tauri::AppHandle) {
    app.restart();
}

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_updater::Builder::new().build())
        .manage(GatewayUrl::default())
        .invoke_handler(tauri::generate_handler![
            gateway_url,
            default_cwd,
            choose_directory,
            choose_files,
            app_version,
            check_update,
            install_update,
            restart_app,
            reveal_path
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
