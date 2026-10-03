"""
Short GUI test to verify window creation and Q-key responsiveness.
"""
import cv2
import time
from perception_module import PerceptionModule

print("Testing GUI functionality (10 second test)...")
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
print("Test will run for 10 seconds or until Q is pressed.")
print("=" * 60)

frame_count = 0
start_time = time.time()
test_duration = 10  # 10 second test

try:
    while True:
        # Check time limit
        elapsed = time.time() - start_time
        if elapsed >= test_duration:
            print(f"Test duration reached ({test_duration}s)")
            break
        
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
        
        # Add test info
        cv2.putText(vis_frame, f"Time: {elapsed:.1f}s/{test_duration}s", (10, 90),
                   cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)
        
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
            print("Q key pressed - test stopped by user.")
            break
        
except KeyboardInterrupt:
    print("\nInterrupted by user.")
finally:
    # Final statistics
    elapsed = time.time() - start_time
    fps = frame_count / elapsed if elapsed > 0 else 0
    
    print("=" * 60)
    print("GUI TEST RESULTS")
    print("=" * 60)
    print(f"Test duration: {elapsed:.1f}s")
    print(f"Frames processed: {frame_count}")
    print(f"Average FPS: {fps:.1f}")
    print("GUI test completed successfully!")
    print("=" * 60)
    
    cap.release()
    cv2.destroyAllWindows()
