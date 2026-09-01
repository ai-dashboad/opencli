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

use serde_json::Value;
use serde_json::json;
use std::time::Duration;

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
        tools: params.get("tools").and_then(Value::as_bool).unwrap_or(false),
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
    let source = params.get("source").and_then(Value::as_str).unwrap_or("huggingface");

    match source {
        "huggingface" => search_hugging_face(query).await,
        "modelscope" => Ok(modelscope_hint(query)),
        other => Err(format!("`{other}` is not a source this build knows")),
    }
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
        .map(|models| {
            models
                .iter()
                .filter_map(|model| {
                    let id = model.get("id").and_then(Value::as_str)?;
                    Some(json!({
                        "source": "huggingface",
                        // The runtime resolves this form directly. A quantisation
                        // has to be chosen, which the panel asks for.
                        "tag": format!("hf.co/{id}"),
                        "name": id,
                        "downloads": model.get("downloads"),
                        "likes": model.get("likes"),
                        // Nothing here says whether it calls tools; only the
                        // runtime knows, once installed. Claiming otherwise
                        // would be guessing at the one fact that matters.
                        "tools": Value::Null,
                        "needsQuant": true,
                    }))
                })
                .collect()
        })
        .unwrap_or_default();

    Ok(json!({ "data": data }))
}

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
        // A split file is one part of a set; its size is not the model's, and
        // reporting a shard as a choice would understate it several times over.
        if name.contains("-of-") {
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

    // The best that fits, or the smallest when nothing does — chosen rather
    // than asked for, because "which quantisation" is not a question most
    // people can answer.
    let recommended = data
        .iter()
        .filter(|entry| entry["fits"].as_bool().unwrap_or(true))
        .next_back()
        .or_else(|| data.first())
        .and_then(|entry| entry["tag"].as_str())
        .map(str::to_string);

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

#[cfg(test)]
mod tests {
    use super::*;

    use tempfile::tempdir;

    async fn call_in(raw: &str, home: &std::path::Path) -> Value {
        let reply = handle(raw, home).await.expect("hub methods are handled locally");
        serde_json::from_str(&reply).expect("valid JSON reply")
    }

    async fn call(raw: &str) -> Value {
        let dir = tempdir().expect("tempdir");
        call_in(raw, dir.path()).await
    }

    #[tokio::test]
    async fn should_pass_non_hub_methods_through_to_the_agent() {
        let dir = tempdir().expect("tempdir");
        assert!(handle(r#"{"method":"turn/start","id":1}"#, dir.path()).await.is_none());
        assert!(handle("not json", dir.path()).await.is_none());
    }

    #[tokio::test]
    async fn should_offer_a_library_that_says_what_each_model_is_for() {
        let listed = call(r#"{"method":"hub/catalog","id":1}"#).await;
        let rows = listed["result"]["data"].as_array().expect("data");
        assert!(rows.len() >= 8);
        for row in rows {
            assert!(!row["note"].as_str().unwrap_or("").is_empty(), "{row} needs a note");
            assert!(row["tools"].is_boolean(), "{row} must say whether it calls tools");
            assert!(row["needsGb"].as_f64().unwrap_or(0.0) > 0.0);
        }
    }

    #[tokio::test]
    async fn should_be_honest_about_models_that_cannot_call_tools() {
        // A marketplace that hid this would be selling disappointment: such a
        // model cannot drive the agent's own work.
        let listed = call(r#"{"method":"hub/catalog","id":1}"#).await;
        let rows = listed["result"]["data"].as_array().expect("data");
        let without = rows.iter().find(|row| row["tools"] == false).expect("one is listed");
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
        assert!(rows.iter().all(|row| row["tag"].as_str().unwrap_or("").contains("coder")));
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
        assert!(reply["error"]["message"]
            .as_str()
            .is_some_and(|message| message.contains("note")));
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
            assert!(!describe_quant(quant).is_empty(), "{quant} needs a description");
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
        let reply =
            call(r#"{"method":"hub/search","id":1,"params":{"query":"qwen","source":"modelscope"}}"#)
                .await;
        assert!(reply["result"]["data"].as_array().expect("data").is_empty());
        assert!(reply["result"]["hint"].as_str().unwrap_or("").contains("modelscope.cn"));
    }
}
