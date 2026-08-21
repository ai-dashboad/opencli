use opencli_app_server::run_main;
use opencli_arg0::arg0_dispatch_or_else;
use opencli_common::CliConfigOverrides;
use opencli_core::config_loader::LoaderOverrides;
use std::path::PathBuf;

// Debug-only test hook: lets integration tests point the server at a temporary
// managed config file without writing to /etc.
const MANAGED_CONFIG_PATH_ENV_VAR: &str = "OPENCLI_APP_SERVER_MANAGED_CONFIG_PATH";

fn main() -> anyhow::Result<()> {
    arg0_dispatch_or_else(|opencli_linux_sandbox_exe| async move {
        let managed_config_path = managed_config_path_from_debug_env();
        let loader_overrides = LoaderOverrides {
            managed_config_path,
            ..Default::default()
        };

        run_main(
            opencli_linux_sandbox_exe,
            CliConfigOverrides::default(),
            loader_overrides,
            false,
        )
        .await?;
        Ok(())
    })
}

fn managed_config_path_from_debug_env() -> Option<PathBuf> {
    #[cfg(debug_assertions)]
    {
        if let Ok(value) = std::env::var(MANAGED_CONFIG_PATH_ENV_VAR) {
            return if value.is_empty() {
                None
            } else {
                Some(PathBuf::from(value))
            };
        }
    }

    None
}
