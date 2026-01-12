#!/bin/bash

# Face Unlock Uninstallation Script
# Run with: sudo ./uninstall.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
INSTALL_DIR="/opt/faceunlock"
DATA_DIR="/var/lib/faceunlock"
SYSTEMD_DIR="/etc/systemd/system"
BIN_DIR="/usr/local/bin"

# Detect OS for PAM module location
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
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

echo -e "${RED}=====================================${NC}"
echo -e "${RED}Face Unlock Uninstallation Script${NC}"
echo -e "${RED}=====================================${NC}\n"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: Please run as root (sudo ./uninstall.sh)${NC}"
    exit 1
fi

# Check if installed
if [ ! -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}Face Unlock does not appear to be installed.${NC}"
    exit 0
fi

# Confirm uninstallation
echo -e "${YELLOW}This will remove Face Unlock from your system.${NC}"
read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

# Stop and disable service
echo "Stopping service..."
systemctl stop faceunlock 2>/dev/null || true
systemctl disable faceunlock 2>/dev/null || true
echo -e "${GREEN}✓ Service stopped and disabled${NC}\n"

# Remove systemd service
echo "Removing systemd service..."
rm -f "$SYSTEMD_DIR/faceunlock.service"
systemctl daemon-reload
echo -e "${GREEN}✓ Systemd service removed${NC}\n"

# Remove PAM module
echo "Removing PAM module..."
# Try multiple possible locations
rm -f "$PAM_MODULE_DIR/pam_faceunlock.so"
rm -f "/lib/security/pam_faceunlock.so"
rm -f "/lib64/security/pam_faceunlock.so"
rm -f "/usr/lib/security/pam_faceunlock.so"
rm -f "/lib/x86_64-linux-gnu/security/pam_faceunlock.so"
echo -e "${GREEN}✓ PAM module removed${NC}\n"

# Remove command-line tools
echo "Removing command-line tools..."
rm -f "$BIN_DIR/faceunlock-enroll"
rm -f "$BIN_DIR/faceunlock-service"
rm -f "$BIN_DIR/faceunlock-list"
rm -f "$BIN_DIR/faceunlock-remove"
echo -e "${GREEN}✓ Command-line tools removed${NC}\n"

# Remove installation directory
echo "Removing application files..."
echo -e "  → Removing Python files from $INSTALL_DIR"
echo -e "  → Removing AI model (~250MB) from $INSTALL_DIR/models"
echo -e "  → Removing all application data"
rm -rf "$INSTALL_DIR"
echo -e "${GREEN}✓ Application files and AI model removed${NC}\n"

# Ask about user data
if [ -d "$DATA_DIR" ]; then
    echo -e "${YELLOW}User face data is stored in: $DATA_DIR${NC}"
    if ls "$DATA_DIR"/*.npy 1> /dev/null 2>&1; then
        echo "Enrolled users:"
        ls -1 "$DATA_DIR"/*.npy | xargs -n1 basename | sed 's/.npy//' | sed 's/^/  - /'
    fi
    echo ""
    read -p "Do you want to remove user face data? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$DATA_DIR"
        echo -e "${GREEN}✓ User data removed${NC}\n"
    else
        echo -e "${YELLOW}✓ User data preserved in $DATA_DIR${NC}\n"
    fi
fi

# Check PAM configuration
echo -e "${YELLOW}Checking PAM configuration...${NC}"
PAM_FILES=$(grep -l "pam_faceunlock" /etc/pam.d/* 2>/dev/null || true)
if [ -n "$PAM_FILES" ]; then
    echo -e "${RED}⚠ Face Unlock is still configured in PAM files:${NC}"
    echo "$PAM_FILES" | sed 's/^/  /'
    echo ""
    echo -e "${YELLOW}Please manually remove 'pam_faceunlock.so' lines from these files!${NC}"
    echo -e "${YELLOW}Example: sudo nano /etc/pam.d/common-auth${NC}"
    echo -e "${YELLOW}Remove: auth sufficient pam_faceunlock.so${NC}\n"
else
    echo -e "${GREEN}✓ No PAM configuration found${NC}\n"
fi

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Uninstallation Complete!${NC}"
echo -e "${GREEN}=====================================${NC}\n"
