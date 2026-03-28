"""Headless face enrollment — auto-captures frames without GUI."""

import sys
import time
from pathlib import Path


def enroll(samples=5, timeout=30, config=None):
    """Enroll user's face by auto-capturing frames.

    Args:
        samples: number of face samples to capture (default 5)
        timeout: max seconds to wait for enough samples (default 30)
        config: optional config dict (loads default if None)

    Returns:
        True on success, False on failure
    """
    import numpy as np
    import cv2

    from face_unlock.config import load_config, FACE_UNLOCK_DIR
    from face_unlock.detect import FaceDetector
    from face_unlock.recognize import FaceRecognizer
    from face_unlock.utils import download_models, get_logger

    logger = get_logger()

    if config is None:
        config = load_config()

    model_dir = Path(config["model_path"])
    det_model = model_dir / "det_500m.onnx"
    rec_model = model_dir / "w600k_mbf.onnx"

    # Ensure models
    if not det_model.exists() or not rec_model.exists():
        print("Models not found. Downloading...")
        if not download_models(str(model_dir)):
            print("Error: Failed to download models")
            return False

    # Load models
    try:
        detector = FaceDetector(str(det_model))
        recognizer = FaceRecognizer(str(rec_model))
        print("Models loaded successfully")
    except Exception as e:
        print(f"Error: Failed to load models: {e}")
        return False

    # Open camera
    cam_index = config.get("camera_index", 0)
    cap = cv2.VideoCapture(cam_index)
    if not cap.isOpened():
        print(f"Error: Failed to open camera {cam_index}")
        return False

    print(f"\nEnrollment started — capturing {samples} face samples")
    print("Look at the camera. Capturing automatically...")
    print()

    embeddings = []
    start_time = time.time()
    frame_count = 0
    # Skip first few frames to let camera auto-expose
    warmup_frames = 10

    try:
        while len(embeddings) < samples and (time.time() - start_time) < timeout:
            ret, frame = cap.read()
            if not ret:
                continue

            frame_count += 1
            if frame_count <= warmup_frames:
                continue

            # Detect faces
            faces = detector.detect(frame, conf_threshold=0.5)

            if len(faces) == 0:
                continue
            elif len(faces) > 1:
                print(f"  Multiple faces detected ({len(faces)}) — skipping frame")
                continue

            face = faces[0]

            # Check face confidence
            if face["confidence"] < 0.7:
                continue

            try:
                embedding = recognizer.get_embedding(frame, face["landmarks"])
                embeddings.append(embedding)
                print(f"  Captured sample {len(embeddings)}/{samples}")

                # Brief pause between captures for variety
                time.sleep(0.3)

            except Exception as e:
                logger.debug(f"Failed to process frame: {e}")
                continue

    finally:
        cap.release()

    if len(embeddings) < samples:
        print(f"\nError: Only captured {len(embeddings)}/{samples} samples "
              f"in {timeout}s timeout")
        if len(embeddings) == 0:
            print("No faces detected. Check camera and lighting.")
            return False
        print("Proceeding with available samples...")

    if len(embeddings) == 0:
        return False

    # Average embeddings and normalize
    import numpy as np
    final_embedding = np.mean(embeddings, axis=0)
    norm = np.linalg.norm(final_embedding)
    if norm > 0:
        final_embedding = final_embedding / norm

    # Save
    save_path = FACE_UNLOCK_DIR / "embeddings.npy"
    FACE_UNLOCK_DIR.mkdir(parents=True, exist_ok=True)
    np.save(str(save_path), final_embedding)

    print(f"\nEnrollment successful! ({len(embeddings)} samples)")
    print(f"Saved to: {save_path}")

    # Check for legacy embeddings and warn
    legacy_dir = Path("/var/lib/faceunlock")
    if legacy_dir.exists() and any(legacy_dir.glob("*.npy")):
        print("\nNote: Legacy embeddings found at /var/lib/faceunlock/")
        print("These are from the old model and are no longer used.")

    return True
