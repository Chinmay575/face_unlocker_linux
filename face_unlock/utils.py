"""Shared utilities: logging, cosine similarity, model downloads."""

import logging
import os
import sys
from pathlib import Path

LOG_FILE = "/var/log/face-unlock.log"


def setup_logging(verbose=False):
    """Configure logging to file and stderr."""
    level = logging.DEBUG if verbose else logging.INFO
    handlers = [logging.StreamHandler(sys.stderr)]

    try:
        if os.access("/var/log", os.W_OK):
            handlers.append(logging.FileHandler(LOG_FILE))
    except Exception:
        pass

    logging.basicConfig(
        level=level,
        format="%(asctime)s - %(levelname)s - %(message)s",
        handlers=handlers,
    )
    return logging.getLogger("face-unlock")


def get_logger():
    """Get the face-unlock logger."""
    logger = logging.getLogger("face-unlock")
    if not logger.handlers:
        setup_logging()
    return logger


def cosine_similarity(a, b):
    """Compute cosine similarity between two vectors using numpy."""
    import numpy as np
    a = a.flatten()
    b = b.flatten()
    norm_a = np.linalg.norm(a)
    norm_b = np.linalg.norm(b)
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return float(np.dot(a, b) / (norm_a * norm_b))


def download_models(model_dir):
    """Download InsightFace buffalo_s model pack if models are missing."""
    model_dir = Path(model_dir)
    det_path = model_dir / "det_500m.onnx"
    rec_path = model_dir / "w600k_mbf.onnx"

    if det_path.exists() and rec_path.exists():
        return True

    logger = get_logger()
    logger.info("Downloading InsightFace buffalo_s model pack...")

    import tempfile
    import zipfile
    import requests

    url = "https://github.com/deepinsight/insightface/releases/download/v0.7/buffalo_s.zip"
    model_dir.mkdir(parents=True, exist_ok=True)

    try:
        tmp_zip = tempfile.NamedTemporaryFile(delete=False, suffix=".zip")
        tmp_zip_path = tmp_zip.name
        tmp_zip.close()

        response = requests.get(url, stream=True, timeout=120)
        response.raise_for_status()

        total = int(response.headers.get("content-length", 0))
        downloaded = 0

        with open(tmp_zip_path, "wb") as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
                downloaded += len(chunk)
                if total > 0:
                    pct = (downloaded / total) * 100
                    print(f"\rDownloading models: {pct:.1f}%", end="", flush=True)

        print()  # newline after progress

        with zipfile.ZipFile(tmp_zip_path, "r") as zf:
            for member in zf.namelist():
                basename = os.path.basename(member)
                if basename in ("det_500m.onnx", "w600k_mbf.onnx"):
                    target = model_dir / basename
                    with zf.open(member) as src, open(target, "wb") as dst:
                        dst.write(src.read())
                    logger.info(f"Extracted {basename}")

        os.unlink(tmp_zip_path)

        if det_path.exists() and rec_path.exists():
            logger.info("Models downloaded successfully")
            return True
        else:
            logger.error("Model extraction failed — expected files not found in zip")
            return False

    except Exception as e:
        logger.error(f"Model download failed: {e}")
        if os.path.exists(tmp_zip_path):
            os.unlink(tmp_zip_path)
        return False
