#!/usr/bin/env python3
"""CLI entrypoint for face-unlock.

Usage:
    face-unlock enroll          — enroll your face
    face-unlock test            — test auth without PAM
    face-unlock update          — check for and apply updates
    face-unlock update --check  — just check for updates
    face-unlock version         — show current version
    face-unlock config          — show current config
    face-unlock config --set KEY VALUE — set a config option
    face-unlock status          — show system status
"""

import argparse
import sys


def _show_update_notification():
    """Print update notification if available."""
    try:
        from face_unlock.updater import show_update_notification
        note = show_update_notification()
        if note:
            print(f"\n  {note}\n")
    except Exception:
        pass


def cmd_enroll(args):
    from face_unlock.enroll import enroll
    from face_unlock.config import load_config
    config = load_config()
    success = enroll(samples=args.samples, config=config)
    return 0 if success else 1


def cmd_test(args):
    from face_unlock.auth import authenticate
    result = authenticate()
    if result == 0:
        print("Authentication PASSED")
    else:
        print("Authentication FAILED")
    return result


def cmd_update(args):
    from face_unlock.updater import check_update, apply_update

    if args.check:
        print("Checking for updates...")
        result = check_update()
        if result is None:
            print("Error: could not reach GitHub")
            return 1
        if result["update_available"]:
            print(f"Update available: v{result['local_version']} -> "
                  f"v{result['remote_version']}")
        else:
            print(f"Already up to date (v{result['local_version']})")
        return 0

    print("Checking for updates...")
    result = check_update()
    if result is None:
        print("Error: could not reach GitHub")
        return 1

    if not result["update_available"]:
        print(f"Already up to date (v{result['local_version']})")
        return 0

    print(f"Updating v{result['local_version']} -> v{result['remote_version']}...")
    success, msg = apply_update(result["tag_name"])
    print(msg)
    return 0 if success else 1


def cmd_version(args):
    from face_unlock import __version__
    from face_unlock.updater import get_local_version
    info = get_local_version()
    print(f"face-unlock v{__version__}")
    if info.get("commit_hash"):
        print(f"commit: {info['commit_hash'][:8]}")
    if info.get("updated_at"):
        print(f"updated: {info['updated_at']}")
    return 0


def cmd_config(args):
    from face_unlock.config import load_config, save_config, CONFIG_PATH
    config = load_config()

    if args.set_key:
        key = args.set_key
        value = args.set_value
        if key not in config:
            print(f"Unknown config key: {key}")
            return 1
        # Type coerce based on existing value type
        old_val = config[key]
        if isinstance(old_val, bool):
            value = value.lower() in ("true", "1", "yes")
        elif isinstance(old_val, int):
            value = int(value)
        elif isinstance(old_val, float):
            value = float(value)
        config[key] = value
        save_config(config)
        print(f"Set {key} = {value}")
        return 0

    # Show config
    print(f"Config file: {CONFIG_PATH}")
    print()
    for key, value in config.items():
        print(f"  {key}: {value}")
    return 0


def cmd_status(args):
    import os
    from pathlib import Path
    from face_unlock.config import load_config, FACE_UNLOCK_DIR
    from face_unlock.resource_guard import get_available_ram_mb

    config = load_config()

    print("=== Face Unlock Status ===\n")

    # PAM configured?
    pam_configured = False
    auth_script = Path("/usr/local/bin/face-unlock-auth")
    if auth_script.exists():
        pam_configured = True
        print("  PAM auth script: installed")
    else:
        print("  PAM auth script: NOT installed")

    # Check PAM config
    pam_found = False
    for pam_file in ["/etc/pam.d/gdm-password", "/etc/pam.d/sddm",
                     "/etc/pam.d/lightdm", "/etc/pam.d/login"]:
        if os.path.exists(pam_file):
            try:
                with open(pam_file, "r") as f:
                    if "face-unlock-auth" in f.read():
                        pam_found = True
                        print(f"  PAM config: found in {pam_file}")
                        break
            except PermissionError:
                pass
    if not pam_found:
        print("  PAM config: not configured")

    # Models downloaded?
    model_dir = Path(config["model_path"])
    det = model_dir / "det_500m.onnx"
    rec = model_dir / "w600k_mbf.onnx"
    if det.exists() and rec.exists():
        print("  Models: downloaded")
    else:
        print("  Models: NOT downloaded")

    # Enrollment done?
    emb = FACE_UNLOCK_DIR / "embeddings.npy"
    if emb.exists():
        print("  Enrollment: done")
    else:
        print("  Enrollment: NOT done")

    # Current RAM
    ram = get_available_ram_mb()
    if ram is not None:
        print(f"  Available RAM: {ram:.0f}MB (min: {config.get('min_available_ram_mb', 300)}MB)")
    else:
        print("  Available RAM: unknown")

    # Version
    from face_unlock import __version__
    print(f"  Version: {__version__}")

    print()
    return 0


def main():
    parser = argparse.ArgumentParser(
        prog="face-unlock",
        description="Face Unlock for Linux — on-demand face authentication",
    )
    subparsers = parser.add_subparsers(dest="command")

    # enroll
    p_enroll = subparsers.add_parser("enroll", help="Enroll your face")
    p_enroll.add_argument("-s", "--samples", type=int, default=5,
                          help="Number of samples to capture (default: 5)")

    # test
    subparsers.add_parser("test", help="Test authentication without PAM")

    # update
    p_update = subparsers.add_parser("update", help="Check for and apply updates")
    p_update.add_argument("--check", action="store_true",
                          help="Check only, don't apply")

    # version
    subparsers.add_parser("version", help="Show version info")

    # config
    p_config = subparsers.add_parser("config", help="Show or edit config")
    p_config.add_argument("--set", dest="set_key", metavar="KEY",
                          help="Config key to set")
    p_config.add_argument("set_value", nargs="?", default=None,
                          help="Value to set")

    # status
    subparsers.add_parser("status", help="Show system status")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return 0

    # Show update notification for interactive commands
    if args.command not in ("update",):
        _show_update_notification()

    commands = {
        "enroll": cmd_enroll,
        "test": cmd_test,
        "update": cmd_update,
        "version": cmd_version,
        "config": cmd_config,
        "status": cmd_status,
    }

    handler = commands.get(args.command)
    if handler:
        return handler(args)

    parser.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
