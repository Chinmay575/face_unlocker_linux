import cv2
import numpy as np
import os
import sys
import argparse
from pathlib import Path
from face_embedder import FaceEmbedder

# Configuration
SAVE_DIR = "/var/lib/faceunlock"
MODEL = "/opt/faceunlock/models/arcfaceresnet100-8.onnx"
REQUIRED_SAMPLES = 5
MIN_FACE_SIZE = (80, 80)

def enroll_user(username, samples=REQUIRED_SAMPLES):
    """Enroll a user's face"""
    
    # Validate username
    if not username or '/' in username or '\\' in username or username.startswith('.'):
        print(f"Error: Invalid username '{username}'")
        return False
    
    # Create directory
    Path(SAVE_DIR).mkdir(parents=True, exist_ok=True)
    
    # Check if model exists
    if not os.path.exists(MODEL):
        print(f"Error: Model file not found: {MODEL}")
        return False
    
    print(f"\n=== Enrolling user: {username} ===\n")
    
    # Initialize camera
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("Error: Failed to open camera")
        return False
    print("✓ Camera opened successfully")
    
    # Initialize detector
    detector = cv2.CascadeClassifier(
        cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
    )
    if detector.empty():
        print("Error: Failed to load face detector")
        cap.release()
        return False
    print("✓ Face detector loaded")
    
    # Initialize embedder
    try:
        embedder = FaceEmbedder(MODEL)
        print("✓ Face embedder loaded")
    except Exception as e:
        print(f"Error: Failed to load embedder: {e}")
        cap.release()
        return False
    
    embeddings = []
    print(f"\nLook straight at the camera.")
    print(f"Press SPACE to capture ({samples} samples needed)")
    print("Press ESC to cancel\n")
    
    while len(embeddings) < samples:
        ret, frame = cap.read()
        if not ret:
            print("Warning: Failed to read frame from camera")
            continue
        
        # Detect faces
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        faces = detector.detectMultiScale(gray, 1.3, 5, minSize=MIN_FACE_SIZE)
        
        # Draw rectangles and status
        display_frame = frame.copy()
        status_text = ""
        status_color = (0, 0, 255)  # Red
        
        if len(faces) == 0:
            status_text = "No face detected"
        elif len(faces) > 1:
            status_text = f"{len(faces)} faces detected - need exactly 1"
        else:
            x, y, w, h = faces[0]
            cv2.rectangle(display_frame, (x, y), (x+w, y+h), (0, 255, 0), 2)
            status_text = "Ready - Press SPACE to capture"
            status_color = (0, 255, 0)  # Green
        
        # Draw all faces with red rectangles if multiple
        if len(faces) > 1:
            for (x, y, w, h) in faces:
                cv2.rectangle(display_frame, (x, y), (x+w, y+h), (0, 0, 255), 2)
        
        # Add status text
        cv2.putText(display_frame, status_text, (10, 30), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.7, status_color, 2)
        cv2.putText(display_frame, f"Captured: {len(embeddings)}/{samples}", (10, 60),
                   cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
        
        cv2.imshow(f"Enroll Face - {username}", display_frame)
        
        key = cv2.waitKey(1)
        
        # Capture on SPACE
        if key == 32:  # SPACE
            if len(faces) == 1:
                x, y, w, h = faces[0]
                face = frame[y:y+h, x:x+w]
                
                try:
                    emb = embedder.embed(face)
                    embeddings.append(emb)
                    print(f"✓ Captured sample {len(embeddings)}/{samples}")
                except Exception as e:
                    print(f"✗ Failed to process face: {e}")
            else:
                print(f"✗ Detected {len(faces)} faces - need exactly 1")
        
        # Cancel on ESC
        elif key == 27:  # ESC
            print("\nEnrollment cancelled by user")
            cap.release()
            cv2.destroyAllWindows()
            return False
    
    cap.release()
    cv2.destroyAllWindows()
    
    # Process and save embeddings
    if len(embeddings) == samples:
        try:
            # Average all embeddings
            final_embedding = np.mean(embeddings, axis=0)
            # Normalize
            final_embedding /= np.linalg.norm(final_embedding)
            
            # Save
            save_path = Path(SAVE_DIR) / f"{username}.npy"
            np.save(save_path, final_embedding)
            
            print(f"\n✓ Enrollment successful!")
            print(f"✓ Saved to: {save_path}")
            return True
        except Exception as e:
            print(f"\n✗ Failed to save enrollment: {e}")
            return False
    else:
        print(f"\n✗ Insufficient samples: {len(embeddings)}/{samples}")
        return False


def main():
    parser = argparse.ArgumentParser(description='Enroll a user for face unlock')
    parser.add_argument('username', type=str, help='Username to enroll')
    parser.add_argument('-s', '--samples', type=int, default=REQUIRED_SAMPLES,
                       help=f'Number of samples to collect (default: {REQUIRED_SAMPLES})')
    
    args = parser.parse_args()
    
    success = enroll_user(args.username, args.samples)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
