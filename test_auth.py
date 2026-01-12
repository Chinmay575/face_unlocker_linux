#!/usr/bin/env python3
"""
Simple test client for face unlock daemon
"""
import socket
import json
import sys
import os

SOCKET_PATH = "/tmp/faceunlock.sock"
DATA_DIR = "/var/lib/faceunlock"

def test_auth(username):
    """Test authentication for a user"""
    
    # Check if user is enrolled
    user_file = f"{DATA_DIR}/{username}.npy"
    if not os.path.exists(user_file):
        print(f"Error: User '{username}' is not enrolled")
        print(f"Run: sudo faceunlock-enroll {username}")
        return False
    
    if not os.path.exists(SOCKET_PATH):
        print(f"Error: Daemon socket not found at {SOCKET_PATH}")
        print("Is the daemon running? (sudo systemctl start faceunlock)")
        return False
    
    try:
        # Connect to daemon
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.connect(SOCKET_PATH)
        
        # Send request
        request = {"user": username}
        sock.send(json.dumps(request).encode('utf-8'))
        
        # Receive response
        response = sock.recv(1024).decode('utf-8')
        sock.close()
        
        # Parse response
        result = json.loads(response)
        
        print(f"\n=== Face Authentication Test ===")
        print(f"User: {username}")
        print(f"Success: {result.get('ok', False)}")
        print(f"Confidence: {result.get('confidence', 0.0):.3f}")
        
        if result.get('error'):
            print(f"Error: {result.get('error')}")
        
        return result.get('ok', False)
        
    except FileNotFoundError:
        print(f"Error: Socket not found. Is daemon running?")
        return False
    except ConnectionRefusedError:
        print(f"Error: Connection refused. Is daemon running?")
        return False
    except Exception as e:
        print(f"Error: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) < 2:
        username = os.getenv('USER', 'root')
        print(f"No username provided, using: {username}")
    else:
        username = sys.argv[1]
    
    success = test_auth(username)
    sys.exit(0 if success else 1)
