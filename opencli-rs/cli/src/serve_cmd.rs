//! `opencli serve` — expose the agent over WebSocket for a browser or desktop UI.

use anyhow::Result;
use clap::Args;
use opencli_web_gateway::ServeConfig;
use std::net::IpAddr;

#[derive(Debug, Args)]
pub struct ServeArgs {
    /// Address to bind. Defaults to loopback; a client of this server can run
    /// commands on this machine, so binding publicly is opt-in.
    #[arg(long, default_value = "127.0.0.1")]
    host: IpAddr,

    /// Port to listen on. 0 picks a free one.
    #[arg(long, default_value_t = 4517)]
    port: u16,

    /// Disable the connection token. Only allowed on a loopback bind.
    #[arg(long)]
    no_auth: bool,
}

pub async fn run_main(args: ServeArgs) -> Result<()> {
    opencli_web_gateway::serve(ServeConfig {
        host: args.host,
        port: args.port,
        server_bin: None,
        no_auth: args.no_auth,
        // Scheduled tasks live beside the rest of the user's config.
        opencli_home: opencli_core::config::find_opencli_home().ok(),
    })
    .await
}
