#!/bin/bash
set -e

# Face Unlock Installation Script
# Usage: sudo ./scripts/install.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INSTALL_DIR="/opt/face-unlock"
BIN_DIR="/usr/local/bin"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}=== Face Unlock Installer ===${NC}\n"

# Check root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: Run as root (sudo ./scripts/install.sh)${NC}"
    exit 1
fi

# Detect distro
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

DISTRO=$(detect_distro)
echo -e "Detected distro: ${GREEN}${DISTRO}${NC}"

# Install system dependencies
echo -e "\n${BLUE}[1/7] Installing system dependencies...${NC}"
case "$DISTRO" in
    ubuntu|debian|pop|linuxmint)
        apt-get update -qq
        apt-get install -y -qq python3 python3-pip python3-venv libgl1-mesa-glx v4l-utils
        ;;
    fedora|rhel|centos)
        dnf install -y python3 python3-pip mesa-libGL v4l-utils
        ;;
    arch|manjaro|endeavouros)
        pacman -S --noconfirm --needed python python-pip mesa v4l-utils
        ;;
    *)
        echo -e "${YELLOW}Warning: Unknown distro. Ensure python3 and pip are installed.${NC}"
        ;;
esac

# Create install directory
echo -e "\n${BLUE}[2/7] Setting up installation directory...${NC}"
mkdir -p "$INSTALL_DIR"

# Create virtual environment
echo -e "\n${BLUE}[3/7] Creating Python virtual environment...${NC}"
python3 -m venv "$INSTALL_DIR/venv"
source "$INSTALL_DIR/venv/bin/activate"

# Install Python dependencies
echo -e "\n${BLUE}[4/7] Installing Python dependencies...${NC}"
pip install --quiet --upgrade pip
pip install --quiet opencv-python-headless onnxruntime numpy pyyaml requests

# Copy project files
echo -e "\n${BLUE}[5/7] Copying project files...${NC}"
cp -r "$PROJECT_DIR/face_unlock" "$INSTALL_DIR/"
cp -r "$PROJECT_DIR/migrations" "$INSTALL_DIR/" 2>/dev/null || true
cp "$PROJECT_DIR/version.json" "$INSTALL_DIR/" 2>/dev/null || true
cp "$PROJECT_DIR/requirements.txt" "$INSTALL_DIR/" 2>/dev/null || true

# Install auth script and CLI
echo -e "\n${BLUE}[6/7] Installing CLI tools...${NC}"
cp "$PROJECT_DIR/scripts/face-unlock-auth" "$BIN_DIR/face-unlock-auth"
chmod +x "$BIN_DIR/face-unlock-auth"

# Create CLI wrapper
cat > "$BIN_DIR/face-unlock" << 'CLIEOF'
#!/bin/bash
INSTALL_DIR="/opt/face-unlock"
VENV_PYTHON="${INSTALL_DIR}/venv/bin/python3"
SYSTEM_PYTHON="/usr/bin/python3"

if [ -x "$VENV_PYTHON" ]; then
    PYTHON="$VENV_PYTHON"
else
    PYTHON="$SYSTEM_PYTHON"
fi

export PYTHONPATH="${INSTALL_DIR}:${PYTHONPATH}"
exec "$PYTHON" -m face_unlock.cli "$@"
CLIEOF
chmod +x "$BIN_DIR/face-unlock"

# PAM configuration
echo -e "\n${BLUE}[7/7] Configuring PAM...${NC}"
PAM_LINE="auth sufficient pam_exec.so quiet /usr/local/bin/face-unlock-auth"

detect_dm() {
    # Check running display manager
    for dm in gdm sddm lightdm; do
        if systemctl is-active --quiet "$dm" 2>/dev/null || \
           systemctl is-active --quiet "${dm}.service" 2>/dev/null; then
            echo "$dm"
            return
        fi
    done
    echo "unknown"
}

DM=$(detect_dm)
echo -e "  Display manager: ${GREEN}${DM}${NC}"

PAM_FILE=""
case "$DM" in
    gdm)
        # Try gdm-password first, then gdm-autologin
        for f in /etc/pam.d/gdm-password /etc/pam.d/gdm-autologin /etc/pam.d/gdm; do
            if [ -f "$f" ]; then
                PAM_FILE="$f"
                break
            fi
        done
        ;;
    sddm)
        PAM_FILE="/etc/pam.d/sddm"
        ;;
    lightdm)
        PAM_FILE="/etc/pam.d/lightdm"
        ;;
    *)
        echo -e "${YELLOW}  Could not detect display manager.${NC}"
        echo -e "${YELLOW}  Add this line to your PAM config manually:${NC}"
        echo -e "  ${PAM_LINE}"
        ;;
esac

if [ -n "$PAM_FILE" ] && [ -f "$PAM_FILE" ]; then
    # Check if already configured
    if grep -q "face-unlock-auth" "$PAM_FILE"; then
        echo -e "  ${GREEN}PAM already configured in ${PAM_FILE}${NC}"
    else
        # Backup original
        cp "$PAM_FILE" "${PAM_FILE}.bak.$(date +%Y%m%d%H%M%S)"
        echo -e "  Backed up: ${PAM_FILE}"

        # Add face-unlock line before the first auth line
        sed -i "0,/^auth/{s|^auth|${PAM_LINE}\nauth|}" "$PAM_FILE"
        echo -e "  ${GREEN}Added face-unlock to ${PAM_FILE}${NC}"
    fi
fi

# Create user config directory
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
USER_DIR="${REAL_HOME}/.face-unlock"
mkdir -p "$USER_DIR/models"
chown -R "$REAL_USER:$REAL_USER" "$USER_DIR"

# Create log file
touch /var/log/face-unlock.log
chmod 666 /var/log/face-unlock.log

echo -e "\n${GREEN}=== Installation Complete ===${NC}"
echo -e "\nNext steps:"
echo -e "  1. Download models:  ${BLUE}face-unlock status${NC}"
echo -e "  2. Enroll your face: ${BLUE}face-unlock enroll${NC}"
echo -e "  3. Test auth:        ${BLUE}face-unlock test${NC}"
echo -e "  4. Check status:     ${BLUE}face-unlock status${NC}"
