use clap::Parser;

#[derive(Parser, Debug)]
#[command(name = "opencli")]
#[command(author = "cw <cw@dtok.io>")]
#[command(version = "0.1.0")]
#[command(about = "Universal AI Development Platform", long_about = None)]
pub struct Cli {
    /// Method to call (e.g., "chat", "flutter.launch")
    #[arg(default_value = "chat")]
    pub method: String,

    /// Parameters for the method
    #[arg(trailing_var_arg = true)]
    pub params: Vec<String>,

    /// Timeout in milliseconds
    #[arg(short, long, default_value = "30000")]
    pub timeout: u64,

    /// Verbose output
    #[arg(short, long)]
    pub verbose: bool,
}
