//! What each local model runtime can actually be asked to do.
//!
//! OpenCLI does not run inference; it talks to an OpenAI-compatible endpoint.
//! So "download a model" is really two questions — where the file comes from,
//! and *who fetches it* — and the answer to the second depends entirely on the
//! runtime and on whether it is on this machine.
//!
//! The distinction that matters:
//!
//! - On this machine, any runtime works. We can fetch the file ourselves from
//!   anywhere and hand it over.
//! - On another machine, only a runtime that exposes downloading over HTTP can
//!   be asked to fetch anything, because we have no shell there. Today that is
//!   Ollama alone.
//!
//! Encoding this as data rather than scattering `if runtime == "ollama"` keeps
//! the UI from offering an action that will quietly do nothing.

use serde::Deserialize;
use serde::Serialize;

/// How a runtime can be given a model.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum Acquisition {
    /// The runtime downloads it itself, over its own HTTP API. This is the
    /// only option that works on a machine we have no shell on.
    RemoteApi,
    /// We fetch the file and the runtime is pointed at it. Needs the runtime
    /// to be on this machine, since the file lands on this filesystem.
    LocalFile,
    /// The runtime fetches at launch, from a command we cannot run for the
    /// user. All we can honestly do is show that command.
    LaunchArgument,
    /// The runtime downloads through its own interface only.
    OwnInterface,
}

/// A local inference runtime.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Runtime {
    /// Matches the provider catalogue entry, so a detected runtime can be
    /// turned into a configured provider without a second mapping.
    pub id: &'static str,
    pub name: &'static str,
    pub default_port: u16,
    /// How this runtime is given a model.
    pub acquisition: Acquisition,
    /// Whether it serves a GGUF file given only a path, with no import step.
    pub serves_files_directly: bool,
    /// Whether the installed models can be listed over HTTP.
    pub lists_models: bool,
    /// Whether a model can be deleted over HTTP.
    pub deletes_models: bool,
    /// What to tell someone whose runtime is on another machine.
    pub remote_note: &'static str,
    pub docs: &'static str,
}

pub const RUNTIMES: &[Runtime] = &[
    Runtime {
        id: "ollama",
        name: "Ollama",
        default_port: 11434,
        acquisition: Acquisition::RemoteApi,
        // A file has to be imported with a Modelfile before Ollama will serve
        // it, so pointing at a path is not enough on its own.
        serves_files_directly: false,
        lists_models: true,
        deletes_models: true,
        remote_note: "Downloads and deletions can be driven over HTTP, so a server elsewhere \
                      can be managed from here.",
        docs: "https://ollama.com",
    },
    Runtime {
        id: "llamacpp",
        name: "llama.cpp",
        default_port: 8080,
        acquisition: Acquisition::LocalFile,
        serves_files_directly: true,
        // `llama-server` reports the one model it was started with, not a
        // library, so there is nothing to list or delete.
        lists_models: false,
        deletes_models: false,
        remote_note: "Serves one model chosen when it starts. To change it, run llama-server \
                      again on that machine.",
        docs: "https://github.com/ggml-org/llama.cpp",
    },
    Runtime {
        id: "lmstudio",
        name: "LM Studio",
        default_port: 1234,
        acquisition: Acquisition::OwnInterface,
        serves_files_directly: false,
        lists_models: true,
        deletes_models: false,
        remote_note: "Models are downloaded from LM Studio's own window, or with `lms get`.",
        docs: "https://lmstudio.ai",
    },
    Runtime {
        id: "vllm",
        name: "vLLM",
        default_port: 8000,
        acquisition: Acquisition::LaunchArgument,
        serves_files_directly: false,
        lists_models: true,
        deletes_models: false,
        remote_note: "Fetches its model when it starts. To change it, run `vllm serve <model>` \
                      on that machine.",
        docs: "https://docs.vllm.ai",
    },
];

pub fn find(id: &str) -> Option<&'static Runtime> {
    RUNTIMES.iter().find(|runtime| runtime.id == id)
}

/// Whether a runtime on another machine can be asked to fetch a model.
///
/// The whole reason "download to the server" is possible without a shell.
pub fn can_download_remotely(runtime: &Runtime) -> bool {
    runtime.acquisition == Acquisition::RemoteApi
}

/// Whether an address points at this machine.
///
/// Downloading a file ourselves only helps when the runtime reads the same
/// filesystem, so this decides which of the two paths is even available.
pub fn is_local(base_url: &str) -> bool {
    let authority = base_url
        .split("://")
        .nth(1)
        .unwrap_or(base_url)
        .split('/')
        .next()
        .unwrap_or("");

    // An IPv6 address is bracketed and full of colons, so the port cannot be
    // split off by looking for the last one.
    let host = match authority.strip_prefix('[') {
        Some(rest) => rest.split(']').next().unwrap_or(""),
        None => authority.split(':').next().unwrap_or(""),
    };
    matches!(host, "localhost" | "127.0.0.1" | "::1" | "0.0.0.0")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn should_describe_every_runtime_the_catalogue_offers() {
        for id in ["ollama", "llamacpp", "lmstudio", "vllm"] {
            assert!(find(id).is_some(), "{id} is offered but not described");
        }
    }

    #[test]
    fn should_let_only_ollama_be_driven_on_another_machine() {
        // This is the claim the UI rests on. If another runtime gains an HTTP
        // download API, this test is where that is recorded.
        let remote: Vec<&str> = RUNTIMES
            .iter()
            .filter(|runtime| can_download_remotely(runtime))
            .map(|runtime| runtime.id)
            .collect();
        assert_eq!(remote, vec!["ollama"]);
    }

    #[test]
    fn should_recognise_this_machine_by_address() {
        for local in [
            "http://localhost:11434/v1",
            "http://127.0.0.1:8080",
            "http://[::1]:1234/v1",
        ] {
            assert!(is_local(local), "{local} should be local");
        }
    }

    #[test]
    fn should_treat_a_named_host_as_somewhere_else() {
        // Getting this wrong would offer to download a file onto this disk for
        // a runtime that cannot see it.
        for remote in [
            "http://gpu-box:11434/v1",
            "https://llm.example.com/v1",
            "http://192.168.1.20:11434",
        ] {
            assert!(!is_local(remote), "{remote} should not be local");
        }
    }

    #[test]
    fn should_say_what_to_do_for_a_runtime_it_cannot_drive() {
        // A runtime that cannot be driven remotely must still tell the user
        // what to do, rather than leaving a dead button.
        for runtime in RUNTIMES {
            if !can_download_remotely(runtime) {
                assert!(
                    !runtime.remote_note.is_empty(),
                    "{} needs a note saying what to do instead",
                    runtime.id
                );
            }
        }
    }
}
