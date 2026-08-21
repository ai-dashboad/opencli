use std::io::ErrorKind;
use std::path::Path;

use crate::error::OpenCLIErr;
use crate::rollout::SESSIONS_SUBDIR;

pub(crate) fn map_session_init_error(err: &anyhow::Error, opencli_home: &Path) -> OpenCLIErr {
    if let Some(mapped) = err
        .chain()
        .filter_map(|cause| cause.downcast_ref::<std::io::Error>())
        .find_map(|io_err| map_rollout_io_error(io_err, opencli_home))
    {
        return mapped;
    }

    OpenCLIErr::Fatal(format!("Failed to initialize session: {err:#}"))
}

fn map_rollout_io_error(io_err: &std::io::Error, opencli_home: &Path) -> Option<OpenCLIErr> {
    let sessions_dir = opencli_home.join(SESSIONS_SUBDIR);
    let hint = match io_err.kind() {
        ErrorKind::PermissionDenied => format!(
            "OpenCLI cannot access session files at {} (permission denied). If sessions were created using sudo, fix ownership: sudo chown -R $(whoami) {}",
            sessions_dir.display(),
            opencli_home.display()
        ),
        ErrorKind::NotFound => format!(
            "Session storage missing at {}. Create the directory or choose a different OpenCLI home.",
            sessions_dir.display()
        ),
        ErrorKind::AlreadyExists => format!(
            "Session storage path {} is blocked by an existing file. Remove or rename it so OpenCLI can create sessions.",
            sessions_dir.display()
        ),
        ErrorKind::InvalidData | ErrorKind::InvalidInput => format!(
            "Session data under {} looks corrupt or unreadable. Clearing the sessions directory may help (this will remove saved threads).",
            sessions_dir.display()
        ),
        ErrorKind::IsADirectory | ErrorKind::NotADirectory => format!(
            "Session storage path {} has an unexpected type. Ensure it is a directory OpenCLI can use for session files.",
            sessions_dir.display()
        ),
        _ => return None,
    };

    Some(OpenCLIErr::Fatal(format!(
        "{hint} (underlying error: {io_err})"
    )))
}
