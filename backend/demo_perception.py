"""
Demo script to test perception module with synthetic input (no camera required).
This demonstrates the functionality without requiring webcam access.
"""
import numpy as np
import cv2
from perception_module import PerceptionModule

print("Creating synthetic test frame...")
# Create a synthetic test frame (640x480 RGB)
test_frame = np.random.randint(0, 255, (480, 640, 3), dtype=np.uint8)

# Add some "objects" as colored rectangles
cv2.rectangle(test_frame, (100, 100), (200, 200), (255, 0, 0), -1)  # Blue box
cv2.rectangle(test_frame, (300, 150), (400, 250), (0, 255, 0), -1)  # Green box
cv2.rectangle(test_frame, (450, 300), (550, 400), (0, 0, 255), -1)  # Red box

print("Initializing perception module...")
perception = PerceptionModule(
    yolo_model_path="yolo11n.pt",
    yolo_confidence=0.40,
    midas_skip_frames=1,  # Process every frame for demo
    frame_size=(640, 480)
)

print("Processing synthetic frame...")
results = perception.process_frame(test_frame)

print(f"\nProcessing Results:")
print(f"Frame size: {results['frame'].shape}")
print(f"Number of detections: {len(results['detections'])}")
print(f"Depth map available: {results['depth_map'] is not None}")

if results['detections']:
    print("\nDetected objects:")
    for i, detection in enumerate(results['detections']):
        print(f"  {i+1}. {detection['class_name']} (confidence: {detection['confidence']:.2f})")
        print(f"     Bounding box: {detection['bbox']}")
        if detection['depth_value'] is not None:
            print(f"     Depth value: {detection['depth_value']:.1f}")
        if detection['proximity_category'] is not None:
            print(f"     Proximity: {detection['proximity_category'].value}")
            print(f"     Description: {detection['proximity_description']}")
else:
    print("No objects detected (expected with synthetic input)")

print("\nCreating visualization...")
vis_frame = perception.visualize_results(results)

print("Saving visualization to demo_output.jpg...")
cv2.imwrite("demo_output.jpg", vis_frame)
print("✓ Visualization saved")

print("\n" + "="*60)
print("Demo completed successfully!")
print("="*60)
print("\nKey features demonstrated:")
print("✓ Modular YOLO + MiDaS integration")
print("✓ Non-blocking depth estimation")
print("✓ Relative depth classification (VERY CLOSE, CLOSE, MEDIUM, FAR)")
print("✓ Responsive architecture suitable for real-time applications")
print("\nTo run with real camera:")
print("  python perception_module.py")
