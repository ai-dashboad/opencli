"""YAML config manager for ~/.opencli/config.yaml"""

import os
import re
from pathlib import Path
from typing import Any

import yaml


_HOME = Path(os.environ.get("HOME", "."))
CONFIG_DIR = _HOME / ".opencli"
CONFIG_PATH = CONFIG_DIR / "config.yaml"


def _resolve_env_vars(value: Any) -> Any:
    """Resolve ${ENV_VAR} references in string values."""
    if isinstance(value, str):
        def _replace(m: re.Match) -> str:
            return os.environ.get(m.group(1), m.group(0))
        return re.sub(r"\$\{(\w+)\}", _replace, value)
    if isinstance(value, dict):
        return {k: _resolve_env_vars(v) for k, v in value.items()}
    if isinstance(value, list):
        return [_resolve_env_vars(v) for v in value]
    return value


def load_config(resolve_env: bool = True) -> dict:
    """Load config from YAML file. Returns empty dict if file doesn't exist."""
    if not CONFIG_PATH.exists():
        return {}
    with open(CONFIG_PATH) as f:
        data = yaml.safe_load(f) or {}
    if resolve_env:
        data = _resolve_env_vars(data)
    return data


def save_config(config: dict) -> None:
    """Save config dict back to YAML file."""
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    header = "# OpenCLI Configuration\n# Updated by daemon\n\n"
    with open(CONFIG_PATH, "w") as f:
        f.write(header)
        yaml.dump(config, f, default_flow_style=False, allow_unicode=True)


def get_nested(config: dict, dotpath: str, default: Any = None) -> Any:
    """Get a value using dot notation: 'ai_video.api_keys.replicate'"""
    keys = dotpath.split(".")
    current: Any = config
    for key in keys:
        if isinstance(current, dict) and key in current:
            current = current[key]
        else:
            return default
    return current


def deep_merge(target: dict, source: dict) -> dict:
    """Deep merge source into target (mutates target)."""
    for key, value in source.items():
        if isinstance(value, dict) and isinstance(target.get(key), dict):
            deep_merge(target[key], value)
        else:
            target[key] = value
    return target


def mask_api_keys(config: dict) -> dict:
    """Return a copy of config with API key values masked."""
    import copy
    result = copy.deepcopy(config)

    # Mask ai_video.api_keys
    ai_video = result.get("ai_video", {})
    if isinstance(ai_video, dict):
        api_keys = ai_video.get("api_keys", {})
        if isinstance(api_keys, dict):
            for k, v in api_keys.items():
                val = str(v) if v else ""
                if len(val) > 8 and not val.startswith("${"):
                    api_keys[k] = f"****{val[-4:]}"
            ai_video["api_keys"] = api_keys
        result["ai_video"] = ai_video

    # Mask models.*.api_key
    models = result.get("models", {})
    if isinstance(models, dict):
        for mk, mv in models.items():
            if isinstance(mv, dict) and "api_key" in mv:
                val = str(mv["api_key"])
                if len(val) > 8 and not val.startswith("${"):
                    mv["api_key"] = f"****{val[-4:]}"
        result["models"] = models

    return result
