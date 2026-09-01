//! Gateway-side model runtime management.
//!
//! Listing, installing and removing models on a runtime — the one under this
//! desk or one on a machine elsewhere. Ollama's management API is plain HTTP,
//! which is what makes "install this model on the server" possible without a
//! shell there.
//!
//! Installing streams: a model is gigabytes and takes minutes, so progress is
//! pushed as notifications while it runs rather than held until it finishes.
//! Every other method answers in one reply.

use opencli_core::runtimes;
use serde_json::Value;
use serde_json::json;
use std::time::Duration;
use tokio::sync::mpsc::Sender;

/// Answer a `runtime/*` request that needs no streaming.
///
/// Returns `None` for anything else, including `runtime/pull`, which is
/// handled separately because it reports as it goes.
pub async fn handle(raw: &str, opencli_home: &std::path::Path) -> Option<String> {
    let message: Value = serde_json::from_str(raw).ok()?;
    let method = message.get("method")?.as_str()?;
    if !method.starts_with("runtime/") || method == "runtime/pull" {
        return None;
    }
    let id = message.get("id").cloned().unwrap_or(Value::Null);
    let params = message.get("params").cloned().unwrap_or(json!({}));

    let result = match method {
        "runtime/list" => Ok(list()),
        "runtime/probe" => probe(&params).await,
        "runtime/discover" => Ok(discover().await),
        "runtime/models" => models(&params).await,
        "runtime/show" => show(&params).await,
        "runtime/delete" => delete(&params, opencli_home).await,
        "runtime/register" => register_model(&params, opencli_home).await,
        _ => Err(format!("unknown method `{method}`")),
    };

    Some(match result {
        Ok(value) => json!({ "id": id, "result": value }).to_string(),
        Err(message) => {
            json!({ "id": id, "error": { "code": -32602, "message": message } }).to_string()
        }
    })
}

/// The runtimes this build knows about, and what each can be asked to do.
fn list() -> Value {
    let data: Vec<Value> = runtimes::RUNTIMES
        .iter()
        .map(|runtime| {
            json!({
                "id": runtime.id,
                "name": runtime.name,
                "defaultPort": runtime.default_port,
                "acquisition": runtime.acquisition,
                "servesFilesDirectly": runtime.serves_files_directly,
                "listsModels": runtime.lists_models,
                "deletesModels": runtime.deletes_models,
                "canDownloadRemotely": runtimes::can_download_remotely(runtime),
                "remoteNote": runtime.remote_note,
                "docs": runtime.docs,
            })
        })
        .collect();
    json!({ "data": data })
}

/// Strip a trailing `/v1`, which a provider URL carries and the management
/// API does not.
fn management_root(base_url: &str) -> String {
    base_url
        .trim_end_matches('/')
        .trim_end_matches("/v1")
        .trim_end_matches('/')
        .to_string()
}

fn required_url(params: &Value) -> Result<String, String> {
    let url = params
        .get("baseUrl")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|url| !url.is_empty())
        .ok_or("baseUrl is required")?;
    if !url.starts_with("http://") && !url.starts_with("https://") {
        return Err("baseUrl must start with http:// or https://".to_string());
    }
    Ok(management_root(url))
}

fn client() -> reqwest::Client {
    reqwest::Client::builder()
        // Long enough for a slow link, short enough that an unreachable host
        // reports rather than hanging the panel.
        .timeout(Duration::from_secs(30))
        .build()
        .unwrap_or_default()
}

/// Ask a URL what is there.
///
/// Reports *why* it could not be reached, because the three reasons need
/// different fixes: nothing listening, something listening that is not a
/// runtime, or a gateway that answered for a backend that is down.
async fn probe(params: &Value) -> Result<Value, String> {
    let root = required_url(params)?;
    let response = client()
        .get(format!("{root}/api/version"))
        .send()
        .await
        .map_err(|err| {
            format!("could not reach it: {}", err.without_url_noise())
        })?;

    let status = response.status();
    if !status.is_success() {
        // 502 from a tunnel means the tunnel is up and the runtime behind it
        // is not — a server problem, not a network one, and worth saying so.
        let hint = if status.as_u16() == 502 || status.as_u16() == 503 {
            " — something is answering at that address, but the runtime behind it is not running"
        } else {
            ""
        };
        return Ok(json!({
            "reachable": false,
            "status": status.as_u16(),
            "detail": format!("HTTP {status}{hint}"),
        }));
    }

    let body: Value = response.json().await.map_err(|_| {
        "something answered, but not a model runtime".to_string()
    })?;
    let Some(version) = body.get("version").and_then(Value::as_str) else {
        return Err("something answered, but not a model runtime".to_string());
    };

    Ok(json!({
        "reachable": true,
        "version": version,
        "isLocal": runtimes::is_local(&root),
    }))
}

/// Look for runtimes on this machine.
///
/// Probed in parallel: four ports one after another is four timeouts on a
/// machine with none, which is long enough to look broken.
///
/// A port that answers but is not a runtime is reported as such rather than
/// skipped — port 8000 in particular is often something else entirely, and
/// silence there reads as "nothing found" when the truth is "something else is
/// using it".
async fn discover() -> Value {
    let candidates: Vec<(&str, &str, u16)> = runtimes::RUNTIMES
        .iter()
        .map(|runtime| (runtime.id, runtime.name, runtime.default_port))
        .collect();

    let checks = candidates.into_iter().map(|(id, name, port)| async move {
        let base = format!("http://localhost:{port}");
        // Short: this runs on every visit to the panel, and a runtime on this
        // machine answers immediately or not at all.
        let client = match reqwest::Client::builder()
            .timeout(Duration::from_millis(1200))
            .build()
        {
            Ok(client) => client,
            Err(_) => return None,
        };

        // Ollama says its version here; the others only speak the OpenAI
        // surface, so both are tried before deciding nothing is there.
        if let Ok(response) = client.get(format!("{base}/api/version")).send().await
            && response.status().is_success()
            && let Ok(body) = response.json::<Value>().await
            && let Some(version) = body.get("version").and_then(Value::as_str)
        {
            return Some(json!({
                "runtime": id,
                "name": name,
                "baseUrl": base,
                "version": version,
                "manageable": true,
            }));
        }

        match client.get(format!("{base}/v1/models")).send().await {
            Ok(response) if response.status().is_success() => Some(json!({
                "runtime": id,
                "name": name,
                "baseUrl": base,
                "version": Value::Null,
                // It serves models but cannot be told to fetch them.
                "manageable": false,
            })),
            _ => None,
        }
    });

    let found: Vec<Value> = futures::future::join_all(checks)
        .await
        .into_iter()
        .flatten()
        .collect();
    json!({ "data": found })
}

/// Models installed on a runtime.
async fn models(params: &Value) -> Result<Value, String> {
    let root = required_url(params)?;
    let response = client()
        .get(format!("{root}/api/tags"))
        .send()
        .await
        .map_err(|err| format!("could not reach it: {}", err.without_url_noise()))?;
    if !response.status().is_success() {
        return Err(format!("the runtime answered {}", response.status()));
    }
    let body: Value = response
        .json()
        .await
        .map_err(|_| "the runtime's reply was not readable".to_string())?;

    let data: Vec<Value> = body
        .get("models")
        .and_then(Value::as_array)
        .map(|models| {
            models
                .iter()
                .map(|model| {
                    let details = model.get("details").cloned().unwrap_or(json!({}));
                    json!({
                        "name": model.get("name").and_then(Value::as_str).unwrap_or(""),
                        "size": model.get("size").and_then(Value::as_u64).unwrap_or(0),
                        "parameterSize": details.get("parameter_size"),
                        "quantization": details.get("quantization_level"),
                        "family": details.get("family"),
                        "modifiedAt": model.get("modified_at"),
                    })
                })
                .collect()
        })
        .unwrap_or_default();
    Ok(json!({ "data": data }))
}

/// What a model can do, which is what decides whether it is usable here.
///
/// A model that cannot call tools is close to useless for this product, so the
/// capability list is the point of this call, not a decoration.
async fn show(params: &Value) -> Result<Value, String> {
    let root = required_url(params)?;
    let model = params
        .get("model")
        .and_then(Value::as_str)
        .filter(|model| !model.is_empty())
        .ok_or("model is required")?;

    let response = client()
        .post(format!("{root}/api/show"))
        .json(&json!({ "model": model }))
        .send()
        .await
        .map_err(|err| format!("could not reach it: {}", err.without_url_noise()))?;
    if !response.status().is_success() {
        return Err(format!("the runtime answered {}", response.status()));
    }
    let body: Value = response
        .json()
        .await
        .map_err(|_| "the runtime's reply was not readable".to_string())?;

    let capabilities = body
        .get("capabilities")
        .and_then(Value::as_array)
        .map(|values| {
            values
                .iter()
                .filter_map(Value::as_str)
                .map(str::to_string)
                .collect::<Vec<_>>()
        })
        .unwrap_or_default();

    // The context length key is named after the architecture, so it has to be
    // found rather than looked up.
    let context = body
        .get("model_info")
        .and_then(Value::as_object)
        .and_then(|info| {
            info.iter()
                .find(|(key, _)| key.ends_with(".context_length"))
                .and_then(|(_, value)| value.as_u64())
        });

    Ok(json!({
        "model": model,
        "capabilities": capabilities,
        "supportsTools": capabilities.iter().any(|c| c == "tools"),
        "contextLength": context,
        "details": body.get("details").cloned().unwrap_or(json!({})),
    }))
}

/// Make an installed model selectable.
///
/// Installing puts a file on a machine; being able to choose it needs a
/// provider and a `[[models]]` entry too. Doing it here means a one-click
/// install is actually one click, rather than one click and a text editor.
async fn register_model(params: &Value, opencli_home: &std::path::Path) -> Result<Value, String> {
    let root = required_url(params)?;
    let model = params
        .get("model")
        .and_then(Value::as_str)
        .filter(|model| !model.is_empty())
        .ok_or("model is required")?;

    // Read the window from the runtime rather than guessing: a wrong one
    // truncates conversations or overflows the model.
    let context = match show(params).await {
        Ok(details) => details.get("contextLength").and_then(Value::as_i64),
        Err(_) => None,
    };
    crate::register::register(opencli_home, &root, model, None, context)
}

async fn delete(params: &Value, opencli_home: &std::path::Path) -> Result<Value, String> {
    let root = required_url(params)?;
    let model = params
        .get("model")
        .and_then(Value::as_str)
        .filter(|model| !model.is_empty())
        .ok_or("model is required")?;

    let response = client()
        .delete(format!("{root}/api/delete"))
        .json(&json!({ "model": model }))
        .send()
        .await
        .map_err(|err| format!("could not reach it: {}", err.without_url_noise()))?;

    if response.status().as_u16() == 404 {
        return Err(format!("`{model}` is not installed there"));
    }
    if !response.status().is_success() {
        return Err(format!("the runtime answered {}", response.status()));
    }

    // Leaving the entry behind would keep offering a model that is gone.
    let unregistered = crate::register::unregister(opencli_home, &root, model)
        .map(|result| result["removed"].as_bool().unwrap_or(false))
        .unwrap_or(false);
    Ok(json!({ "removed": model, "unregistered": unregistered }))
}

/// Install a model, reporting as it goes.
///
/// Answers the request immediately and pushes `runtime/pull/progress`
/// notifications until it finishes. A model is gigabytes; holding the reply
/// until the end would look like the app had frozen.
pub async fn pull(raw: &str, out: Sender<String>) -> bool {
    let Ok(message) = serde_json::from_str::<Value>(raw) else {
        return false;
    };
    if message.get("method").and_then(Value::as_str) != Some("runtime/pull") {
        return false;
    }
    let id = message.get("id").cloned().unwrap_or(Value::Null);
    let params = message.get("params").cloned().unwrap_or(json!({}));

    let root = match required_url(&params) {
        Ok(root) => root,
        Err(err) => {
            let _ = out
                .send(json!({ "id": id, "error": { "code": -32602, "message": err } }).to_string())
                .await;
            return true;
        }
    };
    let Some(model) = params
        .get("model")
        .and_then(Value::as_str)
        .filter(|model| !model.is_empty())
        .map(str::to_string)
    else {
        let _ = out
            .send(
                json!({ "id": id, "error": { "code": -32602, "message": "model is required" } })
                    .to_string(),
            )
            .await;
        return true;
    };

    // Acknowledge before the work starts, so the client can show a row for it.
    let _ = out
        .send(json!({ "id": id, "result": { "started": model } }).to_string())
        .await;

    tokio::spawn(async move {
        stream_pull(&root, &model, out).await;
    });
    true
}

async fn notify(out: &Sender<String>, model: &str, body: Value) {
    let mut params = body;
    if let Some(object) = params.as_object_mut() {
        object.insert("model".to_string(), json!(model));
    }
    let _ = out
        .send(json!({ "method": "runtime/pull/progress", "params": params }).to_string())
        .await;
}

async fn stream_pull(root: &str, model: &str, out: Sender<String>) {
    // No overall timeout: a large model over a slow link legitimately takes
    // an hour, and cutting it off would waste everything downloaded so far.
    let client = match reqwest::Client::builder()
        .connect_timeout(Duration::from_secs(20))
        .build()
    {
        Ok(client) => client,
        Err(err) => {
            notify(&out, model, json!({ "error": err.to_string() })).await;
            return;
        }
    };

    let response = match client
        .post(format!("{root}/api/pull"))
        .json(&json!({ "model": model, "stream": true }))
        .send()
        .await
    {
        Ok(response) => response,
        Err(err) => {
            notify(
                &out,
                model,
                json!({ "error": format!("could not reach it: {}", err.without_url_noise()) }),
            )
            .await;
            return;
        }
    };

    if !response.status().is_success() {
        notify(
            &out,
            model,
            json!({ "error": format!("the runtime answered {}", response.status()) }),
        )
        .await;
        return;
    }

    let mut stream = response.bytes_stream();
    let mut buffer = String::new();
    use futures::StreamExt;

    while let Some(chunk) = stream.next().await {
        let chunk = match chunk {
            Ok(chunk) => chunk,
            Err(err) => {
                notify(&out, model, json!({ "error": err.to_string() })).await;
                return;
            }
        };
        buffer.push_str(&String::from_utf8_lossy(&chunk));

        // Progress arrives as one JSON object per line, and a chunk can split
        // one in half — so only whole lines are parsed.
        while let Some(newline) = buffer.find('\n') {
            let line: String = buffer.drain(..=newline).collect();
            let line = line.trim();
            if line.is_empty() {
                continue;
            }
            let Ok(event) = serde_json::from_str::<Value>(line) else {
                continue;
            };

            // Ollama reports a failed pull inside a 200 response, so the
            // stream is what says whether it worked, not the status code.
            if let Some(error) = event.get("error").and_then(Value::as_str) {
                notify(&out, model, json!({ "error": error })).await;
                return;
            }

            let status = event.get("status").and_then(Value::as_str).unwrap_or("");
            notify(
                &out,
                model,
                json!({
                    "status": status,
                    "completed": event.get("completed"),
                    "total": event.get("total"),
                    "done": status == "success",
                }),
            )
            .await;

            if status == "success" {
                return;
            }
        }
    }

    // The stream ended without saying it succeeded — a dropped connection
    // mid-download. Say so rather than leaving a row spinning forever.
    notify(
        &out,
        model,
        json!({ "error": "the connection ended before the download finished" }),
    )
    .await;
}

/// Trim the URL that `reqwest` repeats in every error, which is noise once the
/// message already names what was being reached.
trait WithoutUrlNoise {
    fn without_url_noise(&self) -> String;
}

impl WithoutUrlNoise for reqwest::Error {
    fn without_url_noise(&self) -> String {
        let text = self.to_string();
        match text.split_once(" for url (") {
            Some((head, _)) => head.to_string(),
            None => text,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn should_pass_non_runtime_methods_through_to_the_agent() {
        let dir = tempfile::tempdir().expect("tempdir");
        assert!(handle(r#"{"method":"turn/start","id":1}"#, dir.path()).await.is_none());
        assert!(handle("not json", dir.path()).await.is_none());
    }

    #[tokio::test]
    async fn should_leave_pull_to_the_streaming_path() {
        // Answering it here would hold the reply for the whole download.
        assert!(
            handle(r#"{"method":"runtime/pull","id":1,"params":{}}"#, std::path::Path::new("/tmp"))
                .await
                .is_none()
        );
    }

    #[tokio::test]
    async fn should_describe_every_runtime_and_whether_it_can_be_driven_remotely() {
        let reply = handle(r#"{"method":"runtime/list","id":1}"#, std::path::Path::new("/tmp"))
            .await
            .expect("handled");
        let parsed: Value = serde_json::from_str(&reply).expect("valid JSON");
        let rows = parsed["result"]["data"].as_array().expect("data");
        assert_eq!(rows.len(), 4);

        let ollama = rows
            .iter()
            .find(|row| row["id"] == "ollama")
            .expect("ollama is described");
        assert_eq!(ollama["canDownloadRemotely"], true);

        for row in rows {
            assert!(
                !row["remoteNote"].as_str().unwrap_or("").is_empty(),
                "{} must say what to do on another machine",
                row["id"]
            );
        }
    }

    #[test]
    fn should_strip_the_v1_a_provider_url_carries() {
        // A provider is configured as `.../v1`; the management API is not
        // under it, and asking for `/v1/api/tags` would 404 forever.
        assert_eq!(management_root("http://localhost:11434/v1"), "http://localhost:11434");
        assert_eq!(management_root("https://llm.example.com/v1/"), "https://llm.example.com");
        assert_eq!(management_root("http://localhost:11434"), "http://localhost:11434");
    }

    #[tokio::test]
    async fn should_refuse_an_address_that_is_not_a_url() {
        for params in [r#"{}"#, r#"{"baseUrl":"gpu-box:11434"}"#, r#"{"baseUrl":""}"#] {
            let reply = handle(
                &format!(r#"{{"method":"runtime/models","id":1,"params":{params}}}"#),
                std::path::Path::new("/tmp"),
            )
            .await
            .expect("handled");
            let parsed: Value = serde_json::from_str(&reply).expect("valid JSON");
            assert!(parsed["error"].is_object(), "{params} should be refused");
        }
    }

    #[tokio::test]
    async fn should_find_nothing_quickly_when_no_runtime_is_local() {
        // This runs on every visit to the panel; four timeouts in sequence
        // would be long enough to look broken.
        let started = std::time::Instant::now();
        let reply = handle(r#"{"method":"runtime/discover","id":1}"#, std::path::Path::new("/tmp"))
            .await
            .expect("handled");
        let parsed: Value = serde_json::from_str(&reply).expect("valid JSON");
        assert!(parsed["result"]["data"].is_array());
        assert!(
            started.elapsed() < std::time::Duration::from_secs(4),
            "took {:?}; the probes must run together",
            started.elapsed()
        );
    }

    #[tokio::test]
    async fn should_report_an_unreachable_host_rather_than_hanging() {
        // Port 1 is reserved and nothing listens there.
        let reply = handle(
            r#"{"method":"runtime/probe","id":1,"params":{"baseUrl":"http://127.0.0.1:1"}}"#,
            std::path::Path::new("/tmp"),
        )
        .await
        .expect("handled");
        let parsed: Value = serde_json::from_str(&reply).expect("valid JSON");
        assert!(
            parsed["error"]["message"]
                .as_str()
                .is_some_and(|message| message.contains("could not reach")),
            "got {parsed}"
        );
    }
}
