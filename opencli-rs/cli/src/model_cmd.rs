//! `opencli model probe` — find out what a model can actually do.
//!
//! A `[[models]]` entry carries a context window, a tool-calling expectation,
//! and a set of reasoning efforts. For a hosted frontier model those are
//! published; for a local GGUF served by Ollama or llama.cpp they are not, and
//! guessing them is worse than not setting them — an over-large context window
//! means the gateway rejects turns instead of auto-compacting.
//!
//! So ask the server. Runtimes that expose a native metadata endpoint (Ollama's
//! `/api/show`) answer authoritatively in one request; otherwise fall back to
//! exercising the OpenAI-compatible endpoint and observing what comes back.

use anyhow::Context;
use anyhow::Result;
use anyhow::bail;
use clap::Args;
use clap::Subcommand;
use opencli_core::config::CONFIG_TOML_FILE;
use opencli_core::config::find_opencli_home;
use std::path::Path;
use std::time::Duration;

const REQUEST_TIMEOUT: Duration = Duration::from_secs(60);

#[derive(Debug, Args)]
pub struct ModelArgs {
    #[command(subcommand)]
    pub cmd: ModelSubcommand,
}

#[derive(Debug, Subcommand)]
pub enum ModelSubcommand {
    /// Detect a model's capabilities and record them in config.toml.
    Probe {
        /// Model slug, as it appears in `[[models]]`.
        slug: String,
        /// Report findings without changing config.toml.
        #[arg(long)]
        dry_run: bool,
    },
}

/// What a probe established about a model.
#[derive(Debug, Default, PartialEq)]
struct Capabilities {
    context_window: Option<i64>,
    supports_tools: Option<bool>,
    /// The model emits its thinking in a separate `reasoning` field rather than
    /// inline in `content` (common for Qwen3-family models on Ollama).
    separate_reasoning: Option<bool>,
}

pub async fn run_main(args: ModelArgs) -> Result<()> {
    let home = find_opencli_home().context("resolve config home")?;
    let path = home.join(CONFIG_TOML_FILE);
    match args.cmd {
        ModelSubcommand::Probe { slug, dry_run } => probe(&path, &slug, dry_run).await,
    }
}

/// Resolve a declared model to the base URL and key that serve it.
fn resolve_endpoint(doc: &toml_edit::DocumentMut, slug: &str) -> Result<(String, Option<String>)> {
    let provider_id = doc
        .get("models")
        .and_then(|item| item.as_array_of_tables())
        .and_then(|models| {
            models
                .iter()
                .find(|entry| entry.get("model").and_then(|v| v.as_str()) == Some(slug))
                .and_then(|entry| entry.get("provider").and_then(|v| v.as_str()))
                .map(str::to_string)
        })
        .with_context(|| {
            format!(
                "`{slug}` is not declared in config.toml; add a [[models]] entry \
                 or run `opencli provider scan` first"
            )
        })?;

    let provider = doc
        .get("model_providers")
        .and_then(|item| item.as_table_like())
        .and_then(|table| table.get(&provider_id))
        .with_context(|| format!("provider `{provider_id}` is not defined in config.toml"))?;

    let base_url = provider
        .get("base_url")
        .and_then(|v| v.as_str())
        .with_context(|| format!("provider `{provider_id}` has no base_url"))?
        .trim_end_matches('/')
        .to_string();

    let api_key = provider
        .get("env_key")
        .and_then(|v| v.as_str())
        .and_then(|key| std::env::var(key).ok())
        .filter(|value| !value.trim().is_empty());

    Ok((base_url, api_key))
}

/// Ask Ollama's native metadata endpoint, which reports the real context length
/// and capability list without inference. Returns `None` for other runtimes.
async fn probe_ollama_metadata(base_url: &str, slug: &str) -> Option<Capabilities> {
    // `/v1` is the OpenAI-compatible surface; the native API sits beside it.
    let root = base_url.trim_end_matches("/v1");
    let response = opencli_core::default_client::build_reqwest_client()
        .post(format!("{root}/api/show"))
        .json(&serde_json::json!({ "model": slug }))
        .timeout(Duration::from_secs(10))
        .send()
        .await
        .ok()?;
    if !response.status().is_success() {
        return None;
    }
    let body: serde_json::Value = response.json().await.ok()?;

    // The key is namespaced by architecture, e.g. `qwen2.context_length`.
    let context_window = body.get("model_info").and_then(|info| {
        info.as_object()?
            .iter()
            .find(|(key, _)| key.ends_with(".context_length"))
            .and_then(|(_, value)| value.as_i64())
    });
    let supports_tools = body
        .get("capabilities")
        .and_then(|c| c.as_array())
        .map(|caps| caps.iter().any(|c| c.as_str() == Some("tools")));

    if context_window.is_none() && supports_tools.is_none() {
        return None;
    }
    Some(Capabilities {
        context_window,
        supports_tools,
        separate_reasoning: None,
    })
}

/// Exercise the OpenAI-compatible endpoint: offer a trivial tool and see
/// whether the model calls it, and whether it answers in `content` or in a
/// separate `reasoning` field.
async fn probe_chat_completions(
    base_url: &str,
    api_key: Option<&str>,
    slug: &str,
) -> Result<(Option<bool>, Option<bool>)> {
    let request = serde_json::json!({
        "model": slug,
        "messages": [{
            "role": "user",
            "content": "Call the ping tool with value 1. Use the tool; do not answer in prose."
        }],
        "tools": [{
            "type": "function",
            "function": {
                "name": "ping",
                "description": "Records a number.",
                "parameters": {
                    "type": "object",
                    "properties": { "value": { "type": "integer" } },
                    "required": ["value"]
                }
            }
        }],
        "max_tokens": 512,
        "stream": false
    });

    let mut builder = opencli_core::default_client::build_reqwest_client()
        .post(format!("{base_url}/chat/completions"))
        .timeout(REQUEST_TIMEOUT)
        .json(&request);
    if let Some(key) = api_key {
        builder = builder.bearer_auth(key);
    }
    let response = builder.send().await.context("POST /chat/completions")?;
    let status = response.status();
    let body: serde_json::Value = response.json().await.context("parse response")?;
    if !status.is_success() {
        bail!("provider returned {status}: {body}");
    }

    let message = body
        .get("choices")
        .and_then(|c| c.as_array())
        .and_then(|choices| choices.first())
        .and_then(|choice| choice.get("message"));

    let supports_tools = message.map(|m| {
        m.get("tool_calls")
            .and_then(|t| t.as_array())
            .is_some_and(|calls| !calls.is_empty())
    });
    let separate_reasoning = message.map(|m| {
        m.get("reasoning")
            .and_then(|r| r.as_str())
            .is_some_and(|text| !text.trim().is_empty())
    });

    Ok((supports_tools, separate_reasoning))
}

/// Write probe results into the model's `[[models]]` entry.
fn apply_to_config(doc: &mut toml_edit::DocumentMut, slug: &str, caps: &Capabilities) -> bool {
    let Some(models) = doc
        .get_mut("models")
        .and_then(|item| item.as_array_of_tables_mut())
    else {
        return false;
    };
    let Some(entry) = models
        .iter_mut()
        .find(|entry| entry.get("model").and_then(|v| v.as_str()) == Some(slug))
    else {
        return false;
    };

    let mut changed = false;
    if let Some(window) = caps.context_window {
        entry["context_window"] = toml_edit::value(window);
        changed = true;
    }
    if let Some(false) = caps.supports_tools {
        // Recorded as a comment rather than a config key: there is no field to
        // disable tools per model, and silently dropping the information would
        // leave the user wondering why the agent stalls on this model.
        entry
            .key_mut("model")
            .map(|mut key| {
                key.leaf_decor_mut().set_prefix(
                    "# probe: this model did not call an offered tool; agent use will be limited\n",
                );
            })
            .unwrap_or(());
        changed = true;
    }
    changed
}

async fn probe(path: &Path, slug: &str, dry_run: bool) -> Result<()> {
    let contents =
        std::fs::read_to_string(path).with_context(|| format!("read {}", path.display()))?;
    let mut doc: toml_edit::DocumentMut = contents.parse().context("parse config.toml")?;
    let (base_url, api_key) = resolve_endpoint(&doc, slug)?;

    println!("Probing {slug} at {base_url}");

    let mut caps = probe_ollama_metadata(&base_url, slug)
        .await
        .unwrap_or_default();
    if caps.context_window.is_some() {
        println!(
            "  context window: {} (reported by the runtime)",
            caps.context_window.unwrap_or_default()
        );
    }

    // Always exercise the real endpoint: native metadata says what the runtime
    // believes, a live call says what actually comes back over the wire.
    match probe_chat_completions(&base_url, api_key.as_deref(), slug).await {
        Ok((tools, reasoning)) => {
            if let Some(tools) = tools {
                caps.supports_tools = Some(tools);
                println!(
                    "  tool calling: {}",
                    if tools {
                        "yes"
                    } else {
                        "no (offered a tool, model did not call it)"
                    }
                );
            }
            if let Some(true) = reasoning {
                caps.separate_reasoning = Some(true);
                println!("  reasoning: emitted in a separate field (counts against the window)");
            }
        }
        Err(err) => {
            println!("  live request failed: {err:#}");
            if caps == Capabilities::default() {
                bail!("could not determine any capabilities for `{slug}`");
            }
        }
    }

    if caps.context_window.is_none() {
        println!(
            "  context window: unknown — set `context_window` by hand, or it will be \
             learned from the first over-long turn"
        );
    }

    if dry_run {
        println!("\nDry run; {} was not modified.", path.display());
        return Ok(());
    }
    if apply_to_config(&mut doc, slug, &caps) {
        std::fs::write(path, doc.to_string())
            .with_context(|| format!("write {}", path.display()))?;
        println!("\nUpdated {}", path.display());
    } else {
        println!("\nNothing to record.");
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn config_with_model() -> toml_edit::DocumentMut {
        r#"
[model_providers.ollama]
base_url = "http://localhost:11434/v1"

[[models]]
model = "test-slug"
provider = "ollama"
"#
        .parse()
        .expect("parse")
    }

    #[test]
    fn should_resolve_a_declared_model_to_its_endpoint() {
        let doc = config_with_model();
        let (base_url, key) = resolve_endpoint(&doc, "test-slug").expect("resolve");
        assert_eq!(base_url, "http://localhost:11434/v1");
        assert_eq!(key, None);
    }

    #[test]
    fn should_explain_when_the_model_is_not_declared() {
        let doc = config_with_model();
        let err = resolve_endpoint(&doc, "missing").expect_err("should fail");
        assert!(err.to_string().contains("provider scan"), "{err}");
    }

    #[test]
    fn should_record_the_context_window_on_the_matching_entry() {
        let mut doc = config_with_model();
        let caps = Capabilities {
            context_window: Some(32_768),
            supports_tools: Some(true),
            separate_reasoning: None,
        };

        assert!(apply_to_config(&mut doc, "test-slug", &caps));

        let out = doc.to_string();
        assert!(out.contains("context_window = 32768"), "{out}");
        // The provider section must survive untouched.
        assert!(out.contains("[model_providers.ollama]"));
    }

    #[test]
    fn should_leave_config_alone_when_the_slug_is_absent() {
        let mut doc = config_with_model();
        let caps = Capabilities {
            context_window: Some(1024),
            ..Default::default()
        };
        assert!(!apply_to_config(&mut doc, "other-slug", &caps));
        assert!(!doc.to_string().contains("1024"));
    }
}
