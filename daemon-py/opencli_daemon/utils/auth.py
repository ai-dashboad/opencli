"""SHA256 token verification for WebSocket authentication.

Ported from mobile_connection_manager.dart auth logic.
"""

import hashlib
import time

DEFAULT_AUTH_SECRET = "opencli-dev-secret"
MAX_TIMESTAMP_DRIFT_MS = 300_000  # 5 minutes


def generate_sha256_token(device_id: str, timestamp: int, auth_secret: str) -> str:
    """Generate SHA256(deviceId:timestamp:authSecret)."""
    raw = f"{device_id}:{timestamp}:{auth_secret}"
    return hashlib.sha256(raw.encode()).hexdigest()


def _generate_simple_token(device_id: str, timestamp: int, auth_secret: str) -> str:
    """Generate the legacy simple hash token for backwards compat."""
    raw = f"{device_id}:{timestamp}:{auth_secret}"
    h = 0
    for b in raw.encode():
        h = ((h << 5) - h) + b
        h &= 0xFFFFFFFF
    return format(h, "x")


def verify_token(
    device_id: str,
    timestamp: int,
    token: str,
    auth_secret: str = DEFAULT_AUTH_SECRET,
) -> bool:
    """Verify an auth token. Accepts both SHA256 and simple hash tokens."""
    now_ms = int(time.time() * 1000)
    if abs(now_ms - timestamp) > MAX_TIMESTAMP_DRIFT_MS:
        return False

    sha256_tok = generate_sha256_token(device_id, timestamp, auth_secret)
    if token == sha256_tok:
        return True

    simple_tok = _generate_simple_token(device_id, timestamp, auth_secret)
    return token == simple_tok
