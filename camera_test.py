import cv2 

cap = cv2.VideoCapture(0)

if not cap.isOpened():
    print("Camera not accessible")
    exit(1)

ret,frame = cap.read()
cap.release()

print("Camera accessed successfully:", frame.shape if ret else "Failed to read frame")