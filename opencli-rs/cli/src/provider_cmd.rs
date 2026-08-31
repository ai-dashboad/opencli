//! `opencli provider` — discover and install model providers.
//!
//! This build ships no providers or models of its own, so getting to a working
//! setup otherwise means hand-writing a `[model_providers.*]` section and one
//! `[[models]]` entry per model. These subcommands do that for you: `add`
//! installs a catalog entry, and `scan` finds runtimes already listening on
//! this machine and enumerates the models they serve.
//!
//! Edits go through `toml_edit`, so existing comments and formatting survive.

use anyhow::Context;
use anyhow::Result;
use anyhow::bail;
use clap::Args;
use clap::Subcommand;
use opencli_core::config::CONFIG_TOML_FILE;
use opencli_core::config::find_opencli_home;
use opencli_core::providers::CatalogProvider;
use opencli_core::providers::{self};
use std::path::Path;
use std::time::Duration;

/// How long to wait for a local port to answer before deciding nothing is there.
const PROBE_TIMEOUT: Duration = Duration::from_millis(400);

#[derive(Debug, Args)]
pub struct ProviderArgs {
    #[command(subcommand)]
    pub cmd: ProviderSubcommand,
}

#[derive(Debug, Subcommand)]
pub enum ProviderSubcommand {
    /// List providers in the catalog and whether they are configured.
    List,
    /// Install a catalog provider into config.toml, e.g. `provider add ollama`.
    Add {
        /// Catalog id, as shown by `provider list`.
        id: String,
    },
    /// Probe this machine for running model servers and install what is found,
    /// including the models they currently serve.
    Scan {
        /// Report what would be written without changing config.toml.
        #[arg(long)]
        dry_run: bool,
    },
}

pub async fn run_main(args: ProviderArgs) -> Result<()> {
    let home = find_opencli_home().context("resolve config home")?;
    let path = home.join(CONFIG_TOML_FILE);

    match args.cmd {
        ProviderSubcommand::List => list(&path),
        ProviderSubcommand::Add { id } => add(&path, &id),
        ProviderSubcommand::Scan { dry_run } => scan(&path, dry_run).await,
    }
}

fn load_doc(path: &Path) -> Result<toml_edit::DocumentMut> {
    let contents = std::fs::read_to_string(path).unwrap_or_default();
    contents.parse().context("parse config.toml")
}

fn is_configured(doc: &toml_edit::DocumentMut, id: &str) -> bool {
    doc.get("model_providers")
        .and_then(|item| item.as_table_like())
        .is_some_and(|table| table.get(id).is_some())
}

fn list(path: &Path) -> Result<()> {
    let doc = load_doc(path)?;
    println!("{:<14} {:<26} {}", "ID", "NAME", "STATUS");
    for provider in providers::all() {
        let status = if is_configured(&doc, &provider.id) {
            "configured".to_string()
        } else if provider.is_local() {
            "available (local)".to_string()
        } else if let Some(key) = provider.env_key.as_deref() {
            match std::env::var(key) {
                Ok(value) if !value.trim().is_empty() => format!("available ({key} set)"),
                _ => format!("needs {key}"),
            }
        } else {
            "available".to_string()
        };
        println!("{:<14} {:<26} {}", provider.id, provider.name, status);
    }
    println!("\nInstall one with: opencli provider add <id>");
    println!("Find local servers with: opencli provider scan");
    Ok(())
}

fn add(path: &Path, id: &str) -> Result<()> {
    let Some(provider) = providers::find(id) else {
        bail!(
            "unknown provider `{id}`; run `opencli provider list` to see the catalog",
        );
    };
    let mut doc = load_doc(path)?;
    write_provider(&mut doc, &provider);
    std::fs::write(path, doc.to_string())
        .with_context(|| format!("write {}", path.display()))?;

    println!("Added [model_providers.{}] to {}", provider.id, path.display());
    if let Some(key) = provider.env_key.as_deref() {
        println!("Set {key} in your environment before using it.");
    }
    if let Some(docs) = provider.docs.as_deref() {
        println!("Docs: {docs}");
    }
    println!(
        "Declare a model with:\n\n  [[models]]\n  model = \"<slug>\"\n  provider = \"{}\"\n",
        provider.id
    );
    Ok(())
}

/// Upsert a `[model_providers.<id>]` section, leaving surrounding config intact.
fn write_provider(doc: &mut toml_edit::DocumentMut, provider: &CatalogProvider) {
    let providers_table = doc
        .entry("model_providers")
        .or_insert(toml_edit::Item::Table({
            let mut table = toml_edit::Table::new();
            table.set_implicit(true);
            table
        }));

    let mut entry = toml_edit::Table::new();
    entry["name"] = toml_edit::value(provider.name.clone());
    entry["base_url"] = toml_edit::value(provider.base_url.clone());
    entry["wire_api"] = toml_edit::value(provider.wire_api.clone());
    if let Some(env_key) = provider.env_key.as_deref() {
        entry["env_key"] = toml_edit::value(env_key);
    }

    if let Some(table) = providers_table.as_table_like_mut() {
        table.insert(&provider.id, toml_edit::Item::Table(entry));
    }
}

/// Append `[[models]]` entries for slugs that are not already declared.
fn write_models(doc: &mut toml_edit::DocumentMut, provider_id: &str, slugs: &[String]) -> usize {
    let existing: Vec<String> = doc
        .get("models")
        .and_then(|item| item.as_array_of_tables())
        .map(|array| {
            array
                .iter()
                .filter_map(|table| {
                    table.get("model").and_then(|v| v.as_str()).map(str::to_string)
                })
                .collect()
        })
        .unwrap_or_default();

    let array = doc
        .entry("models")
        .or_insert(toml_edit::Item::ArrayOfTables(
            toml_edit::ArrayOfTables::new(),
        ));
    let Some(array) = array.as_array_of_tables_mut() else {
        return 0;
    };

    let mut added = 0;
    for slug in slugs {
        if existing.iter().any(|e| e == slug) {
            continue;
        }
        let mut table = toml_edit::Table::new();
        table["model"] = toml_edit::value(slug.clone());
        table["provider"] = toml_edit::value(provider_id);
        array.push(table);
        added += 1;
    }
    added
}

/// True when something accepts a TCP connection on `port` of this machine.
async fn port_is_open(port: u16) -> bool {
    let addr = format!("127.0.0.1:{port}");
    matches!(
        tokio::time::timeout(PROBE_TIMEOUT, tokio::net::TcpStream::connect(addr)).await,
        Ok(Ok(_))
    )
}

/// Whether a discovered slug is usable for chat.
///
/// Runtimes list every loaded model, including embedding-only ones that reject
/// `/chat/completions`. Writing those into `[[models]]` would put entries in the
/// `/model` picker that fail the moment they are selected. Ollama reports a
/// per-model capability list, so ask rather than guess; when nothing answers,
/// keep the slug — a false negative would hide a working model.
async fn is_chat_capable(base_url: &str, slug: &str) -> bool {
    let root = base_url.trim_end_matches("/v1");
    let Ok(response) = opencli_core::default_client::build_reqwest_client()
        .post(format!("{root}/api/show"))
        .json(&serde_json::json!({ "model": slug }))
        .timeout(Duration::from_secs(10))
        .send()
        .await
    else {
        return true;
    };
    if !response.status().is_success() {
        return true;
    }
    let Ok(body) = response.json::<serde_json::Value>().await else {
        return true;
    };
    match body.get("capabilities").and_then(|c| c.as_array()) {
        Some(caps) => caps.iter().any(|c| c.as_str() == Some("completion")),
        None => true,
    }
}

/// What a probe of a candidate port concluded.
enum Probe {
    /// An OpenAI-compatible server answered with this model list, which may be
    /// empty when the runtime is up but has nothing loaded.
    Models(Vec<String>),
    /// Something is listening, but it is not this provider's API.
    NotThisProvider,
}

/// Ask an OpenAI-compatible server which models it serves.
///
/// Parsed loosely on purpose: self-hosted servers differ in what else they put
/// in `/v1/models`, and only each entry's `id` matters here. Ollama reports
/// `"data": null` rather than `[]` when no model is installed, so a null or
/// missing array is treated as "none loaded", not as a parse failure.
async fn probe_models(base_url: &str) -> Result<Probe> {
    let url = format!("{}/models", base_url.trim_end_matches('/'));
    let response = opencli_core::default_client::build_reqwest_client()
        .get(&url)
        .timeout(Duration::from_secs(5))
        .send()
        .await
        .with_context(|| format!("GET {url}"))?;

    if !response.status().is_success() {
        return Ok(Probe::NotThisProvider);
    }
    let Ok(body) = response.json::<serde_json::Value>().await else {
        return Ok(Probe::NotThisProvider);
    };
    // A response without `data` at all is some other service on the port.
    let Some(data) = body.get("data") else {
        return Ok(Probe::NotThisProvider);
    };
    let slugs = data
        .as_array()
        .map(|entries| {
            entries
                .iter()
                .filter_map(|entry| entry.get("id")?.as_str().map(str::to_string))
                .collect()
        })
        .unwrap_or_default();
    Ok(Probe::Models(slugs))
}

async fn scan(path: &Path, dry_run: bool) -> Result<()> {
    let mut doc = load_doc(path)?;
    let mut found_any = false;
    let mut changed = false;

    for provider in providers::all().into_iter().filter(CatalogProvider::is_local) {
        let mut open_port = None;
        for port in &provider.scan_ports {
            if port_is_open(*port).await {
                open_port = Some(*port);
                break;
            }
        }
        let Some(port) = open_port else { continue };

        let slugs = match probe_models(&provider.base_url).await {
            // Something else owns the port — say nothing, since reporting it as
            // "found" would be wrong and the user did not ask about it.
            Ok(Probe::NotThisProvider) => continue,
            Ok(Probe::Models(slugs)) => {
                found_any = true;
                println!("Found {} on port {port}", provider.name);
                if slugs.is_empty() {
                    println!("  running, but no models are loaded yet");
                    continue;
                }
                slugs
            }
            Err(err) => {
                found_any = true;
                println!("Found {} on port {port}", provider.name);
                println!("  could not list models: {err:#}");
                continue;
            }
        };

        let mut chat_slugs = Vec::new();
        for slug in &slugs {
            if is_chat_capable(&provider.base_url, slug).await {
                println!("  model: {slug}");
                chat_slugs.push(slug.clone());
            } else {
                println!("  model: {slug} (skipped: not usable for chat)");
            }
        }
        if chat_slugs.is_empty() {
            println!("  no chat-capable models; skipping");
            continue;
        }
        let slugs = chat_slugs;

        if dry_run {
            continue;
        }
        write_provider(&mut doc, &provider);
        let added = write_models(&mut doc, &provider.id, &slugs);
        println!(
            "  wrote [model_providers.{}] and {added} new model entr{}",
            provider.id,
            if added == 1 { "y" } else { "ies" }
        );
        // Without a default the session model resolves to the built-in `openai`
        // provider, which a local-only setup has no credentials for. Pick the
        // first discovered model so the very next run works.
        if doc.get("model").is_none()
            && let Some(first) = slugs.first()
        {
            doc["model"] = toml_edit::value(first.clone());
            println!("  set default model to {first}");
        }
        changed = true;
    }

    if !found_any {
        println!("No local model servers found.");
        println!(
            "Checked: {}",
            providers::all()
                .into_iter()
                .filter(CatalogProvider::is_local)
                .map(|p| format!(
                    "{} ({})",
                    p.name,
                    p.scan_ports
                        .iter()
                        .map(u16::to_string)
                        .collect::<Vec<_>>()
                        .join("/")
                ))
                .collect::<Vec<_>>()
                .join(", ")
        );
        return Ok(());
    }

    if changed {
        std::fs::write(path, doc.to_string())
            .with_context(|| format!("write {}", path.display()))?;
        println!("\nUpdated {}. Pick a model with /model.", path.display());
    } else if dry_run {
        println!("\nDry run; {} was not modified.", path.display());
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn should_add_a_provider_without_disturbing_existing_config() {
        let mut doc: toml_edit::DocumentMut = r#"
# keep me
model = "existing"
"#
        .parse()
        .expect("parse");
        let provider = providers::find("ollama").expect("ollama in catalog");

        write_provider(&mut doc, &provider);
        let out = doc.to_string();

        assert!(out.contains("# keep me"), "comments must survive: {out}");
        assert!(out.contains("model = \"existing\""));
        assert!(out.contains("[model_providers.ollama]"));
        assert!(out.contains("http://localhost:11434/v1"));
    }

    #[test]
    fn should_not_duplicate_models_already_declared() {
        let mut doc: toml_edit::DocumentMut = r#"
[[models]]
model = "already-there"
provider = "ollama"
"#
        .parse()
        .expect("parse");

        let added = write_models(
            &mut doc,
            "ollama",
            &["already-there".to_string(), "brand-new".to_string()],
        );

        assert_eq!(added, 1, "only the new slug should be appended");
        let out = doc.to_string();
        assert_eq!(out.matches("already-there").count(), 1);
        assert!(out.contains("brand-new"));
    }

    /// Ollama reports `"data": null` when no model is installed. Observed
    /// against a real server; treating it as a parse error made a healthy
    /// runtime look broken.
    #[test]
    fn should_read_a_null_data_field_as_no_models_loaded() {
        let body: serde_json::Value =
            serde_json::from_str(r#"{"object":"list","data":null}"#).expect("parse");
        let slugs: Vec<String> = body
            .get("data")
            .and_then(|d| d.as_array())
            .map(|entries| {
                entries
                    .iter()
                    .filter_map(|e| e.get("id")?.as_str().map(str::to_string))
                    .collect()
            })
            .unwrap_or_default();
        assert!(slugs.is_empty());
    }

    /// A port being open does not mean it belongs to the expected provider;
    /// port 8000 on the author's machine served an unrelated app.
    #[test]
    fn should_treat_a_response_without_data_as_a_different_service() {
        let body: serde_json::Value =
            serde_json::from_str(r#"{"detail":"Not Found"}"#).expect("parse");
        assert!(body.get("data").is_none());
    }

    /// Runtimes list embedding-only models alongside chat ones; those reject
    /// `/chat/completions`, so they must not reach the `/model` picker.
    /// Observed with `all-minilm`, which advertises only `embedding`.
    #[test]
    fn should_read_capabilities_to_tell_chat_models_from_embedding_models() {
        let chat: serde_json::Value =
            serde_json::from_str(r#"{"capabilities":["completion","tools"]}"#).expect("parse");
        let embedding: serde_json::Value =
            serde_json::from_str(r#"{"capabilities":["embedding"]}"#).expect("parse");

        let is_chat = |v: &serde_json::Value| {
            v.get("capabilities")
                .and_then(|c| c.as_array())
                .is_some_and(|caps| caps.iter().any(|c| c.as_str() == Some("completion")))
        };
        assert!(is_chat(&chat));
        assert!(!is_chat(&embedding));
    }

    #[test]
    fn should_reject_an_unknown_catalog_id() {
        let dir = tempfile::tempdir().expect("tempdir");
        let path = dir.path().join("config.toml");
        let err = add(&path, "not-a-provider").expect_err("unknown id should fail");
        assert!(err.to_string().contains("not-a-provider"));
    }
}
