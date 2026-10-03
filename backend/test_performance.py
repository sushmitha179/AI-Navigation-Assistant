"""
Performance test for perception module without GUI.
Tests YOLO detection, MiDaS depth estimation, and integration.
"""
import cv2
import numpy as np
import time
from perception_module import PerceptionModule

print("Testing perception module performance (no GUI)...")
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
print("=" * 60)

# Performance tracking
frame_count = 0
total_frames = 100  # Test for 100 frames
start_time = time.time()
yolo_times = []
midas_times = []
total_times = []

depth_available_count = 0
detection_count = 0

print(f"Running performance test for {total_frames} frames...")
print("Frame | YOLO(ms) | Total(ms) | Objects | Depth | FPS")
print("-" * 60)

try:
    while frame_count < total_frames:
        # Read frame
        success, frame = cap.read()
        if not success:
            print("Could not read frame.")
            break
        
        frame_count += 1
        
        # Process frame with timing
        frame_start = time.time()
        
        # YOLO detection timing
        yolo_start = time.time()
        detections = perception.yolo.detect(cv2.resize(frame, (640, 480)))
        yolo_time = (time.time() - yolo_start) * 1000
        yolo_times.append(yolo_time)
        
        # MiDaS depth estimation
        depth_map = perception.midas.estimate_depth(cv2.resize(frame, (640, 480)))
        
        # Total processing time
        total_time = (time.time() - frame_start) * 1000
        total_times.append(total_time)
        
        # Track statistics
        if depth_map is not None:
            depth_available_count += 1
        
        detection_count += len(detections)
        
        # Calculate running FPS
        elapsed = time.time() - start_time
        fps = frame_count / elapsed if elapsed > 0 else 0
        
        # Print progress every 10 frames
        if frame_count % 10 == 0:
            depth_status = "Yes" if depth_map is not None else "No"
            print(f"{frame_count:5d} | {yolo_time:7.1f} | {total_time:8.1f} | {len(detections):7d} | {depth_status:5s} | {fps:5.1f}")
        
except KeyboardInterrupt:
    print("\nInterrupted by user.")
finally:
    # Final statistics
    elapsed = time.time() - start_time
    avg_fps = frame_count / elapsed if elapsed > 0 else 0
    avg_yolo = np.mean(yolo_times) if yolo_times else 0
    avg_total = np.mean(total_times) if total_times else 0
    
    print("\n" + "=" * 60)
    print("PERFORMANCE RESULTS")
    print("=" * 60)
    print(f"Total frames processed: {frame_count}")
    print(f"Average FPS: {avg_fps:.2f}")
    print(f"Average YOLO time: {avg_yolo:.1f}ms")
    print(f"Average total processing time: {avg_total:.1f}ms")
    print(f"Depth maps available: {depth_available_count}/{frame_count} ({depth_available_count/frame_count*100:.1f}%)")
    print(f"Total detections: {detection_count}")
    print(f"Average detections per frame: {detection_count/frame_count:.1f}")
    print("=" * 60)
    
    cap.release()
    print("Performance test completed.")
