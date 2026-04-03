"""Configuration loading and defaults for face-unlock."""

import os
from pathlib import Path

FACE_UNLOCK_DIR = Path.home() / ".face-unlock"
CONFIG_PATH = FACE_UNLOCK_DIR / "config.yaml"

DEFAULTS = {
    "similarity_threshold": 0.5,
    "camera_index": 0,
    "timeout_seconds": 5,
    "model_path": str(FACE_UNLOCK_DIR / "models"),
    "update_channel": "stable",
    "auto_update": True,
    "check_update_interval_hours": 24,
    "min_available_ram_mb": 300,
    "min_cpu_idle_percent": 10,
    "resource_check_enabled": True,
}


def ensure_dirs():
    """Create ~/.face-unlock/ and subdirectories if needed."""
    FACE_UNLOCK_DIR.mkdir(parents=True, exist_ok=True)
    (FACE_UNLOCK_DIR / "models").mkdir(parents=True, exist_ok=True)


def load_config():
    """Load config from ~/.face-unlock/config.yaml, creating defaults if missing."""
    ensure_dirs()

    config = dict(DEFAULTS)

    if CONFIG_PATH.exists():
        try:
            import yaml
            import logging
            with open(CONFIG_PATH, "r") as f:
                user_config = yaml.safe_load(f) or {}
            config.update(user_config)
        except Exception as e:
            logging.getLogger("face-unlock").warning(
                f"Could not parse config file {CONFIG_PATH}: {e}. Using defaults."
            )

    return config


def save_config(config):
    """Save config to ~/.face-unlock/config.yaml."""
    ensure_dirs()
    import yaml
    with open(CONFIG_PATH, "w") as f:
        yaml.dump(config, f, default_flow_style=False, sort_keys=False)


def create_default_config():
    """Create default config file if it doesn't exist."""
    if not CONFIG_PATH.exists():
        save_config(dict(DEFAULTS))
