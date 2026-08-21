use opencli_arg0::arg0_dispatch_or_else;
use opencli_common::CliConfigOverrides;
use opencli_mcp_server::run_main;

fn main() -> anyhow::Result<()> {
    arg0_dispatch_or_else(|opencli_linux_sandbox_exe| async move {
        run_main(opencli_linux_sandbox_exe, CliConfigOverrides::default()).await?;
        Ok(())
    })
}
