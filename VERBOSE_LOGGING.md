# 📊 Verbose Logging Guide

## Overview

All Face Unlock scripts now support verbose logging to help with debugging and troubleshooting. Verbose mode provides detailed information about what the scripts are doing at each step.

---

## 🔧 Bash Scripts

### Enable Verbose Mode

Add the `-v` or `--verbose` flag to any bash script:

```bash
# Installation
sudo ./install.sh --verbose

# Uninstallation
sudo ./uninstall.sh -v

# Emergency disable
sudo ./emergency_disable.sh --verbose
```

### What You'll See

With verbose mode enabled, bash scripts will:
- ✅ Show detailed debug information with `[VERBOSE]` prefix
- ✅ Enable bash debug mode (`set -x`) showing each command executed
- ✅ Display file paths and configuration values
- ✅ Show environment variables being set
- ✅ Log exit codes and command results

### Example Output

```bash
$ sudo ./install.sh --verbose

[VERBOSE] Verbose logging enabled
[VERBOSE] Install directory: /opt/faceunlock
[VERBOSE] Data directory: /var/lib/faceunlock
[VERBOSE] Running as: root
+ CURRENT_STEP=0
+ echo -e '\n\033[0;36m\033[1m[Step 1/11]\033[0m \033[0;34mChecking required files\033[0m'
...
```

---

## 🐍 Python Scripts (enroll.py)

### Enable Verbose Mode

Add the `-v` or `--verbose` flag when running enrollment:

```bash
# Direct enrollment (not recommended, use wrapper instead)
sudo python3 /opt/faceunlock/enroll.py username --verbose

# Via wrapper command (recommended)
sudo faceunlock-enroll username --verbose
```

### What You'll See

With verbose mode enabled, Python scripts will:
- ✅ Switch from INFO to DEBUG logging level
- ✅ Show Python and OpenCV versions
- ✅ Display Qt plugin discovery process
- ✅ Log camera initialization steps
- ✅ Show face detection details
- ✅ Display embedding generation progress

### Example Output

```bash
$ sudo faceunlock-enroll chinmay --verbose

DEBUG: Verbose logging enabled
DEBUG: Python version: 3.13.0
DEBUG: Arguments: ['/opt/faceunlock/enroll.py', 'chinmay', '--verbose']
DEBUG: OpenCV version: 4.12.0
DEBUG: OpenCV path: /usr/lib/python3.13/site-packages/cv2
DEBUG: Qt plugin path: /usr/lib/python3.13/site-packages/cv2/qt/plugins
DEBUG: Using OpenCV bundled Qt plugins
DEBUG: Set Qt platform to xcb
DEBUG: Configuration: SAVE_DIR=/var/lib/faceunlock, MODEL=/opt/faceunlock/models/arcfaceresnet100-8.onnx
DEBUG: Required samples: 5, Min face size: (80, 80)
DEBUG: Starting enrollment for user: chinmay
DEBUG: Username validation passed: chinmay
DEBUG: Created/verified directory: /var/lib/faceunlock
DEBUG: Model file exists: /opt/faceunlock/models/arcfaceresnet100-8.onnx
DEBUG: Initializing camera (device 0)
DEBUG: Camera opened successfully
...
```

---

## 🔄 Daemon (face_daemon.py)

### Enable Verbose Mode

The daemon reads verbose mode from an **environment variable**. You have two options:

#### Option 1: Temporary (Current Session)

```bash
# Stop the service
sudo systemctl stop faceunlock.service

# Run manually with verbose logging
sudo FACEUNLOCK_VERBOSE=1 python3 /opt/faceunlock/face_daemon.py
```

#### Option 2: Persistent (Via Systemd Service)

Edit the systemd service file:

```bash
sudo nano /etc/systemd/system/faceunlock.service
```

Uncomment the environment line:

```ini
[Service]
...
# Uncomment the line below to enable verbose logging:
Environment="FACEUNLOCK_VERBOSE=1"
...
```

Then reload and restart:

```bash
sudo systemctl daemon-reload
sudo systemctl restart faceunlock.service
```

### View Daemon Logs

```bash
# Follow logs in real-time
sudo journalctl -u faceunlock.service -f

# View last 100 lines
sudo journalctl -u faceunlock.service -n 100

# View logs since boot
sudo journalctl -u faceunlock.service -b
```

### What You'll See

With verbose mode enabled, the daemon will:
- ✅ Show detailed startup information
- ✅ Log each authentication attempt with timestamps
- ✅ Display face detection frame-by-frame
- ✅ Show similarity scores for each comparison
- ✅ Log camera capture details
- ✅ Display socket communication details

### Example Output

```
2026-01-13 10:30:15 - DEBUG - ======================================================================
2026-01-13 10:30:15 - DEBUG - Face Unlock Daemon Starting - VERBOSE MODE ENABLED
2026-01-13 10:30:15 - DEBUG - ======================================================================
2026-01-13 10:30:15 - DEBUG - Python version: 3.13.0
2026-01-13 10:30:15 - DEBUG - OpenCV version: 4.12.0
2026-01-13 10:30:15 - DEBUG - Configuration:
2026-01-13 10:30:15 - DEBUG -   SOCKET: /tmp/faceunlock.sock
2026-01-13 10:30:15 - DEBUG -   MODEL: /opt/faceunlock/models/arcfaceresnet100-8.onnx
2026-01-13 10:30:15 - DEBUG -   DATA_DIR: /var/lib/faceunlock
2026-01-13 10:30:15 - DEBUG -   THRESHOLD: 0.6
2026-01-13 10:30:15 - DEBUG -   TIMEOUT: 5.0s
2026-01-13 10:30:15 - DEBUG -   MAX_ATTEMPTS: 30
2026-01-13 10:30:15 - DEBUG -   LOG_FILE: /var/log/faceunlock.log
2026-01-13 10:30:15 - DEBUG - ======================================================================
2026-01-13 10:30:15 - INFO - Initializing models...
...
```

---

## 📋 Quick Reference

| Script | Verbose Flag | Example |
|--------|--------------|---------|
| `install.sh` | `-v` or `--verbose` | `sudo ./install.sh --verbose` |
| `uninstall.sh` | `-v` or `--verbose` | `sudo ./uninstall.sh -v` |
| `emergency_disable.sh` | `-v` or `--verbose` | `sudo ./emergency_disable.sh --verbose` |
| `faceunlock-enroll` | `-v` or `--verbose` | `sudo faceunlock-enroll user --verbose` |
| `enroll.py` | `-v` or `--verbose` | `python3 enroll.py user --verbose` |
| `face_daemon.py` | `FACEUNLOCK_VERBOSE=1` | `FACEUNLOCK_VERBOSE=1 python3 face_daemon.py` |

---

## 🎯 Common Debugging Scenarios

### Installation Not Working

```bash
# Run installer with verbose logging
sudo ./install.sh --verbose 2>&1 | tee install.log

# The install.log file will contain all output for analysis
```

### Enrollment Issues

```bash
# Run enrollment with verbose logging
sudo faceunlock-enroll chinmay --verbose 2>&1 | tee enroll.log
```

### Daemon/Authentication Problems

```bash
# Enable verbose logging in systemd service
sudo nano /etc/systemd/system/faceunlock.service
# Uncomment: Environment="FACEUNLOCK_VERBOSE=1"

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart faceunlock.service

# Watch logs in real-time
sudo journalctl -u faceunlock.service -f

# Or run manually for immediate feedback
sudo systemctl stop faceunlock.service
sudo FACEUNLOCK_VERBOSE=1 python3 /opt/faceunlock/face_daemon.py
```

### Camera Detection Issues

```bash
# Check Qt plugin discovery with verbose mode
sudo faceunlock-enroll test --verbose 2>&1 | grep -i "qt\|plugin\|camera"
```

---

## 🔍 Log Locations

| Component | Log Location | How to View |
|-----------|--------------|-------------|
| Daemon | systemd journal + `/var/log/faceunlock.log` | `journalctl -u faceunlock.service` |
| Enrollment | Terminal output | Redirect to file: `2>&1 | tee file.log` |
| Install Script | Terminal output | Redirect to file: `2>&1 | tee file.log` |
| System Auth | `/var/log/auth.log` (Ubuntu/Debian) | `tail -f /var/log/auth.log` |
| System Auth | `/var/log/secure` (Fedora/RHEL) | `tail -f /var/log/secure` |

---

## 💡 Tips

1. **Always use verbose mode when troubleshooting** - it provides crucial context
2. **Save logs to files** - Use `2>&1 | tee logfile.log` to capture output
3. **Check timestamps** - Correlate daemon logs with authentication attempts
4. **Disable after debugging** - Verbose logging creates large log files
5. **Share logs when asking for help** - Include relevant verbose output in bug reports

---

## 🚨 Disable Verbose Logging

### Bash Scripts
Simply run without the `-v` or `--verbose` flag.

### Daemon
Edit systemd service and comment out the environment line:

```bash
sudo nano /etc/systemd/system/faceunlock.service
# Comment out: # Environment="FACEUNLOCK_VERBOSE=1"

sudo systemctl daemon-reload
sudo systemctl restart faceunlock.service
```

---

**Note:** Verbose logging is disabled by default for cleaner output and smaller log files.
