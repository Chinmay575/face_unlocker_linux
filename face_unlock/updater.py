"""Self-update system for face-unlock.

Checks GitHub releases, downloads updates, applies atomically with rollback.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

GITHUB_REPO = "chinmay-singh-modak/face_unlocker_linux"
GITHUB_API_URL = f"https://api.github.com/repos/{GITHUB_REPO}"
INSTALL_DIR = Path("/opt/face-unlock")
BACKUP_DIR = INSTALL_DIR / ".backup"
USER_DIR = Path.home() / ".face-unlock"
VERSION_FILE = USER_DIR / "version.json"


def get_local_version():
    """Read local version info from version.json."""
    if VERSION_FILE.exists():
        try:
            with open(VERSION_FILE, "r") as f:
                return json.load(f)
        except Exception:
            pass

    # Fallback to package version
    try:
        from face_unlock import __version__
        return {"version": __version__, "commit_hash": "", "updated_at": ""}
    except Exception:
        return {"version": "0.0.0", "commit_hash": "", "updated_at": ""}


def check_update():
    """Check GitHub for available updates.

    Returns:
        dict with keys: update_available (bool), local_version, remote_version,
        tag_name, download_url. Or None on failure.
    """
    import requests

    local = get_local_version()
    local_version = local.get("version", "0.0.0")

    try:
        # Try releases first
        resp = requests.get(
            f"{GITHUB_API_URL}/releases/latest",
            timeout=10,
            headers={"Accept": "application/vnd.github.v3+json"},
        )

        if resp.status_code == 200:
            data = resp.json()
            remote_version = data.get("tag_name", "").lstrip("v")
            return {
                "update_available": _version_newer(remote_version, local_version),
                "local_version": local_version,
                "remote_version": remote_version,
                "tag_name": data.get("tag_name", ""),
                "html_url": data.get("html_url", ""),
            }

        # Fallback: check tags
        resp = requests.get(
            f"{GITHUB_API_URL}/tags",
            timeout=10,
            headers={"Accept": "application/vnd.github.v3+json"},
        )

        if resp.status_code == 200:
            tags = resp.json()
            if tags:
                latest_tag = tags[0]["name"].lstrip("v")
                return {
                    "update_available": _version_newer(latest_tag, local_version),
                    "local_version": local_version,
                    "remote_version": latest_tag,
                    "tag_name": tags[0]["name"],
                    "html_url": f"https://github.com/{GITHUB_REPO}/releases/tag/{tags[0]['name']}",
                }

        return {
            "update_available": False,
            "local_version": local_version,
            "remote_version": local_version,
            "tag_name": "",
            "html_url": "",
        }

    except Exception as e:
        return None


def _version_newer(remote, local):
    """Compare semver strings. Returns True if remote > local."""
    try:
        r = [int(x) for x in remote.split(".")]
        l = [int(x) for x in local.split(".")]
        # Pad to same length
        while len(r) < 3:
            r.append(0)
        while len(l) < 3:
            l.append(0)
        return tuple(r) > tuple(l)
    except (ValueError, AttributeError):
        return False


def apply_update(tag_name=None):
    """Download and apply an update.

    Args:
        tag_name: specific tag to update to. If None, uses latest.

    Returns:
        (success, message)
    """
    if tag_name is None:
        result = check_update()
        if result is None:
            return False, "Failed to check for updates"
        if not result["update_available"]:
            return True, "Already up to date"
        tag_name = result["tag_name"]

    # Check if we need sudo for install dir
    needs_sudo = not os.access(str(INSTALL_DIR.parent), os.W_OK)

    tmp_dir = None
    try:
        # Clone to temp directory
        tmp_dir = tempfile.mkdtemp(prefix="face-unlock-update-")
        print(f"Cloning {tag_name}...")

        clone_url = f"https://github.com/{GITHUB_REPO}.git"
        result = subprocess.run(
            ["git", "clone", "--depth", "1", "--branch", tag_name, clone_url, tmp_dir],
            capture_output=True, text=True, timeout=120,
        )

        if result.returncode != 0:
            # Try without --branch (tag might not match)
            result = subprocess.run(
                ["git", "clone", "--depth", "1", clone_url, tmp_dir],
                capture_output=True, text=True, timeout=120,
            )
            if result.returncode != 0:
                return False, f"Git clone failed: {result.stderr}"

        # Run migration if present
        migrate_script = Path(tmp_dir) / "migrations" / "migrate.py"
        if migrate_script.exists():
            print("Running migration script...")
            result = subprocess.run(
                [sys.executable, str(migrate_script)],
                capture_output=True, text=True, timeout=60,
            )
            if result.returncode != 0:
                return False, f"Migration failed: {result.stderr}"

        # Backup current installation
        if INSTALL_DIR.exists():
            print("Backing up current installation...")
            if BACKUP_DIR.exists():
                shutil.rmtree(str(BACKUP_DIR))
            shutil.copytree(str(INSTALL_DIR), str(BACKUP_DIR),
                            ignore=shutil.ignore_patterns(".backup"))

        # Copy new files to install dir
        print("Installing update...")
        src_dir = Path(tmp_dir)

        # Files/dirs to copy
        targets = ["face_unlock", "scripts", "migrations", "version.json",
                    "requirements.txt", "Makefile", "README.md"]

        for target in targets:
            src = src_dir / target
            dst = INSTALL_DIR / target
            if not src.exists():
                continue

            if dst.exists():
                if dst.is_dir():
                    shutil.rmtree(str(dst))
                else:
                    dst.unlink()

            if src.is_dir():
                shutil.copytree(str(src), str(dst))
            else:
                INSTALL_DIR.mkdir(parents=True, exist_ok=True)
                shutil.copy2(str(src), str(dst))

        # Update auth script if present
        auth_wrapper = src_dir / "scripts" / "face-unlock-auth"
        if auth_wrapper.exists():
            dest_auth = Path("/usr/local/bin/face-unlock-auth")
            if needs_sudo:
                subprocess.run(
                    ["sudo", "cp", str(auth_wrapper), str(dest_auth)],
                    check=True,
                )
                subprocess.run(
                    ["sudo", "chmod", "+x", str(dest_auth)],
                    check=True,
                )
            else:
                shutil.copy2(str(auth_wrapper), str(dest_auth))
                os.chmod(str(dest_auth), 0o755)

        # Update version.json
        new_version = tag_name.lstrip("v")
        version_info = {
            "version": new_version,
            "commit_hash": _get_commit_hash(tmp_dir),
            "updated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        }
        USER_DIR.mkdir(parents=True, exist_ok=True)
        with open(VERSION_FILE, "w") as f:
            json.dump(version_info, f, indent=2)

        # Remove update-available flag
        flag = USER_DIR / ".update-available"
        if flag.exists():
            flag.unlink()

        print(f"Updated to {new_version}")
        return True, f"Updated to {new_version}"

    except Exception as e:
        # Rollback on failure
        if BACKUP_DIR.exists():
            print("Update failed, rolling back...")
            if INSTALL_DIR.exists():
                shutil.rmtree(str(INSTALL_DIR))
            shutil.copytree(str(BACKUP_DIR), str(INSTALL_DIR))
            shutil.rmtree(str(BACKUP_DIR))
        return False, f"Update failed: {e}"

    finally:
        if tmp_dir and os.path.exists(tmp_dir):
            shutil.rmtree(tmp_dir)


def _get_commit_hash(repo_dir):
    """Get the HEAD commit hash from a git repo."""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            capture_output=True, text=True, cwd=repo_dir,
        )
        return result.stdout.strip()
    except Exception:
        return ""


def show_update_notification():
    """Show update notification if available. Returns notification string or None."""
    flag = USER_DIR / ".update-available"
    if not flag.exists():
        return None
    try:
        with open(flag, "r") as f:
            data = json.load(f)
        if data.get("update_available"):
            local = data.get("local_version", "?")
            remote = data.get("remote_version", "?")
            return (
                f"Update available: v{local} -> v{remote}. "
                f"Run `face-unlock update` to apply."
            )
    except Exception:
        pass
    return None
