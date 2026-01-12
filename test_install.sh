#!/bin/bash
# Test script to verify installation

echo "Testing Face Unlock Installation..."
echo ""

# Test 1: Check commands exist
echo "1. Testing commands..."
for cmd in faceunlock-enroll faceunlock-service faceunlock-list faceunlock-remove; do
    if command -v $cmd &> /dev/null; then
        echo "  ✓ $cmd found"
    else
        echo "  ✗ $cmd NOT FOUND"
    fi
done
echo ""

# Test 2: Check service status
echo "2. Testing service..."
if systemctl is-active --quiet faceunlock.service; then
    echo "  ✓ Service is running"
else
    echo "  ✗ Service is NOT running"
fi
echo ""

# Test 3: Check socket file
echo "3. Testing socket file..."
if [ -S "/tmp/faceunlock.sock" ]; then
    echo "  ✓ Socket file exists"
    ls -la /tmp/faceunlock.sock
else
    echo "  ✗ Socket file NOT found"
fi
echo ""

# Test 4: Check enrolled users
echo "4. Testing user enrollment..."
faceunlock-list
echo ""

echo "Test complete!"
