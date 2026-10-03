"""
Real-time camera test to verify collision risk integration.
Runs for 10 seconds to verify collision risk analysis works with real camera input.
"""
import cv2
import time
from perception_module import PerceptionModule

print("=" * 70)
print("REAL-TIME COLLISION RISK INTEGRATION TEST")
print("=" * 70)

# Initialize perception module
print("Initializing perception module with collision risk analysis...")
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
print("Running 10-second real-time test with collision risk analysis...")
print("=" * 70)

frame_count = 0
start_time = time.time()
test_duration = 10  # 10 second test
total_high_risk = 0
total_medium_risk = 0
total_low_risk = 0

try:
    while True:
        # Check time limit
        elapsed = time.time() - start_time
        if elapsed >= test_duration:
            print(f"\nTest duration reached ({test_duration}s)")
            break
        
        # Read frame
        success, frame = cap.read()
        if not success:
            print("Could not read frame.")
            break
        
        frame_count += 1
        
        # Process frame
        results = perception.process_frame(frame)
        
        # Track risk statistics
        risk_summary = results.get('risk_summary', {})
        total_high_risk += risk_summary.get('high_risk_count', 0)
        total_medium_risk += risk_summary.get('medium_risk_count', 0)
        total_low_risk += risk_summary.get('low_risk_count', 0)
        
        # Create visualization
        vis_frame = perception.visualize_results(results)
        
        # Add test info
        cv2.putText(vis_frame, f"Time: {elapsed:.1f}s/{test_duration}s", (10, 170),
                   cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)
        
        # Display camera feed
        cv2.imshow("AI Navigation Assistant - Collision Risk Test", vis_frame)
        
        # Display depth map if available
        if results['normalized_depth_map'] is not None:
            depth_colormap = cv2.applyColorMap(
                results['normalized_depth_map'],
                cv2.COLORMAP_MAGMA
            )
            cv2.imshow("Depth Map", depth_colormap)
        
        # Check for quit key
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
    
    print("\n" + "=" * 70)
    print("REAL-TIME COLLISION RISK TEST RESULTS")
    print("=" * 70)
    print(f"Test duration: {elapsed:.1f}s")
    print(f"Frames processed: {frame_count}")
    print(f"Average FPS: {fps:.1f}")
    print(f"\nCollision Risk Statistics:")
    print(f"  Total HIGH risk detections: {total_high_risk}")
    print(f"  Total MEDIUM risk detections: {total_medium_risk}")
    print(f"  Total LOW risk detections: {total_low_risk}")
    print(f"  Total risk assessments: {total_high_risk + total_medium_risk + total_low_risk}")
    
    print("\n" + "=" * 70)
    print("INTEGRATION STATUS")
    print("=" * 70)
    print(f"Camera access: {'✓ WORKING' if frame_count > 0 else '✗ FAILED'}")
    print(f"YOLO detection: {'✓ WORKING' if total_high_risk + total_medium_risk + total_low_risk > 0 else '✗ NO OBJECTS'}")
    print(f"Collision risk analysis: {'✓ WORKING' if total_high_risk + total_medium_risk + total_low_risk > 0 else '✗ NO RISK DATA'}")
    print(f"UI responsiveness: {'✓ WORKING' if fps > 1 else '✗ TOO SLOW'}")
    
    print("\n" + "=" * 70)
    if total_high_risk + total_medium_risk + total_low_risk > 0:
        print("✓ Collision risk analysis successfully integrated and working!")
    else:
        print("⚠ No objects detected during test (may be normal for empty scene)")
    print("=" * 70)
    
    cap.release()
    cv2.destroyAllWindows()
    print("Real-time test completed.")
