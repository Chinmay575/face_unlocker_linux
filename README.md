# Face Unlock for Linux

On-demand face authentication for Linux using lightweight ONNX models. Uses PAM integration to unlock your screen, sudo, and login with your face.

## Architecture

Unlike traditional daemon-based approaches, face-unlock runs **on-demand** via `pam_exec.so`:

1. PAM triggers the auth script
2. Resource guard checks RAM/CPU (~50ms for CPU sampling, stdlib only)
3. If resources OK: camera -> face detection -> embedding -> comparison
4. Returns result, exits immediately -- no lingering process

**RAM usage**: ~150MB during inference (vs ~4GB for daemon-based approaches)

## Models

Uses InsightFace's **buffalo_s** bundle:
- **RetinaFace-MobileNet** (`det_500m.onnx`) -- face detection
- **MobileFaceNet** (`w600k_mbf.onnx`) -- face recognition (512-dim embeddings)

Models are auto-downloaded on first use (~30MB total).

## Installation

```bash
git clone https://github.com/chinmay-singh-modak/face_unlocker_linux.git
cd face_unlocker_linux
sudo bash scripts/install.sh
```

Or using make:
```bash
make install
```

## Usage

### CLI Commands

```bash
face-unlock enroll          # Enroll your face (captures 5 samples)
face-unlock test            # Test authentication without PAM
face-unlock update          # Check for and apply updates
face-unlock update --check  # Just check for updates
face-unlock version         # Show version info
face-unlock config          # Show current configuration
face-unlock config --set similarity_threshold 0.6
face-unlock status          # Show system status
```

### Enrollment

```bash
face-unlock enroll              # Default: 5 samples
face-unlock enroll -s 10        # 10 samples for better accuracy
```

Enrollment automatically captures face samples -- just look at the camera.

## Configuration

Config file: `~/.face-unlock/config.yaml`

| Option | Default | Description |
|--------|---------|-------------|
| `similarity_threshold` | 0.5 | Match threshold (0.0-1.0) |
| `camera_index` | 0 | Camera device index |
| `timeout_seconds` | 5 | Max auth attempt duration |
| `model_path` | `~/.face-unlock/models/` | ONNX model directory |
| `min_available_ram_mb` | 300 | Skip auth if RAM below this |
| `min_cpu_idle_percent` | 10 | Skip auth if CPU too busy |
| `resource_check_enabled` | true | Enable/disable resource guard |
| `auto_update` | true | Check for updates after auth |
| `check_update_interval_hours` | 24 | Hours between update checks |

## Resource Guard

Before any inference, the auth script checks system resources:
- Reads `/proc/meminfo` for available RAM
- Reads `/proc/stat` for CPU idle percentage
- Uses only stdlib (zero heavy library overhead)
- CPU idle sampling takes ~50ms (two `/proc/stat` reads 50ms apart)
- If resources are low, skips face auth and the password prompt appears with no delay

## Self-Update

```bash
face-unlock update          # Download and apply latest version
face-unlock update --check  # Check without applying
```

Updates are atomic with rollback on failure. User data (`~/.face-unlock/`) is never modified by updates.

## Uninstallation

```bash
sudo bash scripts/uninstall.sh
# or
make uninstall
```

User data at `~/.face-unlock/` is preserved. Remove manually if desired.

## Project Structure

```
face_unlock/
    __init__.py          # Version string
    cli.py               # CLI entrypoint (face-unlock command)
    auth.py              # PAM auth logic (resource guard first)
    enroll.py            # Face enrollment
    detect.py            # RetinaFace-MobileNet ONNX detector
    recognize.py         # MobileFaceNet ONNX embedder
    resource_guard.py    # RAM/CPU checks (stdlib only)
    updater.py           # Self-update system
    config.py            # Config loading/defaults
    utils.py             # Cosine similarity, logging, model download
scripts/
    install.sh           # System installer
    uninstall.sh         # Clean removal
    face-unlock-auth     # PAM wrapper script
migrations/
    migrate.py           # Data migration for updates
```

## Requirements

- Python 3.10+
- Linux (Ubuntu, Fedora, Arch)
- USB/built-in camera
- Dependencies: onnxruntime, opencv-python-headless, numpy, pyyaml, requests

## Releasing

```bash
make release VERSION=1.2.0
```

This updates version strings, creates a git tag, and pushes to GitHub.
