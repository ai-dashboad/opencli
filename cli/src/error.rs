use thiserror::Error;

pub type Result<T> = std::result::Result<T, OpenCliError>;

#[derive(Error, Debug)]
pub enum OpenCliError {
    #[error("IPC connection failed: {0}")]
    IpcConnectionFailed(String),

    #[error("Request failed: {0}")]
    RequestFailed(String),

    #[error("Serialization error: {0}")]
    SerializationError(#[from] rmp_serde::encode::Error),

    #[error("Deserialization error: {0}")]
    DeserializationError(#[from] rmp_serde::decode::Error),

    #[error("IO error: {0}")]
    IoError(#[from] std::io::Error),

    #[error("Daemon not running. Start with: opencli daemon start")]
    DaemonNotRunning,

    #[error("Resource extraction failed: {0}")]
    ResourceError(String),
}

impl OpenCliError {
    pub fn suggest_fix(&self) -> Option<String> {
        match self {
            OpenCliError::DaemonNotRunning => Some("Try running: opencli daemon start".to_string()),
            OpenCliError::IpcConnectionFailed(_) => {
                Some("Check if daemon is running: opencli daemon status".to_string())
            }
            _ => None,
        }
    }
}
