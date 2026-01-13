import cv2
import os
import socket
import time
import json
import logging
import signal
import sys
import numpy as np
from pathlib import Path

from face_embedder import FaceEmbedder

# Configuration
SOCKET = "/tmp/faceunlock.sock"
MODEL = "/opt/faceunlock/models/arcfaceresnet100-8.onnx"
DATA_DIR = "/var/lib/faceunlock"
THRESHOLD = 0.6  # Adjustable confidence threshold
TIMEOUT = 5.0  # Increased timeout for better accuracy
MAX_ATTEMPTS = 30  # Maximum frame attempts
LOG_FILE = "/var/log/faceunlock.log"

# Check if verbose logging is enabled via environment variable
VERBOSE = os.environ.get('FACEUNLOCK_VERBOSE', '0') == '1'
LOG_LEVEL = logging.DEBUG if VERBOSE else logging.INFO

# Setup logging
logging.basicConfig(
    level=LOG_LEVEL,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE) if os.access('/var/log', os.W_OK) else logging.StreamHandler(),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

if VERBOSE:
    logger.debug("=" * 70)
    logger.debug("Face Unlock Daemon Starting - VERBOSE MODE ENABLED")
    logger.debug("=" * 70)
    logger.debug(f"Python version: {sys.version}")
    logger.debug(f"OpenCV version: {cv2.__version__}")
    logger.debug(f"Configuration:")
    logger.debug(f"  SOCKET: {SOCKET}")
    logger.debug(f"  MODEL: {MODEL}")
    logger.debug(f"  DATA_DIR: {DATA_DIR}")
    logger.debug(f"  THRESHOLD: {THRESHOLD}")
    logger.debug(f"  TIMEOUT: {TIMEOUT}s")
    logger.debug(f"  MAX_ATTEMPTS: {MAX_ATTEMPTS}")
    logger.debug(f"  LOG_FILE: {LOG_FILE}")
    logger.debug("=" * 70)

# Global resources
embedder = None
detector = None
camera_lock = False
logger = logging.getLogger(__name__)

# Global resources
embedder = None
detector = None
camera_lock = False


def initialize():
    """Initialize models and resources"""
    global embedder, detector
    
    try:
        logger.info("Initializing face unlock daemon...")
        
        # Ensure data directory exists
        Path(DATA_DIR).mkdir(parents=True, exist_ok=True)
        
        # Load embedder model
        if not os.path.exists(MODEL):
            logger.error(f"Model file not found: {MODEL}")
            sys.exit(1)
        
        embedder = FaceEmbedder(MODEL)
        logger.info("Face embedder loaded successfully")
        
        # Load face detector
        detector = cv2.CascadeClassifier(
            cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
        )
        
        if detector.empty():
            logger.error("Failed to load face detector")
            sys.exit(1)
        
        logger.info("Face detector loaded successfully")
        
    except Exception as e:
        logger.error(f"Initialization failed: {e}")
        sys.exit(1)


def verify(user):
    """Verify user's face against stored embedding"""
    global camera_lock
    
    if camera_lock:
        logger.warning("Camera is busy")
        return False, 0.0
    
    camera_lock = True
    camera_lock = True
    
    try:
        logger.info(f"Verification request for user: {user}")
        
        # Validate username (prevent path traversal)
        if not user or '/' in user or '\\' in user or user.startswith('.'):
            logger.warning(f"Invalid username format: {user}")
            return False, 0.0
        
        path = Path(DATA_DIR) / f"{user}.npy"

        if not path.exists():
            logger.warning(f"No enrollment data found for user: {user}")
            return False, 0.0

        stored = np.load(path)
        logger.info(f"Loaded stored embedding for {user}")

        cap = cv2.VideoCapture(0)
        
        if not cap.isOpened():
            logger.error("Failed to open camera")
            return False, 0.0
        
        start_time = time.time()
        best_score = 0.0
        attempts = 0

        while time.time() - start_time < TIMEOUT and attempts < MAX_ATTEMPTS:
            ret, frame = cap.read()
            attempts += 1

            if not ret:
                logger.debug(f"Failed to read frame (attempt {attempts})")
                continue

            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            faces = detector.detectMultiScale(gray, 1.3, 5, minSize=(80, 80))

            if len(faces) != 1:
                logger.debug(f"Detected {len(faces)} faces (need exactly 1)")
                continue

            x, y, w, h = faces[0]
            face = frame[y:y+h, x:x+w]

            try:
                emb = embedder.embed(face)
                score = float(np.dot(emb, stored))
                best_score = max(score, best_score)
                
                logger.debug(f"Face match score: {score:.3f} (best: {best_score:.3f})")

                if best_score >= THRESHOLD:
                    logger.info(f"Face verification SUCCESS for {user} (score: {best_score:.3f})")
                    break
                    
            except Exception as e:
                logger.error(f"Error processing face: {e}")
                continue

        cap.release()
        
        success = best_score >= THRESHOLD
        if not success:
            logger.warning(f"Face verification FAILED for {user} (best score: {best_score:.3f}, threshold: {THRESHOLD})")
        
        return success, best_score
        
    except Exception as e:
        logger.error(f"Verification error for {user}: {e}")
        return False, 0.0
    
    finally:
        camera_lock = False


def handle(conn):
    """Handle client connection"""
    try:
        # Set timeout for socket operations
        conn.settimeout(10.0)
        
        data = conn.recv(1024)
        if not data:
            logger.warning("Received empty request")
            resp = {"ok": False, "error": "Empty request"}
            conn.send(json.dumps(resp).encode())
            return
        
        req = json.loads(data.decode('utf-8'))
        user = req.get("user", "").strip()
        
        if not user:
            logger.warning("No username provided in request")
            resp = {"ok": False, "error": "No username"}
        else:
            ok, conf = verify(user)
            resp = {"ok": ok, "confidence": round(conf, 3)}
            
    except json.JSONDecodeError as e:
        logger.error(f"Invalid JSON request: {e}")
        resp = {"ok": False, "error": "Invalid JSON"}
    except socket.timeout:
        logger.error("Socket timeout")
        resp = {"ok": False, "error": "Timeout"}
    except Exception as e:
        logger.error(f"Handler error: {e}")
        resp = {"ok": False, "error": "Internal error"}
    
    try:
        conn.send(json.dumps(resp).encode('utf-8'))
    except Exception as e:
        logger.error(f"Failed to send response: {e}")
        logger.error(f"Failed to send response: {e}")


def cleanup(signum=None, frame=None):
    """Cleanup on shutdown"""
    logger.info("Shutting down daemon...")
    
    if os.path.exists(SOCKET):
        try:
            os.remove(SOCKET)
            logger.info("Socket file removed")
        except Exception as e:
            logger.error(f"Failed to remove socket: {e}")
    
    sys.exit(0)


def main():
    """Main daemon loop"""
    # Setup signal handlers
    signal.signal(signal.SIGINT, cleanup)
    signal.signal(signal.SIGTERM, cleanup)
    
    # Initialize models
    initialize()
    
    # Remove stale socket
    if os.path.exists(SOCKET):
        logger.warning(f"Removing stale socket file: {SOCKET}")
        try:
            os.remove(SOCKET)
        except Exception as e:
            logger.error(f"Failed to remove stale socket: {e}")
            sys.exit(1)

    # Create socket
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.bind(SOCKET)
        os.chmod(SOCKET, 0o666)  # Proper octal notation
        s.listen(5)  # Increased backlog
        logger.info(f"Daemon listening on {SOCKET}")
    except Exception as e:
        logger.error(f"Failed to create socket: {e}")
        sys.exit(1)

    # Main accept loop
    while True:
        try:
            conn, _ = s.accept()
            logger.debug("Client connected")
            handle(conn)
            conn.close()
        except KeyboardInterrupt:
            break
        except Exception as e:
            logger.error(f"Accept loop error: {e}")
            continue
    
    cleanup()


if __name__ == "__main__":
    main()
