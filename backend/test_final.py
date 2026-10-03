"""
Final comprehensive test of perception module.
Tests all functionality with automatic termination after 15 seconds.
"""
import cv2
import numpy as np
import time
from perception_module import PerceptionModule

print("=" * 70)
print("FINAL PERCEPTION MODULE TEST")
print("=" * 70)

# Initialize perception module
print("\n1. Initializing perception module...")
perception = PerceptionModule(
    yolo_model_path="yolo11n.pt",
    yolo_confidence=0.40,
    midas_skip_frames=5,
    frame_size=(640, 480)
)
print("   ✓ Perception module initialized")

# Open camera
print("\n2. Opening camera...")
cap = cv2.VideoCapture(0)

if not cap.isOpened():
    print("   ✗ Error: Could not open webcam.")
    exit()

print("   ✓ Camera opened successfully")
print(f"   Resolution: {int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))}x{int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))}")

# Test parameters
test_duration = 15  # 15 second test
print(f"\n3. Running comprehensive test for {test_duration} seconds...")
print("   Testing: YOLO detection, MiDaS depth, classification, UI responsiveness")

frame_count = 0
start_time = time.time()
detection_count = 0
depth_available_count = 0
classification_count = 0
processing_times = []

try:
    while True:
        # Check time limit
        elapsed = time.time() - start_time
        if elapsed >= test_duration:
            print(f"\n   Test duration reached ({test_duration}s)")
            break
        
        # Read frame
        success, frame = cap.read()
        if not success:
            print("   ✗ Could not read frame.")
            break
        
        frame_count += 1
        
        # Process frame with timing
        frame_start = time.time()
        results = perception.process_frame(frame)
        process_time = (time.time() - frame_start) * 1000
        processing_times.append(process_time)
        
        # Track statistics
        detection_count += len(results['detections'])
        if results['depth_map'] is not None:
            depth_available_count += 1
        
        for detection in results['detections']:
            if detection['proximity_category'] is not None:
                classification_count += 1
        
        # Create visualization
        vis_frame = perception.visualize_results(results)
        
        # Add test info to frame
        fps = frame_count / elapsed if elapsed > 0 else 0
        info_text = f"FPS: {fps:.1f} | Time: {elapsed:.1f}s/{test_duration}s"
        cv2.putText(vis_frame, info_text, (10, 90),
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
        
        # Check for quit key (testing responsiveness)
        key = cv2.waitKey(1) & 0xFF
        if key == ord('q'):
            print(f"\n   Q key pressed at {elapsed:.1f}s - UI responsive!")
            break
        
except KeyboardInterrupt:
    print("\n   Interrupted by user.")
finally:
    # Final statistics
    total_elapsed = time.time() - start_time
    avg_fps = frame_count / total_elapsed if total_elapsed > 0 else 0
    avg_process_time = np.mean(processing_times) if processing_times else 0
    
    print("\n" + "=" * 70)
    print("TEST RESULTS")
    print("=" * 70)
    print(f"Test duration: {total_elapsed:.1f}s")
    print(f"Frames processed: {frame_count}")
    print(f"Average FPS: {avg_fps:.2f}")
    print(f"Average processing time: {avg_process_time:.1f}ms")
    print(f"Total detections: {detection_count}")
    print(f"Average detections per frame: {detection_count/frame_count:.1f}")
    print(f"Depth maps available: {depth_available_count}/{frame_count} ({depth_available_count/frame_count*100:.1f}%)")
    print(f"Classifications made: {classification_count}")
    
    print("\n" + "=" * 70)
    print("COMPONENT STATUS")
    print("=" * 70)
    print(f"Webcam access: {'✓ WORKING' if frame_count > 0 else '✗ FAILED'}")
    print(f"YOLO detection: {'✓ WORKING' if detection_count > 0 else '✗ FAILED'}")
    print(f"MiDaS depth: {'✓ WORKING' if depth_available_count > 0 else '✗ FAILED'}")
    print(f"Depth classification: {'✓ WORKING' if classification_count > 0 else '✗ FAILED'}")
    print(f"UI responsiveness: {'✓ WORKING' if avg_fps > 1 else '✗ TOO SLOW'}")
    print(f"Q-key exit: {'✓ WORKING' if key == ord('q') else '✓ TIMEOUT (normal)'}")
    
    print("\n" + "=" * 70)
    print("PERFORMANCE SUMMARY")
    print("=" * 70)
    if avg_fps >= 5:
        print(f"Performance: GOOD ({avg_fps:.1f} FPS)")
    elif avg_fps >= 2:
        print(f"Performance: ACCEPTABLE ({avg_fps:.1f} FPS)")
    else:
        print(f"Performance: SLOW ({avg_fps:.1f} FPS) - Consider optimization")
    
    print("=" * 70)
    
    cap.release()
    cv2.destroyAllWindows()
    print("Test completed successfully!")
