# Face Unlock for Linux

A secure and lightweight face authentication system for Linux using ArcFace AI model and PAM integration.

## 🚀 Features

- **AI-Powered Face Recognition**: Uses ArcFace ResNet100 for accurate face embeddings
- **PAM Integration**: Seamless integration with Linux authentication system
- **Multi-User Support**: Enroll multiple users with individual face profiles
- **Systemd Service**: Background daemon with automatic startup
- **Command-Line Tools**: Easy-to-use commands for enrollment and management
- **Multi-Distribution Support**: Ubuntu, Debian, Fedora, Arch, Manjaro, openSUSE, and more
- **Security Hardened**: Input validation, camera locking, and secure socket communication

## 📋 Requirements

- Linux distribution with systemd
- Python 3.x
- Webcam/camera device
- GCC compiler
- PAM development libraries

## ⚡ Quick Installation

```bash
# Clone the repository
git clone https://github.com/Chinmay575/face_unlocker_linux.git
cd face_unlocker_linux

# Run the installer (requires sudo)
sudo ./install.sh
```

The installer will automatically:
- ✅ Detect your Linux distribution
- ✅ Install system dependencies (Python, OpenCV, GCC, PAM libraries)
- ✅ Install Python packages (opencv-python, numpy, onnxruntime)
- ✅ **Download the AI model** (~250MB from ONNX Model Zoo)
- ✅ Compile the PAM module
- ✅ Install systemd service
- ✅ Create command-line tools
- ✅ Set up directories with proper permissions
- ✅ Enable and start the face unlock service

## 🎯 Usage

### Enroll a User

```bash
sudo faceunlock-enroll <username>
```

This will:
1. Open your camera
2. Detect your face
3. Capture 5 samples
4. Generate and save face embeddings

### Manage the Service

```bash
# Check service status
faceunlock-service status

# Start/stop the service
faceunlock-service start
faceunlock-service stop
faceunlock-service restart

# View live logs
faceunlock-service logs
```

### List Enrolled Users

```bash
faceunlock-list
```

### Remove a User

```bash
sudo faceunlock-remove <username>
```

## 🔐 PAM Integration (Optional)

To use face unlock for system authentication (sudo, login, lock screen), edit your PAM configuration:

```bash
sudo nano /etc/pam.d/sudo
```

Add this line at the top:

```
auth sufficient pam_faceunlock.so
```

**⚠️ Warning**: Test thoroughly before enabling on login/lock screen to avoid being locked out!

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    User Applications                     │
│  (sudo, login, lock screen, faceunlock-enroll, etc.)   │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│                   PAM Module                             │
│              (pam_faceunlock.so)                        │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼ Unix Socket (/tmp/faceunlock.sock)
┌─────────────────────────────────────────────────────────┐
│                Face Unlock Daemon                        │
│              (face_daemon.py)                           │
│  • Camera capture                                       │
│  • Face detection (Haar Cascade)                       │
│  • Face embedding (ArcFace ResNet100)                  │
│  • Similarity comparison                               │
└─────────────────────────────────────────────────────────┘
```

## 📁 Installation Layout

- `/opt/faceunlock/` - Application files (Python scripts, models)
- `/var/lib/faceunlock/` - User face embeddings (*.npy files)
- `/usr/lib/security/pam_faceunlock.so` - PAM authentication module
- `/etc/systemd/system/faceunlock.service` - Systemd service
- `/usr/local/bin/faceunlock-*` - Command-line tools
- `/tmp/faceunlock.sock` - Unix socket for daemon communication

## 🔧 Configuration

Edit `/opt/faceunlock/config.ini` to customize:

```ini
[face_unlock]
threshold = 0.6          # Face match confidence (0.0-1.0)
timeout = 5.0            # Authentication timeout (seconds)
max_attempts = 30        # Maximum frame capture attempts
```

## 🛠️ Troubleshooting

### Service not running
```bash
faceunlock-service status
sudo journalctl -u faceunlock.service -n 50
```

### Camera not detected
```bash
python3 camera_test.py
ls -l /dev/video*
```

### Socket file not created
Check if service has `PrivateTmp=no` in `/etc/systemd/system/faceunlock.service`

### X11 display errors during enrollment
The installer automatically configures enrollment to preserve X11 access. If issues persist:
```bash
xhost +local:
sudo faceunlock-enroll <username>
```

## 🗑️ Uninstallation

```bash
sudo ./uninstall.sh
```

This will remove all installed files, services, and user data.

## 🧪 Supported Distributions

- ✅ Ubuntu / Linux Mint / Pop!_OS
- ✅ Debian
- ✅ Fedora / RHEL / CentOS / Rocky / AlmaLinux
- ✅ Arch Linux / Manjaro
- ✅ openSUSE / SLES

## 📦 Technologies Used

- **Python 3** - Core application logic
- **OpenCV** - Face detection and image processing
- **ONNX Runtime** - AI model inference
- **ArcFace ResNet100** - Face recognition model
- **Linux PAM** - Authentication integration
- **systemd** - Service management
- **Unix Sockets** - IPC communication

## 🔒 Security Features

- **Input Validation**: Prevents path traversal and injection attacks
- **Camera Locking**: Prevents concurrent camera access
- **Secure Socket**: Unix socket with proper permissions
- **No Root Execution**: Service runs with minimal privileges
- **Biometric Data Protection**: User embeddings stored with restricted access

## 📄 License

MIT License - See LICENSE file for details

## 🤝 Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## ⚠️ Disclaimer

This is experimental software. While it provides an additional layer of security, it should not be your only authentication method. Always have a password backup!

## 📞 Support

For issues, questions, or feature requests, please open an issue on GitHub.

---

**Made with ❤️ for the Linux community**
