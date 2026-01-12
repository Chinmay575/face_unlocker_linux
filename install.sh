#!/bin/bash

# Face Unlock Installation Script
# Run with: sudo ./install.sh

set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt/faceunlock"
DATA_DIR="/var/lib/faceunlock"
PAM_MODULE_DIR="/lib/security"
SYSTEMD_DIR="/etc/systemd/system"
BIN_DIR="/usr/local/bin"
LOG_DIR="/var/log"

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Face Unlock Installation Script${NC}"
echo -e "${BLUE}================================${NC}\n"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: Please run as root (sudo ./install.sh)${NC}"
    exit 1
fi

# Check required files
echo "Checking required files..."
REQUIRED_FILES="face_daemon.py face_embedder.py enroll.py pam_faceunlock.c requirements.txt"
for file in $REQUIRED_FILES; do
    if [ ! -f "$file" ]; then
        echo -e "${RED}Error: Required file missing: $file${NC}"
        exit 1
    fi
done

if [ ! -d "models" ] || [ ! -f "models/arcfaceresnet100-8.onnx" ]; then
    echo -e "${RED}Error: models/arcfaceresnet100-8.onnx not found${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All required files present${NC}\n"

# Detect OS and distribution
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
echo -e "${GREEN}✓ OS detected: $OS_NAME${NC}\n"

# Install system dependencies based on OS
echo "Installing system dependencies..."

case "$OS_ID" in
    ubuntu|debian|linuxmint|pop)
        echo "Using apt package manager (Debian/Ubuntu)..."
        apt-get update -qq || true
        apt-get install -y python3 python3-pip python3-dev gcc libpam0g-dev \
            libopencv-dev python3-opencv v4l-utils > /dev/null 2>&1
        ;;
    
    fedora|rhel|centos|rocky|almalinux)
        echo "Using dnf/yum package manager (Fedora/RHEL)..."
        if command -v dnf &> /dev/null; then
            dnf install -y python3 python3-pip python3-devel gcc pam-devel \
                opencv opencv-devel python3-opencv v4l-utils > /dev/null 2>&1
        else
            yum install -y python3 python3-pip python3-devel gcc pam-devel \
                opencv opencv-devel python3-opencv v4l-utils > /dev/null 2>&1
        fi
        ;;
    
    arch|manjaro)
        echo "Using pacman package manager (Arch Linux)..."
        pacman -Sy --noconfirm python python-pip gcc pam opencv python-opencv v4l-utils > /dev/null 2>&1
        # Note: On Arch/Manjaro, we'll use pip for OpenCV due to potential ffmpeg version conflicts
        ;;
    
    opensuse*|sles)
        echo "Using zypper package manager (openSUSE)..."
        zypper install -y python3 python3-pip gcc pam-devel opencv python3-opencv v4l-utils > /dev/null 2>&1
        ;;
    
    *)
        echo -e "${YELLOW}Warning: Unsupported distribution: $OS_ID${NC}"
        echo -e "${YELLOW}Please manually install: python3 python3-pip gcc pam-devel opencv v4l-utils${NC}"
        echo ""
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Installation cancelled."
            exit 1
        fi
        ;;
esac

echo -e "${GREEN}✓ System dependencies installed${NC}\n"

# Create directories
echo "Creating directories..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$DATA_DIR"
mkdir -p "$INSTALL_DIR/models"

# Set proper permissions for data directory (needed for enrollment)
chmod 777 "$DATA_DIR"

echo -e "${GREEN}✓ Directories created${NC}\n"

# Copy Python files
echo "Installing Python files..."
cp face_daemon.py face_embedder.py enroll.py "$INSTALL_DIR/"
cp requirements.txt "$INSTALL_DIR/"
chmod 755 "$INSTALL_DIR"/*.py
echo -e "${GREEN}✓ Python files installed${NC}\n"

# Copy models
echo "Installing AI models..."
cp models/arcfaceresnet100-8.onnx "$INSTALL_DIR/models/"
echo -e "${GREEN}✓ Models installed${NC}\n"

# Install Python dependencies
echo "Installing Python dependencies (this may take a moment)..."

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
$PIP_CMD install --upgrade pip > /dev/null 2>&1

# For Arch/Manjaro, use --break-system-packages since system pip installs are restricted
if [ "$OS_ID" = "arch" ] || [ "$OS_ID" = "manjaro" ]; then
    echo -e "${YELLOW}Note: Using --break-system-packages for Arch/Manjaro${NC}"
    $PIP_CMD install --break-system-packages -q -r requirements.txt 2>&1 | grep -v "already satisfied" || true
else
    $PIP_CMD install -q -r requirements.txt 2>&1 | grep -v "already satisfied" || true
fi

echo -e "${GREEN}✓ Python dependencies installed${NC}\n"

# Download AI model if not present
echo "Checking for AI model..."
mkdir -p "$INSTALL_DIR/models"

if [ -f "$INSTALL_DIR/models/arcfaceresnet100-8.onnx" ]; then
    echo -e "${GREEN}✓ AI model already exists${NC}\n"
else
    echo "Downloading ArcFace ResNet100 model (~250MB, this may take a few minutes)..."
    
    MODEL_URL="https://media.githubusercontent.com/media/onnx/models/refs/heads/main/validated/vision/body_analysis/arcface/model/arcfaceresnet100-8.onnx?download=true"
    MODEL_PATH="$INSTALL_DIR/models/arcfaceresnet100-8.onnx"
    
    if command -v curl &> /dev/null; then
        curl -L --progress-bar -o "$MODEL_PATH" "$MODEL_URL"
        DOWNLOAD_STATUS=$?
    elif command -v wget &> /dev/null; then
        wget --show-progress -O "$MODEL_PATH" "$MODEL_URL"
        DOWNLOAD_STATUS=$?
    else
        echo -e "${RED}Error: Neither curl nor wget found. Please install one of them.${NC}"
        exit 1
    fi
    
    # Verify download
    if [ $DOWNLOAD_STATUS -eq 0 ] && [ -f "$MODEL_PATH" ]; then
        # Verify file size (should be around 250MB)
        FILE_SIZE=$(stat -c%s "$MODEL_PATH" 2>/dev/null || stat -f%z "$MODEL_PATH" 2>/dev/null)
        if [ -n "$FILE_SIZE" ] && [ "$FILE_SIZE" -gt 100000000 ]; then
            SIZE_MB=$(awk "BEGIN {printf \"%.1f\", $FILE_SIZE/1048576}")
            echo -e "${GREEN}✓ AI model downloaded successfully (${SIZE_MB}MB)${NC}\n"
        else
            echo -e "${RED}Error: Downloaded model file seems too small or invalid${NC}"
            rm -f "$MODEL_PATH"
            exit 1
        fi
    else
        echo -e "${RED}Error: Failed to download AI model${NC}"
        echo -e "${YELLOW}You can manually download it from:${NC}"
        echo -e "${YELLOW}https://github.com/onnx/models/tree/main/validated/vision/body_analysis/arcface${NC}"
        echo -e "${YELLOW}and place it at: $MODEL_PATH${NC}"
        exit 1
    fi
fi

# Compile and install PAM module
echo "Compiling PAM module..."

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
mkdir -p "$PAM_MODULE_DIR"

# Compile PAM module
gcc -fPIC -shared -o pam_faceunlock.so pam_faceunlock.c -lpam
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to compile PAM module${NC}"
    exit 1
fi

cp pam_faceunlock.so "$PAM_MODULE_DIR/"
chmod 755 "$PAM_MODULE_DIR/pam_faceunlock.so"
echo -e "${GREEN}✓ PAM module installed to $PAM_MODULE_DIR${NC}\n"

# Install systemd service
echo "Installing systemd service..."

# Detect init system
if command -v systemctl &> /dev/null; then
    # Systemd is available
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

    systemctl daemon-reload
    systemctl enable faceunlock.service
    systemctl start faceunlock.service
    echo -e "${GREEN}✓ Systemd service installed and enabled${NC}\n"
else
    echo -e "${YELLOW}Warning: systemd not detected. Service file not installed.${NC}"
    echo -e "${YELLOW}You will need to start the daemon manually:${NC}"
    echo -e "${YELLOW}  python3 $INSTALL_DIR/face_daemon.py &${NC}\n"
fi

# Create wrapper scripts
echo "Creating command-line tools..."

# faceunlock-enroll command
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

# Run as the original user to preserve X11 access for GUI
if [ -n "$SUDO_USER" ]; then
    sudo -u "$SUDO_USER" DISPLAY=:0 python3 /opt/faceunlock/enroll.py "$1"
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

echo -e "${GREEN}✓ Command-line tools installed${NC}\n"

# Set proper permissions
echo "Setting permissions..."
chmod 755 "$INSTALL_DIR"
echo -e "${GREEN}✓ Permissions set${NC}\n"

# Verify installation
echo "Verifying installation..."
VERIFICATION_FAILED=0

# Check if files exist
if [ ! -f "$INSTALL_DIR/face_daemon.py" ]; then
    echo -e "${RED}✗ face_daemon.py not found${NC}"
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

echo -e "${GREEN}✓ All verification checks passed${NC}\n"

# Installation complete
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}================================${NC}\n"

echo -e "${YELLOW}Next Steps:${NC}\n"

echo -e "${BLUE}1. Enroll your user:${NC}"
echo -e "   ${GREEN}sudo faceunlock-enroll \$USER${NC}\n"

echo -e "${BLUE}2. Check service status:${NC}"
echo -e "   ${GREEN}faceunlock-service status${NC}\n"

echo -e "${BLUE}3. View enrolled users:${NC}"
echo -e "   ${GREEN}faceunlock-list${NC}\n"

echo -e "${BLUE}4. Test authentication:${NC}"
echo -e "   ${GREEN}python3 $INSTALL_DIR/test_auth.py \$USER${NC}\n"

echo -e "${YELLOW}Available Commands:${NC}"
echo -e "  ${GREEN}faceunlock-enroll <user>${NC}   - Enroll a user's face"
echo -e "  ${GREEN}faceunlock-remove <user>${NC}   - Remove a user's face data"
echo -e "  ${GREEN}faceunlock-service${NC}         - Manage the daemon"
echo -e "  ${GREEN}faceunlock-list${NC}            - List enrolled users\n"

echo -e "${YELLOW}Installation Locations:${NC}"
echo -e "  Application: ${GREEN}$INSTALL_DIR${NC}"
echo -e "  User data:   ${GREEN}$DATA_DIR${NC}"
echo -e "  PAM module:  ${GREEN}$PAM_MODULE_DIR/pam_faceunlock.so${NC}"
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
