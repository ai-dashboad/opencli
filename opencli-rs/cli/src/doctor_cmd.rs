//! `opencli doctor` — a quick environment health check.
//!
//! Reports on the config home, config file, provider keys, and session store so
//! a user can see at a glance whether the tool is set up correctly.

use std::path::Path;

use anyhow::Result;
use clap::Args;
use opencli_core::config::CONFIG_TOML_FILE;
use opencli_core::config::find_opencli_home;

#[derive(Debug, Args)]
pub struct DoctorArgs {}

/// Each built-in gateway and the environment variable that unlocks it.
const PROVIDER_KEYS: &[(&str, &str)] = &[
    ("CheapestInference", "CHEAPESTINFERENCE_API_KEY"),
    ("OpenRouter", "OPENROUTER_API_KEY"),
    ("Anthropic", "ANTHROPIC_API_KEY"),
    ("DeepSeek", "DEEPSEEK_API_KEY"),
    ("Moonshot", "MOONSHOT_API_KEY"),
    ("Zhipu", "ZHIPU_API_KEY"),
    ("xAI", "XAI_API_KEY"),
    ("Groq", "GROQ_API_KEY"),
    ("Mistral", "MISTRAL_API_KEY"),
    ("Google Gemini", "GEMINI_API_KEY"),
];

pub fn run_main(_args: DoctorArgs) -> Result<()> {
    println!("opencli doctor\n");

    let version = env!("CARGO_PKG_VERSION");
    line("ok", "version", version);

    match find_opencli_home() {
        Ok(home) => {
            line("ok", "config home", &home.display().to_string());
            check_config_file(&home);
            check_sessions(&home);
        }
        Err(err) => line("fail", "config home", &format!("cannot resolve: {err}")),
    }

    println!("\nProviders (a key unlocks that gateway's models in /model):");
    let mut any_key = false;
    for (name, env_key) in PROVIDER_KEYS {
        let present = std::env::var(env_key)
            .ok()
            .is_some_and(|value| !value.trim().is_empty());
        any_key |= present;
        line(
            if present { "ok" } else { "--" },
            name,
            if present { env_key } else { "no key set" },
        );
    }
    if !any_key {
        println!("\n  No provider keys are set. Export at least one *_API_KEY to use a model.");
    }

    Ok(())
}

fn check_config_file(home: &Path) {
    let path = home.join(CONFIG_TOML_FILE);
    if !path.exists() {
        line("--", "config.toml", "not present (built-in defaults apply)");
        return;
    }
    match std::fs::read_to_string(&path) {
        Ok(contents) => match toml::from_str::<toml::Value>(&contents) {
            Ok(_) => line("ok", "config.toml", &path.display().to_string()),
            Err(err) => line("fail", "config.toml", &format!("invalid TOML: {err}")),
        },
        Err(err) => line("fail", "config.toml", &format!("unreadable: {err}")),
    }
}

fn check_sessions(home: &Path) {
    let dir = home.join("sessions");
    if !dir.exists() {
        line("--", "sessions", "none recorded yet");
        return;
    }
    let count = count_rollouts(&dir);
    line("ok", "sessions", &format!("{count} recorded"));
}

/// Count `rollout-*.jsonl` files anywhere under `dir`.
fn count_rollouts(dir: &Path) -> usize {
    let mut count = 0;
    let mut stack = vec![dir.to_path_buf()];
    while let Some(current) = stack.pop() {
        let Ok(entries) = std::fs::read_dir(&current) else {
            continue;
        };
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_dir() {
                stack.push(path);
            } else if path
                .file_name()
                .and_then(|name| name.to_str())
                .is_some_and(|name| name.starts_with("rollout-") && name.ends_with(".jsonl"))
            {
                count += 1;
            }
        }
    }
    count
}

fn line(status: &str, label: &str, detail: &str) {
    let mark = match status {
        "ok" => "[ok]",
        "fail" => "[!!]",
        _ => "[--]",
    };
    println!("  {mark} {label:<14} {detail}");
}
