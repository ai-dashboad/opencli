mod args;
mod error;
mod ipc;
mod resource;

use args::Cli;
use clap::Parser;
use error::Result;

fn main() {
    if let Err(e) = run() {
        eprintln!("Error: {}", e);
        std::process::exit(1);
    }
}

fn run() -> Result<()> {
    let cli = Cli::parse();

    // Ensure daemon resources are extracted
    resource::ensure_daemon_extracted()?;

    // Connect to daemon via IPC
    let mut client = ipc::IpcClient::connect()?;

    // Send request and receive response
    let response = client.send_request(&cli.method, &cli.params)?;

    // Print result
    println!("{}", response.result);

    Ok(())
}
