use crate::error::{OpenCliError, Result};
use serde::{Deserialize, Serialize};

#[cfg(unix)]
use std::io::{Read, Write};

#[cfg(unix)]
use std::os::unix::net::UnixStream;

#[cfg(unix)]
const SOCKET_PATH: &str = "/tmp/opencli.sock";

#[derive(Serialize, Deserialize, Debug)]
pub struct IpcRequest {
    pub method: String,
    pub params: Vec<String>,
    pub context: std::collections::HashMap<String, String>,
    pub request_id: Option<String>,
    pub timeout_ms: Option<u64>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct IpcResponse {
    pub success: bool,
    pub result: String,
    pub duration_us: u64,
    pub cached: bool,
    pub request_id: Option<String>,
    pub error: Option<String>,
}

pub struct IpcClient {
    #[cfg(unix)]
    stream: UnixStream,
}

impl IpcClient {
    pub fn connect() -> Result<Self> {
        #[cfg(unix)]
        {
            let stream =
                UnixStream::connect(SOCKET_PATH).map_err(|_| OpenCliError::DaemonNotRunning)?;

            Ok(Self { stream })
        }

        #[cfg(windows)]
        {
            // Windows named pipe implementation
            unimplemented!("Windows support coming soon")
        }
    }

    pub fn send_request(&mut self, method: &str, params: &[String]) -> Result<IpcResponse> {
        #[cfg(unix)]
        {
            let request = IpcRequest {
                method: method.to_string(),
                params: params.to_vec(),
                context: std::collections::HashMap::new(),
                request_id: Some(uuid::Uuid::new_v4().to_string()),
                timeout_ms: Some(30000),
            };

            let payload = rmp_serde::to_vec(&request)?;
            let length = (payload.len() as u32).to_le_bytes();

            self.stream.write_all(&length)?;
            self.stream.write_all(&payload)?;
            self.stream.flush()?;

            let mut len_buf = [0u8; 4];
            self.stream.read_exact(&mut len_buf)?;
            let response_len = u32::from_le_bytes(len_buf) as usize;

            let mut response_buf = vec![0u8; response_len];
            self.stream.read_exact(&mut response_buf)?;

            let response: IpcResponse = rmp_serde::from_slice(&response_buf)?;

            if !response.success {
                return Err(OpenCliError::RequestFailed(
                    response
                        .error
                        .unwrap_or_else(|| "Unknown error".to_string()),
                ));
            }

            Ok(response)
        }

        #[cfg(windows)]
        {
            let _ = (method, params);
            Err(OpenCliError::RequestFailed(
                "Windows IPC support is not yet implemented".to_string(),
            ))
        }
    }
}

// UUID generation helper
mod uuid {
    use std::fmt;

    pub struct Uuid;

    impl Uuid {
        pub fn new_v4() -> Self {
            Uuid
        }
    }

    impl fmt::Display for Uuid {
        fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
            use std::time::{SystemTime, UNIX_EPOCH};
            let timestamp = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_nanos();
            write!(f, "{:x}", timestamp)
        }
    }
}
