//! Finding models to install.
//!
//! Three sources, all reaching the same runtime through the same pull:
//!
//! - **Ollama's library** — already quantised and ready. There is no public
//!   search API for it, so what is offered is a catalogue kept here, with what
//!   each model is for and whether it calls tools.
//! - **Hugging Face** — searchable over a public API, and installable because
//!   Ollama resolves `hf.co/owner/repo:quant` directly. Both verified against
//!   the real services rather than assumed.
//! - **ModelScope** — the same, through `modelscope.cn/owner/repo`. Worth
//!   having where Hugging Face is slow or blocked.
//!
//! Whether a model calls tools is the fact that matters most here: one that
//! cannot is close to useless for agent work, and a marketplace that hid that
//! would be selling disappointment.
//!
//! # Browsing without knowing a name
//!
//! Hugging Face was originally reachable only by searching it, which asks the
//! user to already know what a model is called. Most do not — that is the
//! whole reason they are looking. So the popular list is fetched with no query
//! at all, cached to disk, and warmed in the background when the gateway
//! starts, so opening the panel shows a browsable list rather than an empty
//! search box.

use serde::Deserialize;
use serde::Serialize;
use serde_json::Value;
use serde_json::json;
use std::path::Path;
use std::time::Duration;
use std::time::SystemTime;
use std::time::UNIX_EPOCH;

/// Answer a `hub/*` request.
pub async fn handle(raw: &str, opencli_home: &std::path::Path) -> Option<String> {
    let message: Value = serde_json::from_str(raw).ok()?;
    let method = message.get("method")?.as_str()?;
    if !method.starts_with("hub/") {
        return None;
    }
    let id = message.get("id").cloned().unwrap_or(Value::Null);
    let params = message.get("params").cloned().unwrap_or(json!({}));

    let result = match method {
        "hub/catalog" => Ok(catalog(opencli_home, &params)),
        "hub/upsert" => upsert(opencli_home, &params),
        "hub/remove" => remove(opencli_home, &params),
        "hub/search" => search(&params).await,
        "hub/popular" => popular(opencli_home, &params).await,
        "hub/variants" => variants(&params).await,
        _ => Err(format!("unknown method `{method}`")),
    };

    Some(match result {
        Ok(value) => json!({ "id": id, "result": value }).to_string(),
        Err(message) => {
            json!({ "id": id, "error": { "code": -32602, "message": message } }).to_string()
        }
    })
}

fn entry_json(entry: &opencli_core::model_catalog::CatalogModel) -> Value {
    json!({
        "source": "ollama",
        "tag": entry.tag,
        "name": entry.name,
        "note": entry.note,
        "sizeGb": entry.size_gb,
        "needsGb": entry.needs_gb,
        "tools": entry.tools,
        "context": entry.context,
        "purpose": entry.purpose,
        // The UI offers to edit only what the user owns; a bundled entry is
        // replaced by adding one with the same tag, not edited in place.
        "userDefined": entry.user_defined,
    })
}

/// The catalogue, optionally filtered and checked against a memory figure.
fn catalog(opencli_home: &std::path::Path, params: &Value) -> Value {
    let needle = params
        .get("query")
        .and_then(Value::as_str)
        .unwrap_or("")
        .trim()
        .to_ascii_lowercase();
    // A machine that cannot hold a model should not be offered it as an equal.
    let fits = params.get("memoryGb").and_then(Value::as_f64);

    let data: Vec<Value> = opencli_core::model_catalog::all(opencli_home)
        .iter()
        .filter(|entry| {
            needle.is_empty()
                || entry.tag.to_ascii_lowercase().contains(&needle)
                || entry.name.to_ascii_lowercase().contains(&needle)
                || entry.note.to_ascii_lowercase().contains(&needle)
        })
        .map(|entry| {
            let mut value = entry_json(entry);
            if let Some(memory) = fits
                && let Some(object) = value.as_object_mut()
            {
                object.insert("fits".to_string(), json!(entry.needs_gb as f64 <= memory));
            }
            value
        })
        .collect();
    json!({ "data": data })
}

/// Add or replace one of the user's own entries.
fn upsert(opencli_home: &std::path::Path, params: &Value) -> Result<Value, String> {
    let text = |key: &str| {
        params
            .get(key)
            .and_then(Value::as_str)
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(str::to_string)
    };
    let tag = text("tag").ok_or("tag is required")?;
    // Without a note the entry says nothing a chooser can act on, which is the
    // whole point of a catalogue over a bare list of names.
    let note = text("note").ok_or("note is required — say what the model is for")?;
    let name = text("name").unwrap_or_else(|| tag.clone());

    let entry = opencli_core::model_catalog::CatalogModel {
        tag,
        name,
        note,
        size_gb: params.get("sizeGb").and_then(Value::as_f64).unwrap_or(0.0) as f32,
        needs_gb: params.get("needsGb").and_then(Value::as_f64).unwrap_or(0.0) as f32,
        tools: params
            .get("tools")
            .and_then(Value::as_bool)
            .unwrap_or(false),
        context: params.get("context").and_then(Value::as_u64).unwrap_or(0) as u32,
        // An unrecognised purpose would make a group of one, so anything the
        // build does not group by falls into the general one.
        purpose: params
            .get("purpose")
            .and_then(Value::as_str)
            .filter(|purpose| opencli_core::model_catalog::is_known_purpose(purpose))
            .unwrap_or("general")
            .to_string(),
        user_defined: true,
    };

    opencli_core::model_catalog::upsert(opencli_home, entry)
        .map_err(|err| format!("could not save models.toml: {err}"))?;
    Ok(json!({ "saved": true }))
}

/// Remove one of the user's entries. A bundled one cannot be deleted, only
/// shadowed, so a build's own catalogue stays whole.
fn remove(opencli_home: &std::path::Path, params: &Value) -> Result<Value, String> {
    let tag = params
        .get("tag")
        .and_then(Value::as_str)
        .filter(|tag| !tag.is_empty())
        .ok_or("tag is required")?;
    let removed = opencli_core::model_catalog::remove(opencli_home, tag)
        .map_err(|err| format!("could not save models.toml: {err}"))?;
    if !removed {
        return Err(format!("`{tag}` is not one of your own entries"));
    }
    Ok(json!({ "removed": true }))
}

/// Search a hub for models that can be installed.
///
/// Only GGUF repositories are returned: those are the ones the runtime can
/// resolve. Listing anything else would offer installs that fail.
async fn search(params: &Value) -> Result<Value, String> {
    let query = params
        .get("query")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|query| !query.is_empty())
        .ok_or("query is required")?;
    let source = params
        .get("source")
        .and_then(Value::as_str)
        .unwrap_or("huggingface");

    match source {
        "huggingface" => search_hugging_face(query).await,
        "modelscope" => Ok(modelscope_hint(query)),
        other => Err(format!("`{other}` is not a source this build knows")),
    }
}

/// Where the popular list is kept between runs.
const POPULAR_FILE: &str = "hub-popular.json";

/// How many to keep, which is also how far "show more" reaches.
///
/// Fetched in one go and sliced locally rather than paged over the network:
/// "show more" is then instant, and one request per session is kinder to a
/// public API than one per page.
const POPULAR_DEPTH: usize = 100;

/// How long a cached list is served without refetching.
///
/// Download rankings move over days, not minutes. The stale copy is shown
/// either way — this only decides when a refresh is started behind it.
const POPULAR_TTL: Duration = Duration::from_secs(6 * 60 * 60);

/// The popular list as it sits on disk.
#[derive(Serialize, Deserialize)]
struct PopularCache {
    fetched_at: u64,
    models: Vec<Value>,
}

fn popular_path(opencli_home: &Path) -> std::path::PathBuf {
    opencli_home.join(POPULAR_FILE)
}

fn now_seconds() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|since| since.as_secs())
        .unwrap_or(0)
}

/// The cached list, or none when it is missing or unreadable.
///
/// A corrupt cache costs a refetch, never the panel.
fn read_popular(opencli_home: &Path) -> Option<PopularCache> {
    let text = std::fs::read_to_string(popular_path(opencli_home)).ok()?;
    serde_json::from_str(&text).ok()
}

fn write_popular(opencli_home: &Path, cache: &PopularCache) {
    let _ = std::fs::create_dir_all(opencli_home);
    if let Ok(text) = serde_json::to_string(cache) {
        let _ = std::fs::write(popular_path(opencli_home), text);
    }
}

/// Turn one Hugging Face model record into an offer.
///
/// Shared with search so both lists describe a model the same way, and so
/// neither can quietly start claiming something the other does not.
fn hugging_face_offer(model: &Value) -> Option<Value> {
    let id = model.get("id").and_then(Value::as_str)?;
    Some(json!({
        "source": "huggingface",
        // The runtime resolves this form directly. A quantisation has to be
        // chosen, which the install dialog asks for.
        "tag": format!("hf.co/{id}"),
        "name": id,
        "downloads": model.get("downloads"),
        "likes": model.get("likes"),
        // Nothing here says whether it calls tools; only the runtime knows,
        // once installed. Claiming otherwise would be guessing at the one fact
        // that decides whether it is usable.
        "tools": Value::Null,
        "needsQuant": true,
    }))
}

/// Ask Hugging Face for the most-downloaded models, with no search term.
///
/// `pipeline_tag` is not a matter of taste — it removes models that cannot
/// hold a conversation at all. The top of the unfiltered list contains
/// embedding and speech-recognition models, which no amount of quantisation
/// makes usable here. Nothing else is filtered: what is popular is shown as
/// it is, in the order Hugging Face reports.
async fn fetch_popular(depth: usize) -> Result<Vec<Value>, String> {
    let client = reqwest::Client::builder()
        .timeout(Duration::from_secs(20))
        .build()
        .map_err(|err| err.to_string())?;

    let response = client
        .get("https://huggingface.co/api/models")
        .query(&[
            ("filter", "gguf"),
            ("pipeline_tag", "text-generation"),
            ("sort", "downloads"),
            ("direction", "-1"),
            ("limit", &depth.to_string()),
        ])
        .send()
        .await
        .map_err(|err| format!("could not reach Hugging Face: {err}"))?;

    if !response.status().is_success() {
        return Err(format!("Hugging Face answered {}", response.status()));
    }
    let body: Value = response
        .json()
        .await
        .map_err(|_| "Hugging Face's reply was not readable".to_string())?;

    Ok(body
        .as_array()
        .map(|models| models.iter().filter_map(hugging_face_offer).collect())
        .unwrap_or_default())
}

/// Fetch the popular list into the cache when it is missing or old.
///
/// Spawned once when the gateway starts, so the first time the panel is
/// opened there is already something to show. Failure is silent on purpose:
/// no list is a panel with a curated library and a note, not an error on
/// startup for something nobody asked for yet.
pub async fn warm_popular_cache(opencli_home: std::path::PathBuf) {
    let age = read_popular(&opencli_home)
        .map(|cache| now_seconds().saturating_sub(cache.fetched_at))
        .unwrap_or(u64::MAX);
    if age < POPULAR_TTL.as_secs() {
        return;
    }
    if let Ok(models) = fetch_popular(POPULAR_DEPTH).await {
        write_popular(
            &opencli_home,
            &PopularCache {
                fetched_at: now_seconds(),
                models,
            },
        );
    }
}

/// The most-downloaded models, for browsing without a search term.
///
/// A cached list is served straight away and marked `stale` when it is old,
/// rather than made to wait for a refresh. Waiting would put an empty panel
/// behind a network call, which is the thing this whole method exists to
/// avoid. Only a completely absent cache fetches inline.
async fn popular(opencli_home: &Path, params: &Value) -> Result<Value, String> {
    let offset = params
        .get("offset")
        .and_then(Value::as_u64)
        .unwrap_or(0)
        .min(POPULAR_DEPTH as u64) as usize;
    let limit = params
        .get("limit")
        .and_then(Value::as_u64)
        .unwrap_or(20)
        .clamp(1, POPULAR_DEPTH as u64) as usize;

    let cache = match read_popular(opencli_home) {
        Some(cache) if !cache.models.is_empty() => cache,
        _ => {
            let models = fetch_popular(POPULAR_DEPTH).await?;
            let cache = PopularCache {
                fetched_at: now_seconds(),
                models,
            };
            write_popular(opencli_home, &cache);
            cache
        }
    };

    let age = now_seconds().saturating_sub(cache.fetched_at);
    let total = cache.models.len();
    let page: Vec<Value> = cache
        .models
        .iter()
        .skip(offset)
        .take(limit)
        .cloned()
        .collect();

    Ok(json!({
        "data": page,
        "total": total,
        "fetchedAt": cache.fetched_at,
        // Shown either way; this only tells the panel whether to say it is
        // being refreshed, so a figure from last week never passes as current.
        "stale": age >= POPULAR_TTL.as_secs(),
    }))
}

async fn search_hugging_face(query: &str) -> Result<Value, String> {
    let client = reqwest::Client::builder()
        .timeout(Duration::from_secs(20))
        .build()
        .map_err(|err| err.to_string())?;

    let response = client
        .get("https://huggingface.co/api/models")
        .query(&[
            ("search", query),
            ("filter", "gguf"),
            // Same reasoning as the popular list: a search for "qwen" should
            // not return embedding models that cannot hold a conversation.
            ("pipeline_tag", "text-generation"),
            ("sort", "downloads"),
            ("direction", "-1"),
            ("limit", "25"),
        ])
        .send()
        .await
        .map_err(|err| format!("could not reach Hugging Face: {err}"))?;

    if !response.status().is_success() {
        return Err(format!("Hugging Face answered {}", response.status()));
    }
    let body: Value = response
        .json()
        .await
        .map_err(|_| "Hugging Face's reply was not readable".to_string())?;

    let data: Vec<Value> = body
        .as_array()
        .map(|models| models.iter().filter_map(hugging_face_offer).collect())
        .unwrap_or_default();

    Ok(json!({ "data": data }))
}

/// Companion files that sit beside a model in a GGUF repository.
///
/// A repository holds more than the weights. `mmproj-…` is the vision
/// projector for a multimodal model — a real `.gguf`, carrying a quantisation
/// in its name, and around a fortieth the size of the model it belongs to.
/// Treating one as a choice offered a 0.9 GB "BF16" beside a 71 GB one, so it
/// looked like the best version that fits and was recommended. Installing it
/// downloads something that cannot answer a prompt at all.
const COMPANION_PREFIXES: &[&str] = &["mmproj", "mmproj-model", "proj"];

/// Whether a `.gguf` file in a repository is the model itself.
fn is_model_file(rfilename: &str) -> bool {
    let base = rfilename.rsplit('/').next().unwrap_or(rfilename);
    let lower = base.to_ascii_lowercase();

    // A split file is one part of a set; its size is not the model's, and
    // reporting a shard as a choice would understate it several times over.
    if lower.contains("-of-") {
        return false;
    }
    !COMPANION_PREFIXES
        .iter()
        .any(|prefix| lower.starts_with(&format!("{prefix}-")) || lower == format!("{prefix}.gguf"))
}

/// The quantisation to suggest when nothing is known about the machine.
///
/// The one whose description is "the usual balance of size and quality" — it
/// runs on the widest range of hardware while still being worth running.
const BALANCED_QUANT: &str = "Q4_K_M";

/// What each quantisation means, in words rather than letters.
///
/// `Q4_K_M` tells a person nothing. Offering the choice without saying what it
/// costs is offering a decision nobody can make.
fn describe_quant(quant: &str) -> &'static str {
    match quant {
        "Q2_K" => "Smallest. Noticeably worse; only worth it when memory is very tight.",
        "Q3_K_S" | "Q3_K_M" | "Q3_K_L" => "Small, with some loss of quality.",
        "Q4_0" | "Q4_1" | "Q4_K_S" => "Small and fast.",
        "Q4_K_M" => "The usual balance of size and quality.",
        "Q5_K_S" | "Q5_K_M" => "Better quality, around 15% larger than Q4.",
        "Q6_K" => "Close to the original, around a third larger than Q4.",
        "Q8_0" => "Near-lossless, about twice the size of Q4.",
        "FP16" | "BF16" => "The original weights. Largest, and rarely worth it locally.",
        _ => "",
    }
}

/// How good a quantisation is, for choosing the best one that fits.
///
/// Not simply "largest is best". Unquantised weights are twice the size of
/// `Q8_0` for a difference nobody can detect locally, so they rank *below* it:
/// recommending 15 GB where 8 would do wastes memory that the context window
/// needs more.
fn quality_rank(quant: &str) -> u8 {
    match quant {
        "Q8_0" => 9,
        // Deliberately below Q8: bigger, and no better in practice.
        "FP16" | "BF16" => 8,
        "Q6_K" => 7,
        "Q5_K_M" => 6,
        "Q5_K_S" => 5,
        "Q4_K_M" => 4,
        "Q4_K_S" | "Q4_0" | "Q4_1" => 3,
        "Q3_K_L" | "Q3_K_M" | "Q3_K_S" => 2,
        "Q2_K" => 1,
        _ => 0,
    }
}

/// The quantisations a Hugging Face repository offers, with real sizes.
///
/// Listing them turns "type `:Q4_K_M` yourself and hope" into a choice with
/// numbers attached — and lets a sensible default be picked from the memory
/// actually available.
async fn variants(params: &Value) -> Result<Value, String> {
    let repo = params
        .get("repo")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|repo| !repo.is_empty())
        .ok_or("repo is required")?;
    // Accept either form, so a tag from elsewhere in the UI can be passed back.
    let repo = repo
        .trim_start_matches("hf.co/")
        .split(':')
        .next()
        .unwrap_or(repo);

    let client = reqwest::Client::builder()
        .timeout(Duration::from_secs(20))
        .build()
        .map_err(|err| err.to_string())?;
    let response = client
        .get(format!("https://huggingface.co/api/models/{repo}"))
        .query(&[("blobs", "true")])
        .send()
        .await
        .map_err(|err| format!("could not reach Hugging Face: {err}"))?;
    if !response.status().is_success() {
        return Err(format!("Hugging Face answered {}", response.status()));
    }
    let body: Value = response
        .json()
        .await
        .map_err(|_| "Hugging Face's reply was not readable".to_string())?;

    let mut seen: std::collections::BTreeMap<String, u64> = std::collections::BTreeMap::new();
    for sibling in body
        .get("siblings")
        .and_then(Value::as_array)
        .unwrap_or(&Vec::new())
    {
        let Some(name) = sibling.get("rfilename").and_then(Value::as_str) else {
            continue;
        };
        if !name.ends_with(".gguf") {
            continue;
        }
        if !is_model_file(name) {
            continue;
        }
        let Some(quant) = name
            .rsplit_once('-')
            .map(|(_, tail)| tail.trim_end_matches(".gguf").to_ascii_uppercase())
        else {
            continue;
        };
        if quality_rank(&quant) == 0 {
            continue;
        }
        let size = sibling.get("size").and_then(Value::as_u64).unwrap_or(0);
        seen.insert(quant, size);
    }

    let memory = params.get("memoryGb").and_then(Value::as_f64);
    let mut data: Vec<Value> = seen
        .iter()
        .map(|(quant, size)| {
            let gb = *size as f64 / 1e9;
            json!({
                "quant": quant,
                "tag": format!("hf.co/{repo}:{quant}"),
                "sizeGb": gb,
                "note": describe_quant(quant),
                // Weights are not the only thing resident; a model needs
                // headroom above its own size to run comfortably.
                "fits": memory.map(|memory| gb * 1.25 <= memory),
            })
        })
        .collect();
    data.sort_by_key(|entry| quality_rank(entry["quant"].as_str().unwrap_or("")));

    let recommended = recommend(&data, memory.is_some());

    if data.is_empty() {
        return Err(format!(
            "`{repo}` has no GGUF files this build recognises, so there is nothing to install"
        ));
    }

    Ok(json!({ "data": data, "recommended": recommended }))
}

/// ModelScope has no public search API that does not need an account, so the
/// panel sends people to the site rather than pretending to search it.
fn modelscope_hint(query: &str) -> Value {
    json!({
        "data": [],
        "hint": format!(
            "ModelScope has no open search API. Find a GGUF repository at \
             https://modelscope.cn/models?search={query}, then install it by its full name, \
             for example `modelscope.cn/owner/repo`."
        ),
    })
}

/// Which version to suggest, given the variants in quality order.
///
/// Chosen rather than asked for, because "which quantisation" is not a
/// question most people can answer.
///
/// When the machine's memory is known: the best that fits, or the smallest
/// when nothing does. When it is not: the balanced default rather than the
/// largest. An unknown machine is precisely where recommending the biggest
/// file is least safe — treating "unknown" as "it fits" would send a 16 GB
/// download to a laptop.
fn recommend(data: &[Value], memory_is_known: bool) -> Option<String> {
    let chosen = if memory_is_known {
        data.iter()
            .rfind(|entry| entry["fits"].as_bool().unwrap_or(false))
            .or_else(|| data.first())
    } else {
        data.iter()
            .find(|entry| entry["quant"].as_str() == Some(BALANCED_QUANT))
            .or_else(|| data.first())
    };
    chosen
        .and_then(|entry| entry["tag"].as_str())
        .map(str::to_string)
}

#[cfg(test)]
mod tests {
    use super::*;

    use tempfile::tempdir;

    async fn call_in(raw: &str, home: &std::path::Path) -> Value {
        let reply = handle(raw, home)
            .await
            .expect("hub methods are handled locally");
        serde_json::from_str(&reply).expect("valid JSON reply")
    }

    async fn call(raw: &str) -> Value {
        let dir = tempdir().expect("tempdir");
        call_in(raw, dir.path()).await
    }

    #[tokio::test]
    async fn should_pass_non_hub_methods_through_to_the_agent() {
        let dir = tempdir().expect("tempdir");
        assert!(
            handle(r#"{"method":"turn/start","id":1}"#, dir.path())
                .await
                .is_none()
        );
        assert!(handle("not json", dir.path()).await.is_none());
    }

    #[tokio::test]
    async fn should_offer_a_library_that_says_what_each_model_is_for() {
        let listed = call(r#"{"method":"hub/catalog","id":1}"#).await;
        let rows = listed["result"]["data"].as_array().expect("data");
        assert!(rows.len() >= 8);
        for row in rows {
            assert!(
                !row["note"].as_str().unwrap_or("").is_empty(),
                "{row} needs a note"
            );
            assert!(
                row["tools"].is_boolean(),
                "{row} must say whether it calls tools"
            );
            assert!(row["needsGb"].as_f64().unwrap_or(0.0) > 0.0);
        }
    }

    #[tokio::test]
    async fn should_be_honest_about_models_that_cannot_call_tools() {
        // A marketplace that hid this would be selling disappointment: such a
        // model cannot drive the agent's own work.
        let listed = call(r#"{"method":"hub/catalog","id":1}"#).await;
        let rows = listed["result"]["data"].as_array().expect("data");
        let without = rows
            .iter()
            .find(|row| row["tools"] == false)
            .expect("one is listed");
        assert!(
            without["note"]
                .as_str()
                .unwrap_or("")
                .to_lowercase()
                .contains("tool"),
            "the note must say so: {without}"
        );
    }

    #[tokio::test]
    async fn should_filter_the_library_by_what_was_typed() {
        let listed = call(r#"{"method":"hub/catalog","id":1,"params":{"query":"coder"}}"#).await;
        let rows = listed["result"]["data"].as_array().expect("data");
        assert!(!rows.is_empty());
        assert!(
            rows.iter()
                .all(|row| row["tag"].as_str().unwrap_or("").contains("coder"))
        );
    }

    #[tokio::test]
    async fn should_mark_what_will_not_fit_in_a_given_amount_of_memory() {
        // Offering a 24 GB model to a 8 GB machine as an equal choice wastes a
        // long download to reach a failure.
        let listed = call(r#"{"method":"hub/catalog","id":1,"params":{"memoryGb":8}}"#).await;
        let rows = listed["result"]["data"].as_array().expect("data");
        let big = rows
            .iter()
            .find(|row| row["tag"] == "qwen2.5-coder:32b")
            .expect("listed");
        assert_eq!(big["fits"], false);
        let small = rows
            .iter()
            .find(|row| row["tag"] == "qwen2.5:0.5b")
            .expect("listed");
        assert_eq!(small["fits"], true);
    }

    #[tokio::test]
    async fn should_leave_fit_unstated_when_the_memory_is_unknown() {
        // A remote runtime's memory cannot be read over HTTP; guessing it would
        // be worse than saying nothing.
        let listed = call(r#"{"method":"hub/catalog","id":1}"#).await;
        let rows = listed["result"]["data"].as_array().expect("data");
        assert!(rows.iter().all(|row| row.get("fits").is_none()));
    }

    #[tokio::test]
    async fn should_let_the_user_add_an_entry_of_their_own() {
        // The catalogue is data, so it can be extended without a rebuild —
        // the thing the hardcoded version made impossible.
        let dir = tempdir().expect("tempdir");
        let saved = call_in(
            r#"{"method":"hub/upsert","id":1,"params":
                {"tag":"mine:7b","name":"Mine","note":"my own model","needsGb":8,"tools":true}}"#,
            dir.path(),
        )
        .await;
        assert_eq!(saved["result"]["saved"], true);

        let listed = call_in(r#"{"method":"hub/catalog","id":2}"#, dir.path()).await;
        let mine = listed["result"]["data"]
            .as_array()
            .expect("data")
            .iter()
            .find(|row| row["tag"] == "mine:7b")
            .expect("listed");
        assert_eq!(mine["userDefined"], true);
    }

    #[tokio::test]
    async fn should_refuse_an_entry_that_says_nothing_useful() {
        // A name with no note is a list, not a catalogue; the note is what
        // someone choosing acts on.
        let dir = tempdir().expect("tempdir");
        let reply = call_in(
            r#"{"method":"hub/upsert","id":1,"params":{"tag":"mine:7b"}}"#,
            dir.path(),
        )
        .await;
        assert!(
            reply["error"]["message"]
                .as_str()
                .is_some_and(|message| message.contains("note"))
        );
    }

    #[tokio::test]
    async fn should_refuse_to_delete_a_bundled_entry() {
        // Only shadowed, never removed, so a build's own catalogue stays whole.
        let dir = tempdir().expect("tempdir");
        let reply = call_in(
            r#"{"method":"hub/remove","id":1,"params":{"tag":"qwen2.5-coder:7b"}}"#,
            dir.path(),
        )
        .await;
        assert!(reply["error"].is_object());
    }

    #[tokio::test]
    async fn should_remove_an_entry_the_user_added() {
        let dir = tempdir().expect("tempdir");
        call_in(
            r#"{"method":"hub/upsert","id":1,"params":
                {"tag":"mine:7b","note":"my own model"}}"#,
            dir.path(),
        )
        .await;
        let removed = call_in(
            r#"{"method":"hub/remove","id":2,"params":{"tag":"mine:7b"}}"#,
            dir.path(),
        )
        .await;
        assert_eq!(removed["result"]["removed"], true);
    }

    #[tokio::test]
    async fn should_group_every_offer_under_a_purpose() {
        // Grouping by purpose is how someone picks; an entry with none would
        // fall out of every group and be invisible.
        let listed = call(r#"{"method":"hub/catalog","id":1}"#).await;
        for row in listed["result"]["data"].as_array().expect("data") {
            let purpose = row["purpose"].as_str().unwrap_or("");
            assert!(
                opencli_core::model_catalog::is_known_purpose(purpose),
                "{row} has purpose `{purpose}`"
            );
        }
    }

    #[tokio::test]
    async fn should_explain_what_each_quantisation_costs() {
        // `Q4_K_M` tells a person nothing; a choice without a consequence
        // attached is one nobody can make.
        for quant in ["Q2_K", "Q4_K_M", "Q6_K", "Q8_0"] {
            assert!(
                !describe_quant(quant).is_empty(),
                "{quant} needs a description"
            );
        }
    }

    #[test]
    fn should_rank_quantisations_so_the_best_that_fits_can_be_chosen() {
        assert!(quality_rank("Q8_0") > quality_rank("Q4_K_M"));
        assert!(quality_rank("Q4_K_M") > quality_rank("Q2_K"));
        // Unquantised weights rank below Q8: twice the size for a difference
        // nobody can detect locally, and the memory is better spent on context.
        assert!(
            quality_rank("Q8_0") > quality_rank("FP16"),
            "a big machine should not be steered to the raw weights"
        );
        // Anything unrecognised ranks zero and is left out rather than offered
        // as though its quality were known.
        assert_eq!(quality_rank("Q9_MYSTERY"), 0);
    }

    /// Variants in the order `variants` produces them: worst quality first.
    fn ranked(entries: &[(&str, f64, Option<bool>)]) -> Vec<Value> {
        let mut data: Vec<Value> = entries
            .iter()
            .map(|(quant, gb, fits)| {
                json!({
                    "quant": quant,
                    "tag": format!("hf.co/owner/repo:{quant}"),
                    "sizeGb": gb,
                    "note": describe_quant(quant),
                    "fits": fits,
                })
            })
            .collect();
        data.sort_by_key(|entry| quality_rank(entry["quant"].as_str().unwrap_or("")));
        data
    }

    #[test]
    fn should_suggest_the_best_version_that_fits_the_machine() {
        let data = ranked(&[
            ("Q4_K_M", 4.7, Some(true)),
            ("Q8_0", 8.1, Some(true)),
            ("F16", 15.2, Some(false)),
        ]);
        assert_eq!(
            recommend(&data, true).as_deref(),
            Some("hf.co/owner/repo:Q8_0")
        );
    }

    #[test]
    fn should_fall_back_to_the_smallest_when_nothing_fits() {
        // Better to offer the one with a chance than to offer nothing.
        let data = ranked(&[("Q4_K_M", 40.0, Some(false)), ("Q8_0", 70.0, Some(false))]);
        assert_eq!(
            recommend(&data, true).as_deref(),
            Some("hf.co/owner/repo:Q4_K_M")
        );
    }

    #[test]
    fn should_suggest_the_balanced_version_when_the_machine_is_unknown() {
        // The dangerous case. Treating "unknown" as "it fits" recommended the
        // largest file available, which is the worst guess for a machine
        // nothing is known about.
        let data = ranked(&[
            ("Q4_K_M", 4.7, None),
            ("Q8_0", 8.1, None),
            ("F16", 15.2, None),
        ]);
        assert_eq!(
            recommend(&data, false).as_deref(),
            Some("hf.co/owner/repo:Q4_K_M")
        );
    }

    #[test]
    fn should_suggest_something_when_the_balanced_version_is_not_offered() {
        let data = ranked(&[("Q3_K_M", 3.8, None), ("Q6_K", 6.3, None)]);
        assert!(recommend(&data, false).is_some());
    }

    #[test]
    fn should_suggest_nothing_when_there_are_no_versions() {
        assert_eq!(recommend(&[], true), None);
        assert_eq!(recommend(&[], false), None);
    }

    /// Seed the cache without touching the network.
    fn seed_popular(home: &std::path::Path, count: usize, fetched_at: u64) {
        let models = (0..count)
            .map(|index| {
                json!({
                    "source": "huggingface",
                    "tag": format!("hf.co/owner/model-{index}-GGUF"),
                    "name": format!("owner/model-{index}-GGUF"),
                    "downloads": 1_000_000 - index as u64,
                    "tools": Value::Null,
                    "needsQuant": true,
                })
            })
            .collect();
        write_popular(home, &PopularCache { fetched_at, models });
    }

    #[tokio::test]
    async fn should_offer_models_to_browse_without_being_given_a_search_term() {
        // The point of the whole method: someone looking for a model does not
        // know its name, so an empty query must still return a list.
        let dir = tempdir().expect("tempdir");
        seed_popular(dir.path(), 100, now_seconds());

        let reply = call_in(r#"{"method":"hub/popular","id":1,"params":{}}"#, dir.path()).await;
        let data = reply["result"]["data"].as_array().expect("a list");
        assert_eq!(data.len(), 20, "a first page worth");
        assert_eq!(reply["result"]["total"], 100);
    }

    #[tokio::test]
    async fn should_hand_out_later_pages_from_the_same_fetch() {
        // "Show more" slices what was already fetched, so it is instant and
        // costs the public API nothing.
        let dir = tempdir().expect("tempdir");
        seed_popular(dir.path(), 100, now_seconds());

        let first = call_in(
            r#"{"method":"hub/popular","id":1,"params":{"limit":5,"offset":0}}"#,
            dir.path(),
        )
        .await;
        let second = call_in(
            r#"{"method":"hub/popular","id":1,"params":{"limit":5,"offset":5}}"#,
            dir.path(),
        )
        .await;

        assert_eq!(
            first["result"]["data"][0]["tag"],
            "hf.co/owner/model-0-GGUF"
        );
        assert_eq!(
            second["result"]["data"][0]["tag"],
            "hf.co/owner/model-5-GGUF"
        );
    }

    #[tokio::test]
    async fn should_serve_an_old_list_rather_than_wait_for_a_fresh_one() {
        // Waiting would put an empty panel behind a network call, which is the
        // thing this method exists to avoid. It is shown, and marked.
        let dir = tempdir().expect("tempdir");
        let long_ago = now_seconds() - POPULAR_TTL.as_secs() - 1;
        seed_popular(dir.path(), 30, long_ago);

        let reply = call_in(r#"{"method":"hub/popular","id":1,"params":{}}"#, dir.path()).await;
        assert!(
            !reply["result"]["data"]
                .as_array()
                .expect("a list")
                .is_empty()
        );
        assert_eq!(reply["result"]["stale"], true, "and it must say so");
        assert_eq!(reply["result"]["fetchedAt"], long_ago);
    }

    #[tokio::test]
    async fn should_not_call_a_fresh_list_stale() {
        let dir = tempdir().expect("tempdir");
        seed_popular(dir.path(), 30, now_seconds());
        let reply = call_in(r#"{"method":"hub/popular","id":1,"params":{}}"#, dir.path()).await;
        assert_eq!(reply["result"]["stale"], false);
    }

    #[tokio::test]
    async fn should_ignore_a_corrupt_cache_rather_than_fail() {
        // A broken cache should cost a refetch, never the panel. Proven by the
        // request getting as far as the network instead of returning the junk.
        let dir = tempdir().expect("tempdir");
        std::fs::write(popular_path(dir.path()), "not json at all").expect("write");
        assert!(read_popular(dir.path()).is_none());
    }

    #[test]
    fn should_leave_a_warm_cache_alone() {
        // The startup warm must not refetch on every launch; only a missing or
        // old list is worth a request.
        let dir = tempdir().expect("tempdir");
        seed_popular(dir.path(), 10, now_seconds());
        let before = std::fs::read_to_string(popular_path(dir.path())).expect("read");

        tokio::runtime::Runtime::new()
            .expect("runtime")
            .block_on(warm_popular_cache(dir.path().to_path_buf()));

        let after = std::fs::read_to_string(popular_path(dir.path())).expect("read");
        assert_eq!(before, after, "a fresh cache was refetched");
    }

    #[test]
    fn should_describe_a_hugging_face_model_the_same_way_wherever_it_came_from() {
        // Browsing and searching return the same rows; letting them drift is
        // how one of them starts claiming something the other does not.
        let record = json!({ "id": "owner/Thing-GGUF", "downloads": 42, "likes": 7 });
        let offer = hugging_face_offer(&record).expect("an offer");
        assert_eq!(offer["tag"], "hf.co/owner/Thing-GGUF");
        assert_eq!(offer["downloads"], 42);
        assert_eq!(offer["needsQuant"], true);
        // Only the runtime knows, once installed.
        assert!(offer["tools"].is_null());
    }

    #[test]
    fn should_not_offer_a_projector_as_a_version_of_the_model() {
        // The real file list of ornith-ai/Ornith-1.5-35B-A3B-GGUF. The
        // projector is a genuine .gguf carrying "BF16" in its name at a
        // fortieth of the size, so it read as the best version that fits on a
        // 32 GB machine and was recommended. Installing it downloads something
        // that cannot answer a prompt.
        assert!(!is_model_file("mmproj-Ornith-1.5-35B-BF16.gguf"));
        assert!(is_model_file("Ornith-1.5-35B-BF16.gguf"));
        assert!(is_model_file("Ornith-1.5-35B-Q4_K_M.gguf"));
    }

    #[test]
    fn should_skip_one_part_of_a_split_model() {
        // A shard's size is a fraction of the model's; offering it as a choice
        // would understate what is being downloaded several times over.
        assert!(!is_model_file("Big-Model-Q8_0-00001-of-00003.gguf"));
        assert!(is_model_file("Big-Model-Q8_0.gguf"));
    }

    #[test]
    fn should_look_at_the_file_name_not_the_folder_it_sits_in() {
        // Quantisations are often kept in a directory of their own.
        assert!(is_model_file("Q4_K_M/Model-Q4_K_M.gguf"));
        assert!(!is_model_file("Q4_K_M/mmproj-Model-F16.gguf"));
    }

    #[tokio::test]
    async fn should_require_a_repository_to_list_variants_of() {
        let reply = call(r#"{"method":"hub/variants","id":1,"params":{}}"#).await;
        assert!(reply["error"].is_object());
    }

    #[tokio::test]
    async fn should_require_something_to_search_for() {
        let reply = call(r#"{"method":"hub/search","id":1,"params":{"query":"  "}}"#).await;
        assert!(reply["error"].is_object());
    }

    #[tokio::test]
    async fn should_refuse_a_source_it_does_not_know() {
        let reply =
            call(r#"{"method":"hub/search","id":1,"params":{"query":"x","source":"invented"}}"#)
                .await;
        assert!(reply["error"].is_object());
    }

    #[tokio::test]
    async fn should_send_people_to_modelscope_rather_than_pretend_to_search_it() {
        let reply = call(
            r#"{"method":"hub/search","id":1,"params":{"query":"qwen","source":"modelscope"}}"#,
        )
        .await;
        assert!(reply["result"]["data"].as_array().expect("data").is_empty());
        assert!(
            reply["result"]["hint"]
                .as_str()
                .unwrap_or("")
                .contains("modelscope.cn")
        );
    }
}
