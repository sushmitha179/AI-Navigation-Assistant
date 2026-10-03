"""
Simple camera test to verify webcam access and basic OpenCV functionality.
"""
import cv2
import time

print("Testing camera access...")
cap = cv2.VideoCapture(0)

if not cap.isOpened():
    print("Error: Could not open webcam.")
    exit()

print("Camera opened successfully!")
print("Camera properties:")
print(f"  Width: {cap.get(cv2.CAP_PROP_FRAME_WIDTH)}")
print(f"  Height: {cap.get(cv2.CAP_PROP_FRAME_HEIGHT)}")
print(f"  FPS: {cap.get(cv2.CAP_PROP_FPS)}")

print("\nStarting camera test. Press Q to quit.")

frame_count = 0
start_time = time.time()

try:
    while True:
        success, frame = cap.read()
        if not success:
            print("Could not read frame.")
            break
        
        frame_count += 1
        
        # Add frame counter
        cv2.putText(frame, f"Frame: {frame_count}", (10, 30),
                   cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
        
        cv2.imshow("Camera Test", frame)
        
        # FPS update every 30 frames
        if frame_count % 30 == 0:
            elapsed = time.time() - start_time
            fps = frame_count / elapsed
            print(f"FPS: {fps:.1f}")
        
        key = cv2.waitKey(1) & 0xFF
        if key == ord('q'):
            print("Quit requested.")
            break
            
except KeyboardInterrupt:
    print("\nInterrupted by user.")
finally:
    elapsed = time.time() - start_time
    fps = frame_count / elapsed if elapsed > 0 else 0
    print(f"Final stats - Frames: {frame_count} | Average FPS: {fps:.1f}")
    
    cap.release()
    cv2.destroyAllWindows()
    print("Camera test completed.")
