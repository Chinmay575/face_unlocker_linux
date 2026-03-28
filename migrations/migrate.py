#!/usr/bin/env python3
"""Migration script — runs during updates to handle breaking changes.

This script is executed by the updater before new files are copied.
It should handle any data format changes between versions.
"""

import sys
import os
import json
from pathlib import Path


def check_embedding_format():
    """Check if stored embeddings are compatible with current model."""
    emb_path = Path.home() / ".face-unlock" / "embeddings.npy"
    if not emb_path.exists():
        return

    try:
        import numpy as np
        emb = np.load(str(emb_path))
        if emb.shape[-1] != 512:
            print(f"WARNING: Stored embedding has {emb.shape[-1]} dimensions, "
                  f"expected 512. Re-enrollment required.")
            # Rename old embedding as backup
            backup = emb_path.with_suffix(".npy.old")
            emb_path.rename(backup)
            print(f"  Old embedding backed up to: {backup}")
    except Exception as e:
        print(f"WARNING: Could not check embedding format: {e}")


def check_legacy_embeddings():
    """Check for legacy embeddings from the daemon-based system."""
    legacy_dir = Path("/var/lib/faceunlock")
    if legacy_dir.exists() and any(legacy_dir.glob("*.npy")):
        print("NOTE: Legacy embeddings found at /var/lib/faceunlock/")
        print("  These are from the old ResNet100 model and cannot be reused.")
        print("  Please re-enroll with: face-unlock enroll")


def migrate_config():
    """Migrate from config.ini to config.yaml if needed."""
    old_config = Path("/opt/faceunlock/config.ini")
    new_config = Path.home() / ".face-unlock" / "config.yaml"

    if old_config.exists() and not new_config.exists():
        print("NOTE: Legacy config.ini found. New config uses config.yaml format.")
        print("  Your old settings will need to be migrated manually.")
        print(f"  Old config: {old_config}")
        print(f"  New config: {new_config}")


def main():
    print("Running face-unlock migration...")
    check_embedding_format()
    check_legacy_embeddings()
    migrate_config()
    print("Migration complete.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
