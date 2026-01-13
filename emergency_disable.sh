#!/bin/bash
#
# EMERGENCY DISABLE SCRIPT FOR FACE UNLOCK
# Run this script if face unlock is causing login problems
#
# Usage: sudo ./emergency_disable.sh [-v|--verbose]
#

set -e

# Parse arguments
VERBOSE=false
for arg in "$@"; do
    case $arg in
        -v|--verbose)
            VERBOSE=true
            set -x  # Enable bash debug mode
            shift
            ;;
    esac
done

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging function
log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${CYAN}[VERBOSE]${NC} $1"
    fi
}

log_verbose "Verbose logging enabled"
log_verbose "Running as user: $(whoami)"
log_verbose "Script directory: $(pwd)"

echo -e "${RED}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║     EMERGENCY FACE UNLOCK DISABLE                     ║${NC}"
echo -e "${RED}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}✗ This script must be run as root (use sudo)${NC}"
    exit 1
fi

echo -e "${YELLOW}⚠️  This will disable face unlock authentication${NC}"
echo -e "${YELLOW}⚠️  You will need to use password authentication only${NC}"
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}✓ Cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}→ Stopping face unlock service...${NC}"
log_verbose "Checking if faceunlock.service exists"
systemctl stop faceunlock.service 2>/dev/null || true
log_verbose "Service stopped (exit code: $?)"
systemctl disable faceunlock.service 2>/dev/null || true
log_verbose "Service disabled (exit code: $?)"
echo -e "${GREEN}✓ Service stopped${NC}"

echo ""
echo -e "${YELLOW}→ Removing PAM configuration...${NC}"
log_verbose "Searching for PAM configuration files"

# Find and backup PAM files
PAM_FILES=(
    "/etc/pam.d/common-auth"
    "/etc/pam.d/system-auth"
    "/etc/pam.d/sudo"
    "/etc/pam.d/gdm-password"
    "/etc/pam.d/sddm"
    "/etc/pam.d/lightdm"
)

DISABLED_COUNT=0
for pam_file in "${PAM_FILES[@]}"; do
    if [ -f "$pam_file" ]; then
        if grep -q "pam_faceunlock.so" "$pam_file"; then
            # Create backup
            cp "$pam_file" "${pam_file}.faceunlock.backup.$(date +%Y%m%d_%H%M%S)"
            # Comment out face unlock lines
            sed -i 's/^auth.*pam_faceunlock\.so/#&/' "$pam_file"
            sed -i 's/^[[:space:]]*auth.*pam_faceunlock\.so/#&/' "$pam_file"
            echo -e "  ${GREEN}✓${NC} Disabled in $pam_file"
            ((DISABLED_COUNT++))
        fi
    fi
done

if [ $DISABLED_COUNT -eq 0 ]; then
    echo -e "  ${YELLOW}ℹ${NC} No PAM configuration found (already disabled?)"
else
    echo -e "${GREEN}✓ PAM configuration disabled in $DISABLED_COUNT file(s)${NC}"
fi

echo ""
echo -e "${YELLOW}→ Checking for PAM module...${NC}"

# Find and optionally remove PAM module
PAM_MODULE_PATHS=(
    "/usr/lib/security/pam_faceunlock.so"
    "/lib/security/pam_faceunlock.so"
    "/lib/x86_64-linux-gnu/security/pam_faceunlock.so"
    "/usr/lib64/security/pam_faceunlock.so"
)

MODULE_FOUND=false
for module_path in "${PAM_MODULE_PATHS[@]}"; do
    if [ -f "$module_path" ]; then
        MODULE_FOUND=true
        echo -e "  ${YELLOW}!${NC} Found: $module_path"
    fi
done

if [ "$MODULE_FOUND" = true ]; then
    echo ""
    read -p "Remove PAM module files? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for module_path in "${PAM_MODULE_PATHS[@]}"; do
            if [ -f "$module_path" ]; then
                rm -f "$module_path"
                echo -e "  ${GREEN}✓${NC} Removed: $module_path"
            fi
        done
    else
        echo -e "  ${YELLOW}ℹ${NC} PAM module files kept (disabled but not removed)"
    fi
else
    echo -e "  ${YELLOW}ℹ${NC} No PAM module found"
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ Face unlock has been disabled                     ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Summary:"
echo -e "  • Service: ${GREEN}stopped and disabled${NC}"
echo -e "  • PAM config: ${GREEN}disabled in $DISABLED_COUNT file(s)${NC}"
echo -e "  • Authentication: ${GREEN}password-only${NC}"
echo ""
echo -e "${YELLOW}ℹ${NC}  Backup files created with .faceunlock.backup suffix"
echo -e "${YELLOW}ℹ${NC}  You can now login normally with your password"
echo ""
echo -e "To re-enable face unlock later, run:"
echo -e "  ${YELLOW}sudo ./install.sh${NC}"
echo ""
