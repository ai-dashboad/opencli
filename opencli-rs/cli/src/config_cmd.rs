//! `opencli config` — read and edit `config.toml` from the command line.
//!
//! Editing preserves formatting and comments (via `toml_edit`), so hand-written
//! config with comments survives a `set`.

use anyhow::Context;
use anyhow::Result;
use anyhow::bail;
use clap::Args;
use clap::Subcommand;
use opencli_core::config::CONFIG_TOML_FILE;
use opencli_core::config::find_opencli_home;

#[derive(Debug, Args)]
pub struct ConfigArgs {
    #[command(subcommand)]
    pub cmd: ConfigSubcommand,
}

#[derive(Debug, Subcommand)]
pub enum ConfigSubcommand {
    /// Print the path to config.toml.
    Path,
    /// Print the whole config.toml.
    List,
    /// Print one top-level value, e.g. `config get model`.
    Get { key: String },
    /// Set one top-level value, e.g. `config set model glm-5.2`. The value is
    /// parsed as TOML, falling back to a string when it does not parse.
    Set { key: String, value: String },
}

pub fn run_main(args: ConfigArgs) -> Result<()> {
    let home = find_opencli_home().context("resolve config home")?;
    let path = home.join(CONFIG_TOML_FILE);

    match args.cmd {
        ConfigSubcommand::Path => {
            println!("{}", path.display());
        }
        ConfigSubcommand::List => {
            let contents = std::fs::read_to_string(&path)
                .with_context(|| format!("read {}", path.display()))?;
            print!("{contents}");
        }
        ConfigSubcommand::Get { key } => {
            let contents = std::fs::read_to_string(&path).unwrap_or_default();
            let doc: toml_edit::DocumentMut = contents.parse().context("parse config.toml")?;
            match doc.get(&key) {
                Some(item) => println!("{}", item.to_string().trim()),
                None => bail!("key `{key}` is not set"),
            }
        }
        ConfigSubcommand::Set { key, value } => {
            let contents = std::fs::read_to_string(&path).unwrap_or_default();
            let mut doc: toml_edit::DocumentMut =
                contents.parse().context("parse config.toml")?;
            doc[&key] = parse_value(&value);
            std::fs::write(&path, doc.to_string())
                .with_context(|| format!("write {}", path.display()))?;
            println!("set {key} = {}", doc[&key].to_string().trim());
        }
    }
    Ok(())
}

/// Parse `raw` as a TOML scalar, falling back to a plain string. This mirrors
/// how the `-c key=value` overrides behave.
fn parse_value(raw: &str) -> toml_edit::Item {
    if let Ok(value) = raw.parse::<bool>() {
        return toml_edit::value(value);
    }
    if let Ok(value) = raw.parse::<i64>() {
        return toml_edit::value(value);
    }
    if let Ok(value) = raw.parse::<f64>() {
        return toml_edit::value(value);
    }
    toml_edit::value(raw)
}
