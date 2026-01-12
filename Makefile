.PHONY: all build install uninstall test clean start stop status logs enroll

CC = gcc
CFLAGS = -fPIC -shared
LIBS = -lpam

PAM_MODULE = pam_faceunlock.so
PAM_INSTALL_DIR = /usr/lib/security
SERVICE_FILE = faceunlock.service
SERVICE_INSTALL_DIR = /etc/systemd/system

all: build

build:
	@echo "Building PAM module..."
	$(CC) $(CFLAGS) -o $(PAM_MODULE) pam_faceunlock.c $(LIBS)
	@echo "✓ Build complete"

install: build
	@echo "Installing PAM module..."
	sudo cp $(PAM_MODULE) $(PAM_INSTALL_DIR)/
	@echo "✓ PAM module installed to $(PAM_INSTALL_DIR)"
	
	@echo "Installing systemd service..."
	sudo cp $(SERVICE_FILE) $(SERVICE_INSTALL_DIR)/
	sudo systemctl daemon-reload
	@echo "✓ Systemd service installed"
	
	@echo "\n=== Installation Complete ==="
	@echo "Next steps:"
	@echo "1. Start daemon: make start"
	@echo "2. Enroll user: make enroll USER=\$$USER"
	@echo "3. Configure PAM in /etc/pam.d/"

uninstall:
	@echo "Stopping service..."
	-sudo systemctl stop faceunlock 2>/dev/null
	-sudo systemctl disable faceunlock 2>/dev/null
	
	@echo "Removing files..."
	sudo rm -f $(PAM_INSTALL_DIR)/$(PAM_MODULE)
	sudo rm -f $(SERVICE_INSTALL_DIR)/$(SERVICE_FILE)
	sudo systemctl daemon-reload
	
	@echo "✓ Uninstalled"
	@echo "Note: Enrolled face data is still in ~/.faceunlock/"
	@echo "Remove manually if desired: rm -rf ~/.faceunlock/"

start:
	@echo "Starting face unlock daemon..."
	sudo systemctl start faceunlock
	@sleep 1
	@sudo systemctl status faceunlock --no-pager

stop:
	@echo "Stopping face unlock daemon..."
	sudo systemctl stop faceunlock

restart:
	@echo "Restarting face unlock daemon..."
	sudo systemctl restart faceunlock
	@sleep 1
	@sudo systemctl status faceunlock --no-pager

enable:
	@echo "Enabling face unlock daemon..."
	sudo systemctl enable faceunlock

disable:
	@echo "Disabling face unlock daemon..."
	sudo systemctl disable faceunlock

status:
	@sudo systemctl status faceunlock --no-pager

logs:
	@echo "Showing daemon logs (Ctrl+C to exit)..."
	sudo journalctl -u faceunlock -f

enroll:
ifndef USER
	@echo "Usage: make enroll USER=username"
	@exit 1
endif
	@echo "Enrolling user: $(USER)"
	python3 enroll.py $(USER)

test:
ifndef USER
	$(eval USER := $(shell whoami))
endif
	@echo "Testing authentication for: $(USER)"
	python3 test_auth.py $(USER)

test-pam:
ifndef USER
	$(eval USER := $(shell whoami))
endif
	@echo "Testing PAM authentication for: $(USER)"
	@command -v pamtester >/dev/null 2>&1 || { echo "Error: pamtester not installed. Run: sudo apt install pamtester"; exit 1; }
	pamtester face-test $(USER) authenticate

clean:
	rm -f $(PAM_MODULE)
	rm -rf __pycache__
	@echo "✓ Cleaned build artifacts"

deps:
	@echo "Installing Python dependencies..."
	pip install -r requirements.txt
	@echo "✓ Dependencies installed"

help:
	@echo "Face Unlock for Linux - Makefile Commands"
	@echo ""
	@echo "Build & Install:"
	@echo "  make build       - Build PAM module"
	@echo "  make install     - Install PAM module and systemd service"
	@echo "  make uninstall   - Remove all installed files"
	@echo "  make deps        - Install Python dependencies"
	@echo ""
	@echo "Daemon Control:"
	@echo "  make start       - Start daemon"
	@echo "  make stop        - Stop daemon"
	@echo "  make restart     - Restart daemon"
	@echo "  make enable      - Enable daemon on boot"
	@echo "  make disable     - Disable daemon on boot"
	@echo "  make status      - Show daemon status"
	@echo "  make logs        - Tail daemon logs"
	@echo ""
	@echo "Usage:"
	@echo "  make enroll USER=username    - Enroll a user"
	@echo "  make test USER=username      - Test authentication"
	@echo "  make test-pam USER=username  - Test PAM integration"
	@echo ""
	@echo "Maintenance:"
	@echo "  make clean       - Clean build artifacts"
