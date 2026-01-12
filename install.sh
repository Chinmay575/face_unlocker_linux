#!/bin/bash

# Face Unlock Installation Script
# Run with: sudo ./install.sh

set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt/faceunlock"
DATA_DIR="/var/lib/faceunlock"
PAM_MODULE_DIR="/lib/security"
SYSTEMD_DIR="/etc/systemd/system"
BIN_DIR="/usr/local/bin"
LOG_DIR="/var/log"

# Progress tracking
TOTAL_STEPS=11
CURRENT_STEP=0

# Progress function
show_progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    echo -e "\n${CYAN}${BOLD}[Step $CURRENT_STEP/$TOTAL_STEPS]${NC} ${BLUE}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

echo -e "\n${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Face Unlock Installation Script            ║${NC}"
echo -e "${BLUE}║     Automated Linux Face Authentication        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}\n"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: Please run as root (sudo ./install.sh)${NC}"
    exit 1
fi

# Check required files
show_progress "Checking required files"
REQUIRED_FILES="face_daemon.py face_embedder.py enroll.py pam_faceunlock.c requirements.txt"
for file in $REQUIRED_FILES; do
    if [ ! -f "$file" ]; then
        echo -e "${RED}✗ Error: Required file missing: $file${NC}"
        exit 1
    fi
    echo -e "  ${GREEN}✓${NC} Found: $file"
done

echo -e "${GREEN}✓ All required source files present${NC}"
echo -e "${YELLOW}ℹ  AI model will be downloaded automatically if not present${NC}"

# Detect OS and distribution
show_progress "Detecting operating system"
echo "Detecting operating system..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME=$NAME
    OS_ID=$ID
    OS_VERSION=$VERSION_ID
    echo -e "${BLUE}Detected: $OS_NAME${NC}"
elif [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
    OS_NAME=$DISTRIB_DESCRIPTION
    OS_ID=$DISTRIB_ID
else
    OS_NAME="Unknown"
    OS_ID="unknown"
fi
echo -e "${GREEN}✓ Detected: $OS_NAME${NC}"

# Install system dependencies based on OS
show_progress "Installing system dependencies"

case "$OS_ID" in
    ubuntu|debian|linuxmint|pop)
        echo -e "  ${CYAN}→${NC} Using apt package manager (Debian/Ubuntu)..."
        echo -e "  ${CYAN}→${NC} Updating package lists..."
        apt-get update -qq || true
        echo -e "  ${CYAN}→${NC} Installing: python3, gcc, pam-dev, opencv, Qt, v4l-utils..."
        apt-get install -y python3 python3-pip python3-dev gcc libpam0g-dev \
            libopencv-dev python3-opencv v4l-utils \
            libqt5gui5 libqt5core5a libqt5widgets5 \
            libxcb-xinerama0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 \
            libxcb-randr0 libxcb-render-util0 libxcb-xkb1 > /dev/null 2>&1
        ;;
    
    fedora|rhel|centos|rocky|almalinux)
        echo -e "  ${CYAN}→${NC} Using dnf/yum package manager (Fedora/RHEL)..."
        if command -v dnf &> /dev/null; then
            echo -e "  ${CYAN}→${NC} Installing packages with dnf..."
            dnf install -y python3 python3-pip python3-devel gcc pam-devel \
                opencv opencv-devel python3-opencv v4l-utils \
                qt5-qtbase qt5-qtbase-gui libxcb > /dev/null 2>&1
        else
            echo -e "  ${CYAN}→${NC} Installing packages with yum..."
            yum install -y python3 python3-pip python3-devel gcc pam-devel \
                opencv opencv-devel python3-opencv v4l-utils \
                qt5-qtbase qt5-qtbase-gui libxcb > /dev/null 2>&1
        fi
        ;;
    
    arch|manjaro)
        echo -e "  ${CYAN}→${NC} Using pacman package manager (Arch Linux)..."
        echo -e "  ${CYAN}→${NC} Installing packages..."
        pacman -Sy --noconfirm python python-pip gcc pam opencv python-opencv v4l-utils \
            qt5-base libxcb > /dev/null 2>&1
        echo -e "  ${YELLOW}ℹ${NC}  Note: OpenCV will be installed via pip for ffmpeg compatibility"
        ;;
    
    opensuse*|sles)
        echo -e "  ${CYAN}→${NC} Using zypper package manager (openSUSE)..."
        zypper install -y python3 python3-pip gcc pam-devel opencv python3-opencv v4l-utils \
            libQt5Gui5 libxcb1 > /dev/null 2>&1
        ;;
    
    *)
        echo -e "  ${YELLOW}⚠${NC}  Unsupported distribution: $OS_ID"
        echo -e "  ${YELLOW}ℹ${NC}  Please manually install: python3 python3-pip gcc pam-devel opencv v4l-utils Qt5"
        echo ""
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Installation cancelled."
            exit 1
        fi
        ;;
esac

echo -e "${GREEN}✓ System dependencies installed${NC}"

# Create directories
show_progress "Creating directories"
echo -e "  ${CYAN}→${NC} Creating: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
echo -e "  ${CYAN}→${NC} Creating: $DATA_DIR"
mkdir -p "$DATA_DIR"
echo -e "  ${CYAN}→${NC} Creating: $INSTALL_DIR/models"
mkdir -p "$INSTALL_DIR/models"

# Set proper permissions for data directory (needed for enrollment)
echo -e "  ${CYAN}→${NC} Setting permissions on $DATA_DIR"
chmod 777 "$DATA_DIR"

echo -e "${GREEN}✓ Directories created${NC}"

# Copy Python files
show_progress "Installing Python files"
echo -e "  ${CYAN}→${NC} Copying face_daemon.py, face_embedder.py, enroll.py..."
cp face_daemon.py face_embedder.py enroll.py "$INSTALL_DIR/"
cp requirements.txt "$INSTALL_DIR/"
chmod 755 "$INSTALL_DIR"/*.py
echo -e "${GREEN}✓ Python files installed${NC}"

# Install Python dependencies
show_progress "Installing Python dependencies"
echo -e "  ${YELLOW}ℹ${NC}  This may take a moment..."

# Detect Python package manager
if command -v pip3 &> /dev/null; then
    PIP_CMD="pip3"
elif command -v pip &> /dev/null; then
    PIP_CMD="pip"
else
    echo -e "${RED}Error: pip not found. Installing pip...${NC}"
    case "$OS_ID" in
        ubuntu|debian|linuxmint|pop)
            apt-get install -y python3-pip > /dev/null 2>&1
            ;;
        fedora|rhel|centos|rocky|almalinux)
            if command -v dnf &> /dev/null; then
                dnf install -y python3-pip > /dev/null 2>&1
            else
                yum install -y python3-pip > /dev/null 2>&1
            fi
            ;;
        arch|manjaro)
            pacman -Sy --noconfirm python-pip > /dev/null 2>&1
            ;;
        opensuse*|sles)
            zypper install -y python3-pip > /dev/null 2>&1
            ;;
    esac
    PIP_CMD="pip3"
fi

# Install Python packages
echo -e "  ${CYAN}→${NC} Upgrading pip..."
$PIP_CMD install --upgrade pip > /dev/null 2>&1

# For Arch/Manjaro, use --break-system-packages since system pip installs are restricted
if [ "$OS_ID" = "arch" ] || [ "$OS_ID" = "manjaro" ]; then
    echo -e "  ${YELLOW}ℹ${NC}  Using --break-system-packages for Arch/Manjaro"
    echo -e "  ${CYAN}→${NC} Installing opencv-python, numpy, onnxruntime..."
    $PIP_CMD install --break-system-packages -q -r requirements.txt 2>&1 | grep -v "already satisfied" || true
else
    echo -e "  ${CYAN}→${NC} Installing opencv-python, numpy, onnxruntime..."
    $PIP_CMD install -q -r requirements.txt 2>&1 | grep -v "already satisfied" || true
fi

echo -e "${GREEN}✓ Python dependencies installed${NC}"

# Download AI model if not present
show_progress "Downloading AI model"
mkdir -p "$INSTALL_DIR/models"

if [ -f "$INSTALL_DIR/models/arcfaceresnet100-8.onnx" ]; then
    echo -e "  ${GREEN}✓${NC} AI model already exists (skipping download)"
else
    echo -e "  ${CYAN}→${NC} Downloading ArcFace ResNet100 model (~250MB)"
    echo -e "  ${YELLOW}ℹ${NC}  This may take a few minutes depending on your connection..."
    echo ""
    
    MODEL_URL="https://media.githubusercontent.com/media/onnx/models/refs/heads/main/validated/vision/body_analysis/arcface/model/arcfaceresnet100-8.onnx?download=true"
    MODEL_PATH="$INSTALL_DIR/models/arcfaceresnet100-8.onnx"
    
    if command -v curl &> /dev/null; then
        # Use curl with simple progress bar (shows percentage and speed)
        echo -e "  ${CYAN}→${NC} Starting download..."
        curl -L -# -o "$MODEL_PATH" "$MODEL_URL"
        DOWNLOAD_STATUS=$?
    elif command -v wget &> /dev/null; then
        # Use wget with progress bar
        echo -e "  ${CYAN}→${NC} Starting download..."
        wget --progress=bar:force:noscroll -O "$MODEL_PATH" "$MODEL_URL"
        DOWNLOAD_STATUS=$?
    else
        echo -e "  ${RED}✗${NC} Neither curl nor wget found. Please install one of them."
        exit 1
    fi
    echo ""
    
    # Verify download
    if [ $DOWNLOAD_STATUS -eq 0 ] && [ -f "$MODEL_PATH" ]; then
        # Verify file size (should be around 250MB)
        FILE_SIZE=$(stat -c%s "$MODEL_PATH" 2>/dev/null || stat -f%z "$MODEL_PATH" 2>/dev/null)
        if [ -n "$FILE_SIZE" ] && [ "$FILE_SIZE" -gt 100000000 ]; then
            SIZE_MB=$(awk "BEGIN {printf \"%.1f\", $FILE_SIZE/1048576}")
            echo -e "${GREEN}✓ AI model downloaded successfully (${SIZE_MB}MB)${NC}\n"
        else
            echo -e "  ${RED}✗${NC} Downloaded model file seems too small or invalid"
            rm -f "$MODEL_PATH"
            exit 1
        fi
    else
        echo -e "  ${RED}✗${NC} Failed to download AI model"
        echo -e "  ${YELLOW}ℹ${NC}  You can manually download it from:"
        echo -e "     https://github.com/onnx/models/tree/main/validated/vision/body_analysis/arcface"
        echo -e "  ${YELLOW}ℹ${NC}  and place it at: $MODEL_PATH"
        exit 1
    fi
fi

# Compile and install PAM module
show_progress "Compiling PAM module"

# Detect compiler
if ! command -v gcc &> /dev/null; then
    echo -e "${RED}Error: gcc compiler not found${NC}"
    exit 1
fi

# Detect PAM library location based on OS
case "$OS_ID" in
    ubuntu|debian|linuxmint|pop)
        PAM_MODULE_DIR="/lib/x86_64-linux-gnu/security"
        if [ ! -d "$PAM_MODULE_DIR" ]; then
            PAM_MODULE_DIR="/lib/security"
        fi
        ;;
    fedora|rhel|centos|rocky|almalinux)
        if [ "$(uname -m)" = "x86_64" ]; then
            PAM_MODULE_DIR="/lib64/security"
        else
            PAM_MODULE_DIR="/lib/security"
        fi
        ;;
    arch|manjaro)
        PAM_MODULE_DIR="/usr/lib/security"
        ;;
    opensuse*|sles)
        if [ "$(uname -m)" = "x86_64" ]; then
            PAM_MODULE_DIR="/lib64/security"
        else
            PAM_MODULE_DIR="/lib/security"
        fi
        ;;
    *)
        PAM_MODULE_DIR="/lib/security"
        ;;
esac

# Create PAM directory if it doesn't exist
echo -e "  ${CYAN}→${NC} Creating PAM module directory: $PAM_MODULE_DIR"
mkdir -p "$PAM_MODULE_DIR"

# Compile PAM module
echo -e "  ${CYAN}→${NC} Compiling pam_faceunlock.so from source..."
gcc -fPIC -shared -o pam_faceunlock.so pam_faceunlock.c -lpam
if [ $? -ne 0 ]; then
    echo -e "  ${RED}✗${NC} Failed to compile PAM module"
    exit 1
fi

echo -e "  ${CYAN}→${NC} Installing to $PAM_MODULE_DIR/"
cp pam_faceunlock.so "$PAM_MODULE_DIR/"
chmod 755 "$PAM_MODULE_DIR/pam_faceunlock.so"
echo -e "${GREEN}✓ PAM module compiled and installed${NC}"

# Install systemd service
show_progress "Installing systemd service"

# Detect init system
if command -v systemctl &> /dev/null; then
    # Systemd is available
    echo -e "  ${CYAN}→${NC} Creating faceunlock.service..."
    cat > "$SYSTEMD_DIR/faceunlock.service" << EOF
[Unit]
Description=Face Unlock Authentication Daemon
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/python3 $INSTALL_DIR/face_daemon.py
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

# Security hardening (PrivateTmp removed so socket is accessible)
NoNewPrivileges=true

# Environment
Environment="PYTHONUNBUFFERED=1"

[Install]
WantedBy=multi-user.target
EOF

    echo -e "  ${CYAN}→${NC} Reloading systemd daemon..."
    systemctl daemon-reload
    echo -e "  ${CYAN}→${NC} Enabling service at boot..."
    systemctl enable faceunlock.service
    echo -e "  ${CYAN}→${NC} Starting service..."
    systemctl start faceunlock.service
    echo -e "${GREEN}✓ Service installed, enabled, and started${NC}"
else
    echo -e "  ${YELLOW}⚠${NC}  systemd not detected. Service file not installed."
    echo -e "  ${YELLOW}ℹ${NC}  You will need to start the daemon manually:"
    echo -e "     python3 $INSTALL_DIR/face_daemon.py &"
fi

# Create wrapper scripts
show_progress "Creating command-line tools"

# faceunlock-enroll command
echo -e "  ${CYAN}→${NC} Creating faceunlock-enroll..."
cat > "$BIN_DIR/faceunlock-enroll" << 'EOF'
#!/bin/bash
if [ "$EUID" -ne 0 ]; then
    echo "Error: Please run as root (sudo faceunlock-enroll <username>)"
    exit 1
fi
if [ -z "$1" ]; then
    echo "Usage: faceunlock-enroll <username>"
    exit 1
fi

# Detect X11 display
if [ -z "$DISPLAY" ]; then
    DISPLAY=:0
fi

# Get the X11 authority file
if [ -n "$SUDO_USER" ]; then
    XAUTHORITY_FILE=$(sudo -u "$SUDO_USER" env | grep -w "XAUTHORITY" | cut -d= -f2)
    if [ -z "$XAUTHORITY_FILE" ]; then
        XAUTHORITY_FILE="/home/$SUDO_USER/.Xauthority"
    fi
else
    XAUTHORITY_FILE="$HOME/.Xauthority"
fi

# Set up environment for X11/Qt
export DISPLAY="$DISPLAY"
export XAUTHORITY="$XAUTHORITY_FILE"
export QT_QPA_PLATFORM=xcb

# Set Qt to use OpenCV's bundled plugins if available
CV2_QT_PLUGINS=$(python3 -c 'import cv2, os; print(os.path.join(os.path.dirname(cv2.__file__), "qt", "plugins"))' 2>/dev/null)
if [ -d "$CV2_QT_PLUGINS" ]; then
    export QT_QPA_PLATFORM_PLUGIN_PATH="$CV2_QT_PLUGINS"
fi

# Grant X11 access temporarily
if command -v xhost &> /dev/null; then
    xhost +local: > /dev/null 2>&1
fi

# Run as the original user to preserve X11 access for GUI
if [ -n "$SUDO_USER" ]; then
    sudo -u "$SUDO_USER" DISPLAY="$DISPLAY" XAUTHORITY="$XAUTHORITY_FILE" \
         QT_QPA_PLATFORM=xcb \
         QT_QPA_PLATFORM_PLUGIN_PATH="${QT_QPA_PLATFORM_PLUGIN_PATH:-}" \
         python3 /opt/faceunlock/enroll.py "$1"
    EXIT_CODE=$?
else
    QT_QPA_PLATFORM=xcb \
    QT_QPA_PLATFORM_PLUGIN_PATH="${QT_QPA_PLATFORM_PLUGIN_PATH:-}" \
    python3 /opt/faceunlock/enroll.py "$1"
    EXIT_CODE=$?
fi

# Revoke X11 access
if command -v xhost &> /dev/null; then
    xhost -local: > /dev/null 2>&1
fi

exit $EXIT_CODE
else
    python3 /opt/faceunlock/enroll.py "$1"
fi
EOF
chmod +x "$BIN_DIR/faceunlock-enroll"

# faceunlock-service command
cat > "$BIN_DIR/faceunlock-service" << 'EOF'
#!/bin/bash
case "$1" in
    start)
        systemctl start faceunlock.service
        ;;
    stop)
        systemctl stop faceunlock.service
        ;;
    restart)
        systemctl restart faceunlock.service
        ;;
    status)
        systemctl status faceunlock.service
        ;;
    enable)
        systemctl enable faceunlock.service
        echo "Face unlock service enabled at boot"
        ;;
    disable)
        systemctl disable faceunlock.service
        echo "Face unlock service disabled at boot"
        ;;
    logs)
        journalctl -u faceunlock.service -f
        ;;
    *)
        echo "Face Unlock Service Manager"
        echo ""
        echo "Usage: faceunlock-service {command}"
        echo ""
        echo "Commands:"
        echo "  start    - Start the daemon"
        echo "  stop     - Stop the daemon"
        echo "  restart  - Restart the daemon"
        echo "  status   - Show daemon status"
        echo "  enable   - Enable at boot"
        echo "  disable  - Disable at boot"
        echo "  logs     - View live logs"
        exit 1
        ;;
esac
EOF
chmod +x "$BIN_DIR/faceunlock-service"

# faceunlock-list command
cat > "$BIN_DIR/faceunlock-list" << 'EOF'
#!/bin/bash
echo "Enrolled users:"
if ls /var/lib/faceunlock/*.npy 1> /dev/null 2>&1; then
    ls -1 /var/lib/faceunlock/*.npy | xargs -n1 basename | sed 's/.npy//' | sed 's/^/  - /'
    echo ""
    echo "Total: $(ls -1 /var/lib/faceunlock/*.npy | wc -l) user(s)"
else
    echo "  (none enrolled yet)"
fi
EOF
chmod +x "$BIN_DIR/faceunlock-list"

# faceunlock-remove command
cat > "$BIN_DIR/faceunlock-remove" << 'EOF'
#!/bin/bash
if [ "$EUID" -ne 0 ]; then
    echo "Error: Please run as root (sudo faceunlock-remove <username>)"
    exit 1
fi
if [ -z "$1" ]; then
    echo "Usage: faceunlock-remove <username>"
    exit 1
fi
if [ -f "/var/lib/faceunlock/$1.npy" ]; then
    rm "/var/lib/faceunlock/$1.npy"
    echo "User '$1' removed successfully"
else
    echo "Error: User '$1' not found"
    exit 1
fi
EOF
chmod +x "$BIN_DIR/faceunlock-remove"

echo -e "${GREEN}✓ All command-line tools created${NC}"
echo -e "  ${GREEN}✓${NC} faceunlock-enroll"
echo -e "  ${GREEN}✓${NC} faceunlock-service"
echo -e "  ${GREEN}✓${NC} faceunlock-list"
echo -e "  ${GREEN}✓${NC} faceunlock-remove"

# Set proper permissions
show_progress "Setting final permissions"
echo -e "  ${CYAN}→${NC} Setting permissions on $INSTALL_DIR"
chmod 755 "$INSTALL_DIR"
echo -e "${GREEN}✓ Permissions configured${NC}"

# Verify installation
show_progress "Verifying installation"
VERIFICATION_FAILED=0

# Check if files exist
echo -e "  ${CYAN}→${NC} Checking installed files..."
if [ ! -f "$INSTALL_DIR/face_daemon.py" ]; then
    echo -e "  ${RED}✗${NC} face_daemon.py not found"
    VERIFICATION_FAILED=1
else
    echo -e "${GREEN}✓ face_daemon.py installed${NC}"
fi

if [ ! -f "$INSTALL_DIR/models/arcfaceresnet100-8.onnx" ]; then
    echo -e "${RED}✗ AI model not found${NC}"
    VERIFICATION_FAILED=1
else
    echo -e "${GREEN}✓ AI model installed${NC}"
fi

if [ ! -f "$PAM_MODULE_DIR/pam_faceunlock.so" ]; then
    echo -e "${RED}✗ PAM module not found${NC}"
    VERIFICATION_FAILED=1
else
    echo -e "${GREEN}✓ PAM module installed${NC}"
fi

# Check if commands are executable
for cmd in faceunlock-enroll faceunlock-service faceunlock-list faceunlock-remove; do
    if [ ! -x "$BIN_DIR/$cmd" ]; then
        echo -e "${RED}✗ $cmd not executable${NC}"
        VERIFICATION_FAILED=1
    else
        echo -e "${GREEN}✓ $cmd installed${NC}"
    fi
done

# Check if service is running
if command -v systemctl &> /dev/null; then
    if systemctl is-active --quiet faceunlock.service; then
        echo -e "${GREEN}✓ Service is running${NC}"
    else
        echo -e "${RED}✗ Service is not running${NC}"
        VERIFICATION_FAILED=1
    fi
    
    if systemctl is-enabled --quiet faceunlock.service; then
        echo -e "${GREEN}✓ Service is enabled at boot${NC}"
    else
        echo -e "${YELLOW}⚠ Service is not enabled at boot${NC}"
    fi
fi

# Check if socket file exists
sleep 1  # Give daemon time to create socket
if [ -S "/tmp/faceunlock.sock" ]; then
    echo -e "${GREEN}✓ Socket file created${NC}"
else
    echo -e "${RED}✗ Socket file not found${NC}"
    VERIFICATION_FAILED=1
fi

if [ $VERIFICATION_FAILED -eq 1 ]; then
    echo -e "\n${RED}Installation verification failed! Please check the errors above.${NC}\n"
    exit 1
fi

echo -e "${GREEN}✓ All verification checks passed${NC}"

# Installation complete
echo -e "\n${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                ║${NC}"
echo -e "${GREEN}║     ✓ INSTALLATION COMPLETE!                  ║${NC}"
echo -e "${GREEN}║                                                ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}\n"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${BLUE}  📋 NEXT STEPS${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -e "${BLUE}1.${NC} ${BOLD}Enroll your user:${NC}"
echo -e "   ${GREEN}sudo faceunlock-enroll \$USER${NC}\n"

echo -e "${BLUE}2.${NC} ${BOLD}Check service status:${NC}"
echo -e "   ${GREEN}faceunlock-service status${NC}\n"

echo -e "${BLUE}3.${NC} ${BOLD}View enrolled users:${NC}"
echo -e "   ${GREEN}faceunlock-list${NC}\n"

echo -e "${BLUE}4.${NC} ${BOLD}Test authentication:${NC}"
echo -e "   ${GREEN}python3 $INSTALL_DIR/test_auth.py \$USER${NC}\n"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${BLUE}  🔧 AVAILABLE COMMANDS${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -e "  ${GREEN}faceunlock-enroll <user>${NC}   - Enroll a user's face"
echo -e "  ${GREEN}faceunlock-remove <user>${NC}   - Remove a user's face data"
echo -e "  ${GREEN}faceunlock-service${NC}         - Manage the daemon (start/stop/status)"
echo -e "  ${GREEN}faceunlock-list${NC}            - List enrolled users\n"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${BLUE}  📁 INSTALLATION SUMMARY${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -e "  Application:  ${GREEN}$INSTALL_DIR${NC}"
echo -e "  User data:    ${GREEN}$DATA_DIR${NC}"
echo -e "  PAM module:   ${GREEN}$PAM_MODULE_DIR/pam_faceunlock.so${NC}"
if command -v systemctl &> /dev/null; then
    echo -e "  Service:     ${GREEN}$SYSTEMD_DIR/faceunlock.service${NC}\n"
else
    echo -e "  Service:     ${YELLOW}Not installed (systemd not detected)${NC}\n"
fi

echo -e "${YELLOW}Detected System:${NC}"
echo -e "  OS:          ${GREEN}$OS_NAME${NC}"
echo -e "  Arch:        ${GREEN}$(uname -m)${NC}"
echo -e "  Kernel:      ${GREEN}$(uname -r)${NC}\n"

echo -e "${YELLOW}To configure PAM authentication:${NC}"
case "$OS_ID" in
    ubuntu|debian|linuxmint|pop)
        echo -e "  Edit ${GREEN}/etc/pam.d/common-auth${NC} or ${GREEN}/etc/pam.d/gdm-password${NC}"
        ;;
    fedora|rhel|centos|rocky|almalinux)
        echo -e "  Edit ${GREEN}/etc/pam.d/system-auth${NC} or ${GREEN}/etc/pam.d/gdm-password${NC}"
        ;;
    arch|manjaro)
        echo -e "  Edit ${GREEN}/etc/pam.d/system-login${NC} or ${GREEN}/etc/pam.d/gdm-password${NC}"
        ;;
    *)
        echo -e "  Edit appropriate PAM config in ${GREEN}/etc/pam.d/${NC}"
        ;;
esac
echo -e "  Add: ${GREEN}auth sufficient pam_faceunlock.so${NC}\n"

echo -e "${RED}⚠ WARNING: Test thoroughly before relying on face unlock!${NC}"
echo -e "${RED}           Always keep password authentication enabled!${NC}\n"
