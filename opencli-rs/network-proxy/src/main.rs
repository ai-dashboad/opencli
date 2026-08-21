use anyhow::Result;
use clap::Parser;
use opencli_network_proxy::Args;
use opencli_network_proxy::NetworkProxy;

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt::init();

    let args = Args::parse();
    let _ = args;
    let proxy = NetworkProxy::builder().build().await?;
    proxy.run().await?.wait().await
}
