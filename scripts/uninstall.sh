#!/bin/bash
set -e

# Face Unlock Uninstall Script
# Usage: sudo ./scripts/uninstall.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INSTALL_DIR="/opt/face-unlock"
BIN_DIR="/usr/local/bin"

echo -e "${BLUE}=== Face Unlock Uninstaller ===${NC}\n"

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: Run as root (sudo ./scripts/uninstall.sh)${NC}"
    exit 1
fi

# Remove PAM configuration
echo -e "${BLUE}[1/4] Removing PAM configuration...${NC}"
for pam_file in /etc/pam.d/gdm-password /etc/pam.d/gdm-autologin /etc/pam.d/gdm \
                /etc/pam.d/sddm /etc/pam.d/lightdm /etc/pam.d/login; do
    if [ -f "$pam_file" ]; then
        if grep -q "face-unlock-auth" "$pam_file"; then
            sed -i '/face-unlock-auth/d' "$pam_file"
            echo -e "  Removed face-unlock from ${pam_file}"
        fi
    fi
done

# Remove old systemd service if present
echo -e "\n${BLUE}[2/4] Removing legacy daemon (if present)...${NC}"
if systemctl is-active --quiet faceunlock 2>/dev/null; then
    systemctl stop faceunlock
fi
if systemctl is-enabled --quiet faceunlock 2>/dev/null; then
    systemctl disable faceunlock
fi
rm -f /etc/systemd/system/faceunlock.service
systemctl daemon-reload 2>/dev/null || true
echo -e "  Done"

# Remove installed files
echo -e "\n${BLUE}[3/4] Removing installed files...${NC}"
rm -rf "$INSTALL_DIR"
rm -f "$BIN_DIR/face-unlock-auth"
rm -f "$BIN_DIR/face-unlock"
rm -f "$BIN_DIR/faceunlock-enroll"
rm -f "$BIN_DIR/faceunlock-service"
rm -f "$BIN_DIR/faceunlock-list"
rm -f "$BIN_DIR/faceunlock-remove"
echo -e "  Removed $INSTALL_DIR and CLI tools"

# Remove log
echo -e "\n${BLUE}[4/4] Removing log file...${NC}"
rm -f /var/log/face-unlock.log
rm -f /var/log/faceunlock.log
rm -f /var/log/faceunlock_daemon.log

echo -e "\n${GREEN}=== Uninstallation Complete ===${NC}"
echo -e "\n${YELLOW}Note: User data preserved at ~/.face-unlock/${NC}"
echo -e "Remove manually if desired: ${BLUE}rm -rf ~/.face-unlock/${NC}"
