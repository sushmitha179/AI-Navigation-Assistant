"""
Check camera availability without opening windows.
"""
import cv2

print("Checking camera availability...")

# Try to open camera
cap = cv2.VideoCapture(0)

if not cap.isOpened():
    print("Camera 0: NOT AVAILABLE")
    
    # Try camera 1
    cap = cv2.VideoCapture(1)
    if not cap.isOpened():
        print("Camera 1: NOT AVAILABLE")
        print("No cameras found.")
        exit()
    else:
        print("Camera 1: AVAILABLE")
else:
    print("Camera 0: AVAILABLE")

# Get camera properties
print(f"  Width: {cap.get(cv2.CAP_PROP_FRAME_WIDTH)}")
print(f"  Height: {cap.get(cv2.CAP_PROP_FRAME_HEIGHT)}")
print(f"  FPS: {cap.get(cv2.CAP_PROP_FPS)}")

# Try to read a frame
success, frame = cap.read()
if success:
    print(f"  Frame shape: {frame.shape}")
    print("Camera read test: SUCCESS")
else:
    print("Camera read test: FAILED")

cap.release()
print("Camera check completed.")
