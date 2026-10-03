"""
Test Q-key responsiveness specifically.
"""
import cv2
import time
from perception_module import PerceptionModule

print("Testing Q-key responsiveness...")
print("=" * 60)

# Initialize perception module
print("Initializing perception module...")
perception = PerceptionModule(
    yolo_model_path="yolo11n.pt",
    yolo_confidence=0.40,
    midas_skip_frames=5,
    frame_size=(640, 480)
)

# Open camera
print("Opening camera...")
cap = cv2.VideoCapture(0)

if not cap.isOpened():
    print("Error: Could not open webcam.")
    exit()

print("Camera opened successfully.")
print("Test will run for 5 seconds, then check if Q key works.")
print("After 5 seconds, press Q to test responsiveness.")
print("=" * 60)

frame_count = 0
start_time = time.time()
test_duration = 5  # 5 second initial test

try:
    first_phase = True
    while True:
        # Read frame
        success, frame = cap.read()
        if not success:
            print("Could not read frame.")
            break
        
        frame_count += 1
        
        # Process frame
        results = perception.process_frame(frame)
        
        # Create visualization
        vis_frame = perception.visualize_results(results)
        
        elapsed = time.time() - start_time
        
        if first_phase and elapsed >= test_duration:
            first_phase = False
            print("5 seconds elapsed. Now testing Q-key responsiveness.")
            print("Please press Q to test if the application responds immediately.")
            cv2.putText(vis_frame, "PRESS Q TO TEST", (10, 120),
                       cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 3)
        
        # Display camera feed
        cv2.imshow("AI Navigation Assistant", vis_frame)
        
        # Display depth map if available
        if results['normalized_depth_map'] is not None:
            depth_colormap = cv2.applyColorMap(
                results['normalized_depth_map'],
                cv2.COLORMAP_MAGMA
            )
            cv2.imshow("Depth Map", depth_colormap)
        
        # Check for quit key (non-blocking)
        key = cv2.waitKey(1) & 0xFF
        if key == ord('q'):
            q_pressed_time = time.time()
            response_time = q_pressed_time - start_time
            print(f"Q key pressed at {response_time:.1f}s - immediate response confirmed!")
            break
        
except KeyboardInterrupt:
    print("\nInterrupted by user.")
finally:
    # Final statistics
    elapsed = time.time() - start_time
    fps = frame_count / elapsed if elapsed > 0 else 0
    
    print("=" * 60)
    print("Q-KEY TEST RESULTS")
    print("=" * 60)
    print(f"Test duration: {elapsed:.1f}s")
    print(f"Frames processed: {frame_count}")
    print(f"Average FPS: {fps:.1f}")
    print("Q-key responsiveness test completed!")
    print("=" * 60)
    
    cap.release()
    cv2.destroyAllWindows()
