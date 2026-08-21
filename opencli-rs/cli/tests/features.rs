use std::path::Path;

use anyhow::Result;
use predicates::str::contains;
use tempfile::TempDir;

fn opencli_command(opencli_home: &Path) -> Result<assert_cmd::Command> {
    let mut cmd = assert_cmd::Command::new(opencli_utils_cargo_bin::cargo_bin("opencli")?);
    cmd.env("OPENCLI_HOME", opencli_home);
    Ok(cmd)
}

#[tokio::test]
async fn features_enable_writes_feature_flag_to_config() -> Result<()> {
    let opencli_home = TempDir::new()?;

    let mut cmd = opencli_command(opencli_home.path())?;
    cmd.args(["features", "enable", "unified_exec"])
        .assert()
        .success()
        .stdout(contains("Enabled feature `unified_exec` in config.toml."));

    let config = std::fs::read_to_string(opencli_home.path().join("config.toml"))?;
    assert!(config.contains("[features]"));
    assert!(config.contains("unified_exec = true"));

    Ok(())
}

#[tokio::test]
async fn features_disable_writes_feature_flag_to_config() -> Result<()> {
    let opencli_home = TempDir::new()?;

    let mut cmd = opencli_command(opencli_home.path())?;
    cmd.args(["features", "disable", "shell_tool"])
        .assert()
        .success()
        .stdout(contains("Disabled feature `shell_tool` in config.toml."));

    let config = std::fs::read_to_string(opencli_home.path().join("config.toml"))?;
    assert!(config.contains("[features]"));
    assert!(config.contains("shell_tool = false"));

    Ok(())
}

#[tokio::test]
async fn features_enable_under_development_feature_prints_warning() -> Result<()> {
    let opencli_home = TempDir::new()?;

    let mut cmd = opencli_command(opencli_home.path())?;
    cmd.args(["features", "enable", "sqlite"])
        .assert()
        .success()
        .stderr(contains("Under-development features enabled: sqlite."));

    Ok(())
}
