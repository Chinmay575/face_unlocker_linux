.PHONY: install uninstall release clean help

INSTALL_DIR = /opt/face-unlock

install:
	@echo "Installing face-unlock..."
	sudo bash scripts/install.sh

uninstall:
	@echo "Uninstalling face-unlock..."
	sudo bash scripts/uninstall.sh

release:
ifndef VERSION
	@echo "Usage: make release VERSION=1.2.0"
	@exit 1
endif
	@echo "Releasing v$(VERSION)..."
	@# Update version in __init__.py
	sed -i 's/__version__ = ".*"/__version__ = "$(VERSION)"/' face_unlock/__init__.py
	@# Update version.json
	@python3 -c "import json,time; d={'version':'$(VERSION)','commit_hash':'','updated_at':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())}; json.dump(d,open('version.json','w'),indent=2)"
	@# Commit and tag
	git add face_unlock/__init__.py version.json
	git commit -m "Release v$(VERSION)"
	git tag -a "v$(VERSION)" -m "Release v$(VERSION)"
	git push origin main
	git push origin "v$(VERSION)"
	@echo "Released v$(VERSION)"

clean:
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -name "*.pyc" -delete 2>/dev/null || true
	@echo "Cleaned build artifacts"

test:
	@echo "Running syntax checks..."
	python3 -m py_compile face_unlock/__init__.py
	python3 -m py_compile face_unlock/resource_guard.py
	python3 -m py_compile face_unlock/config.py
	python3 -m py_compile face_unlock/utils.py
	python3 -m py_compile face_unlock/detect.py
	python3 -m py_compile face_unlock/recognize.py
	python3 -m py_compile face_unlock/auth.py
	python3 -m py_compile face_unlock/enroll.py
	python3 -m py_compile face_unlock/updater.py
	python3 -m py_compile face_unlock/cli.py
	@echo "All modules compile successfully"

help:
	@echo "Face Unlock for Linux"
	@echo ""
	@echo "Commands:"
	@echo "  make install              - Install face-unlock system-wide"
	@echo "  make uninstall            - Remove face-unlock"
	@echo "  make release VERSION=x.y.z - Create a release"
	@echo "  make test                 - Run syntax checks"
	@echo "  make clean                - Clean build artifacts"
