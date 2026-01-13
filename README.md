# Face Unlock for Linux

A secure and lightweight face authentication system for Linux using ArcFace AI model and PAM integration.

## 🚀 Features## 🚨 Emergency Recovery - If Login Breaks

If face unlock prevents you from logging in, here are **multiple recovery methods**:

### 🛟 Quick Emergency Script (If Logged In)

```bash
# Run the emergency disable script
sudo ./emergency_disable.sh
```

This interactive script will:

- ✅ Stop and disable the face unlock service
- ✅ Comment out PAM configuration (with backups)
- ✅ Optionally remove PAM module files
- ✅ Restore password-only authentication

### Method 1: Disable PAM Module (Recommended)

Boot into **recovery mode** or **single-user mode**:AI-Powered Face Recognition**: Uses ArcFace ResNet100 for accurate face embeddings

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

```so
auth sufficient pam_faceunlock.so
```

**⚠️ Warning**: Test thoroughly before enabling on login/lock screen to avoid being locked out!

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    User Applications                    │
│  (sudo, login, lock screen, faceunlock-enroll, etc.)    │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│                   PAM Module                            │
│              (pam_faceunlock.so)                        │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼ Unix Socket (/tmp/faceunlock.sock)
┌─────────────────────────────────────────────────────────┐
│                Face Unlock Daemon                       │
│              (face_daemon.py)                           │
│  • Camera capture                                       │
│  • Face detection (Haar Cascade)                        │
│  • Face embedding (ArcFace ResNet100)                   │
│  • Similarity comparison                                │
└─────────────────────────────────────────────────────────┘
```

## 📁 Installation Layout

- `/opt/faceunlock/` - Application files (Python scripts, models)
- `/opt/faceunlock/venv/` - Python virtual environment (isolated dependencies)
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

## � Emergency Recovery - If Login Breaks

If face unlock prevents you from logging in, here are **multiple recovery methods**:

### Method 1: Disable PAM Module (Recommended)

Boot into **recovery mode** or **single-user mode**:

1. **At GRUB menu**: Press `e` to edit boot entry
2. **Add to kernel line**: `single` or `systemd.unit=rescue.target`
3. **Press Ctrl+X** to boot

Then disable the PAM module:

```bash
# Mount root filesystem as read-write
mount -o remount,rw /

# Comment out face unlock in PAM config
sed -i 's/^auth.*pam_faceunlock.so/#&/' /etc/pam.d/common-auth    # Debian/Ubuntu
sed -i 's/^auth.*pam_faceunlock.so/#&/' /etc/pam.d/system-auth    # Fedora/Arch

# Or completely remove the PAM module
rm -f /usr/lib/security/pam_faceunlock.so
rm -f /lib/security/pam_faceunlock.so
rm -f /lib/x86_64-linux-gnu/security/pam_faceunlock.so

# Reboot normally
reboot
```

### Method 2: TTY Console Access

If graphical login fails, switch to a text console:

1. **Press**: `Ctrl+Alt+F2` (or F3, F4, etc.)
2. **Login with password**
3. **Disable face unlock**:

```bash
# Stop the service
sudo systemctl stop faceunlock.service
sudo systemctl disable faceunlock.service

# Remove PAM configuration
sudo sed -i 's/^auth.*pam_faceunlock.so/#&/' /etc/pam.d/common-auth    # Debian/Ubuntu
sudo sed -i 's/^auth.*pam_faceunlock.so/#&/' /etc/pam.d/system-auth    # Fedora/Arch

# Return to graphical session
# Press Ctrl+Alt+F1 or Ctrl+Alt+F7
```

### Method 3: Live USB/Rescue System

Boot from a Linux Live USB:

1. **Boot from Live USB** (Ubuntu, Manjaro, etc.)
2. **Mount your root partition**:

```bash
# Find your root partition
lsblk
sudo mount /dev/sdXY /mnt    # Replace sdXY with your root partition

# Disable face unlock
sudo sed -i 's/^auth.*pam_faceunlock.so/#&/' /mnt/etc/pam.d/common-auth
sudo sed -i 's/^auth.*pam_faceunlock.so/#&/' /mnt/etc/pam.d/system-auth

# Or remove the module
sudo rm -f /mnt/usr/lib/security/pam_faceunlock.so
sudo rm -f /mnt/lib/security/pam_faceunlock.so
sudo rm -f /mnt/lib/x86_64-linux-gnu/security/pam_faceunlock.so

# Unmount and reboot
sudo umount /mnt
sudo reboot
```

### Method 4: Remote SSH Access

If SSH is enabled and you have network access:

```bash
# Connect from another machine
ssh user@your-machine-ip

# Disable face unlock
sudo systemctl stop faceunlock.service
sudo systemctl disable faceunlock.service
sudo sed -i 's/^auth.*pam_faceunlock.so/#&/' /etc/pam.d/common-auth
sudo sed -i 's/^auth.*pam_faceunlock.so/#&/' /etc/pam.d/system-auth
```

### 🛡️ Prevention Tips

1. **Test first**: Always test with `sudo` or terminal before enabling on login
2. **Keep password access**: Never rely solely on face unlock
3. **Test in safe mode**: Test enrollment and authentication thoroughly
4. **Enable SSH**: Keep SSH enabled as a backup access method
5. **Gradual rollout**: Test with sudo → test with lock screen → then enable on login

### Quick Disable Commands (When Logged In)

```bash
# Temporarily disable (until next boot)
sudo systemctl stop faceunlock.service

# Permanently disable service
sudo systemctl disable faceunlock.service

# Remove PAM configuration entirely
sudo ./uninstall.sh
```

## �🛠️ Troubleshooting

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
