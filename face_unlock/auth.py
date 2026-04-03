#!/usr/bin/env python3
"""PAM authentication script for face-unlock.

CRITICAL EXECUTION ORDER:
1. Stdlib-only imports + config load (yaml only)
2. Resource guard check — exit 1 immediately if resources low
3. Only THEN import heavy libraries (onnxruntime, cv2, numpy)
4. Open camera → detect face → extract embedding → compare → exit

This script is called by pam_exec.so via the face-unlock-auth wrapper.
Exit code 0 = PAM_SUCCESS, 1 = PAM_AUTH_ERR (falls through to password).
"""

import os
import sys
import time
import logging

# --- Step 1: Load config (lightweight, yaml only) ---
def _load_config_safe():
    """Load config using only yaml. No heavy imports."""
    try:
        from face_unlock.config import load_config
        return load_config()
    except Exception:
        # Return defaults if config loading fails
        return {
            "similarity_threshold": 0.5,
            "camera_index": 0,
            "timeout_seconds": 5,
            "model_path": os.path.expanduser("~/.face-unlock/models"),
            "min_available_ram_mb": 300,
            "min_cpu_idle_percent": 10,
            "resource_check_enabled": True,
            "auto_update": True,
            "check_update_interval_hours": 24,
        }


# --- Step 2: Resource guard (stdlib only, ZERO heavy imports) ---
def _check_resources(config):
    """Run resource guard. Returns (ok, reason)."""
    from face_unlock.resource_guard import check_resources
    return check_resources(config)


def _get_username():
    """Get the authenticating username from PAM environment."""
    # pam_exec.so sets PAM_USER
    user = os.environ.get("PAM_USER")
    if user:
        return user
    # Fallback for testing
    try:
        return os.getlogin()
    except OSError:
        import getpass
        return getpass.getuser()


def _setup_logging():
    """Setup minimal logging for auth."""
    handlers = [logging.StreamHandler(sys.stderr)]
    try:
        if os.access("/var/log", os.W_OK):
            handlers.append(logging.FileHandler("/var/log/face-unlock.log"))
    except Exception:
        pass
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(levelname)s - %(message)s",
        handlers=handlers,
    )
    return logging.getLogger("face-unlock-auth")


def _trigger_background_update_check(config):
    """Fork a background process to check for updates (non-blocking)."""
    if not config.get("auto_update", True):
        return

    flag_dir = os.path.expanduser("~/.face-unlock")
    last_check_file = os.path.join(flag_dir, ".last-update-check")

    # Check if enough time has passed since last check
    interval_hours = config.get("check_update_interval_hours", 24)
    try:
        if os.path.exists(last_check_file):
            last_check = os.path.getmtime(last_check_file)
            elapsed_hours = (time.time() - last_check) / 3600
            if elapsed_hours < interval_hours:
                return
    except Exception:
        pass

    # Double-fork to background: avoids zombie processes (grandchild is
    # re-parented to init when its parent exits immediately).
    pid = os.fork()
    if pid == 0:
        # First child — fork again then exit so grandchild is orphaned to init
        try:
            os.setsid()
            gpid = os.fork()
            if gpid != 0:
                # First child exits; grandchild is now owned by init
                os._exit(0)

            # Grandchild — do the actual update check
            try:
                sys.stdin.close()
                sys.stdout.close()
                sys.stderr.close()

                from face_unlock.updater import check_update
                result = check_update()

                # Touch last-check file
                os.makedirs(flag_dir, exist_ok=True)
                with open(last_check_file, "w") as f:
                    f.write(str(time.time()))

                if result and result.get("update_available"):
                    flag_path = os.path.join(flag_dir, ".update-available")
                    import json
                    with open(flag_path, "w") as f:
                        json.dump(result, f)

            except Exception:
                pass
            finally:
                os._exit(0)
        except Exception:
            os._exit(0)

    # Parent waits only for the short-lived first child (not the grandchild)
    os.waitpid(pid, 0)


def authenticate():
    """Main PAM authentication flow."""
    logger = _setup_logging()

    # Step 1: Load config
    config = _load_config_safe()

    # Step 2: Resource guard — BEFORE any heavy imports
    ok, reason = _check_resources(config)
    if not ok:
        logger.warning(reason)
        return 1

    logger.debug(reason)  # Log resource check result

    # Step 3: NOW import heavy libraries
    try:
        import numpy as np
        import cv2
    except ImportError as e:
        logger.error(f"Missing dependency: {e}")
        return 1

    from face_unlock.detect import FaceDetector
    from face_unlock.recognize import FaceRecognizer
    from face_unlock.utils import cosine_similarity, download_models
    from pathlib import Path

    # Get username
    username = _get_username()
    if not username:
        logger.error("Could not determine username")
        return 1

    logger.info(f"Face auth attempt for user: {username}")

    # Check for stored embeddings
    embedding_path = Path.home() / ".face-unlock" / "embeddings.npy"

    # Also check legacy path
    legacy_path = Path(f"/var/lib/faceunlock/{username}.npy")
    if not embedding_path.exists() and legacy_path.exists():
        logger.warning("Found legacy embedding — re-enrollment required with new model")
        return 1

    if not embedding_path.exists():
        logger.warning(f"No enrollment data found for {username}")
        return 1

    try:
        stored_embedding = np.load(str(embedding_path))
    except Exception as e:
        logger.error(f"Failed to load embedding: {e}")
        return 1

    # Validate embedding dimensions
    if stored_embedding.shape[-1] != 512:
        logger.warning("Stored embedding has wrong dimensions — re-enrollment required")
        return 1

    # Ensure models exist
    model_dir = Path(config["model_path"])
    det_model = model_dir / "det_500m.onnx"
    rec_model = model_dir / "w600k_mbf.onnx"

    if not det_model.exists() or not rec_model.exists():
        logger.info("Models not found, attempting download...")
        if not download_models(str(model_dir)):
            logger.error("Model download failed")
            return 1

    # Load models
    try:
        detector = FaceDetector(str(det_model))
        recognizer = FaceRecognizer(str(rec_model))
    except Exception as e:
        logger.error(f"Failed to load models: {e}")
        return 1

    # Open camera
    cap = cv2.VideoCapture(config.get("camera_index", 0))
    if not cap.isOpened():
        logger.error("Failed to open camera")
        return 1

    try:
        start_time = time.time()
        timeout = config.get("timeout_seconds", 5)
        best_score = 0.0
        threshold = config.get("similarity_threshold", 0.5)

        while time.time() - start_time < timeout:
            ret, frame = cap.read()
            if not ret:
                continue

            # Detect faces
            faces = detector.detect(frame, conf_threshold=0.5)

            if len(faces) != 1:
                continue

            face = faces[0]

            # Extract embedding with landmark alignment
            embedding = recognizer.get_embedding(frame, face["landmarks"])

            # Compare
            score = cosine_similarity(embedding, stored_embedding)
            best_score = max(best_score, score)

            logger.debug(f"Face match score: {score:.3f} (best: {best_score:.3f})")

            if best_score >= threshold:
                logger.info(
                    f"Face auth SUCCESS for {username} (score: {best_score:.3f})"
                )
                # Trigger background update check after success
                _trigger_background_update_check(config)
                return 0

        logger.warning(
            f"Face auth FAILED for {username} "
            f"(best: {best_score:.3f}, threshold: {threshold})"
        )
        return 1

    except Exception as e:
        logger.error(f"Auth error: {e}")
        return 1
    finally:
        cap.release()


def main():
    sys.exit(authenticate())


if __name__ == "__main__":
    main()
