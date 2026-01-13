#!/bin/bash
# Test the installation prompt logic

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

INSTALL_DIR="/opt/faceunlock"
DATA_DIR="/var/lib/faceunlock"

# Simulate existing installation
mkdir -p /tmp/test_install_dir
INSTALL_DIR="/tmp/test_install_dir"
DATA_DIR="/tmp/test_data_dir"
mkdir -p "$DATA_DIR"

# Create fake enrolled users
touch "$DATA_DIR/alice.npy"
touch "$DATA_DIR/bob.npy"
touch "$DATA_DIR/charlie.npy"

if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  Existing installation detected                ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════╝${NC}\n"
    
    if [ -d "$DATA_DIR" ] && ls "$DATA_DIR"/*.npy 1> /dev/null 2>&1; then
        ENROLLED_USERS=$(ls -1 "$DATA_DIR"/*.npy 2>/dev/null | wc -l)
        echo -e "${CYAN}Found $ENROLLED_USERS enrolled user(s):${NC}"
        ls -1 "$DATA_DIR"/*.npy 2>/dev/null | xargs -n1 basename | sed 's/.npy//' | sed 's/^/  - /'
        echo ""
    fi
    
    echo -e "${YELLOW}What would you like to do?${NC}"
    echo -e "  ${GREEN}1)${NC} Clean re-install (remove old installation, ${BOLD}keep user data${NC})"
    echo -e "  ${YELLOW}2)${NC} Skip installation (exit without changes)"
    echo -e "  ${RED}3)${NC} Full uninstall (remove everything including user data)"
    echo ""
    echo "This is how the prompt will look when Face Unlock is already installed."
fi

# Cleanup
rm -rf /tmp/test_install_dir /tmp/test_data_dir
