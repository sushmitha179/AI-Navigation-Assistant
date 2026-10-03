"""
Test script to verify perception module components can be imported and initialized.
"""
import sys
import numpy as np

print("Testing perception module imports...")

try:
    from yolo_detector import YOLODetector
    print("✓ YOLODetector imported successfully")
except Exception as e:
    print(f"✗ Failed to import YOLODetector: {e}")
    sys.exit(1)

try:
    from midas_depth import MiDaSDepthEstimator
    print("✓ MiDaSDepthEstimator imported successfully")
except Exception as e:
    print(f"✗ Failed to import MiDaSDepthEstimator: {e}")
    sys.exit(1)

try:
    from depth_classifier import DepthClassifier, ProximityCategory
    print("✓ DepthClassifier imported successfully")
except Exception as e:
    print(f"✗ Failed to import DepthClassifier: {e}")
    sys.exit(1)

try:
    from perception_module import PerceptionModule
    print("✓ PerceptionModule imported successfully")
except Exception as e:
    print(f"✗ Failed to import PerceptionModule: {e}")
    sys.exit(1)

print("\nTesting component initialization...")

try:
    # Test YOLO detector initialization
    yolo = YOLODetector("yolo11n.pt", confidence_threshold=0.40)
    print("✓ YOLODetector initialized successfully")
except Exception as e:
    print(f"✗ Failed to initialize YOLODetector: {e}")
    sys.exit(1)

try:
    # Test MiDaS initialization
    midas = MiDaSDepthEstimator(skip_frames=5)
    print("✓ MiDaSDepthEstimator initialized successfully")
except Exception as e:
    print(f"✗ Failed to initialize MiDaSDepthEstimator: {e}")
    sys.exit(1)

try:
    # Test depth classifier initialization
    classifier = DepthClassifier()
    print("✓ DepthClassifier initialized successfully")
except Exception as e:
    print(f"✗ Failed to initialize DepthClassifier: {e}")
    sys.exit(1)

try:
    # Test perception module initialization
    perception = PerceptionModule(
        yolo_model_path="yolo11n.pt",
        yolo_confidence=0.40,
        midas_skip_frames=5,
        frame_size=(640, 480)
    )
    print("✓ PerceptionModule initialized successfully")
except Exception as e:
    print(f"✗ Failed to initialize PerceptionModule: {e}")
    sys.exit(1)

print("\nTesting depth classification...")
try:
    # Test depth classification with synthetic data
    depth_map = np.random.rand(100, 100) * 1000
    classifier = DepthClassifier()
    
    # Test various depth values
    test_depths = [100, 300, 500, 800]
    for depth in test_depths:
        category, description = classifier.classify(depth, depth_map)
        print(f"  Depth {depth}: {category.value} - {description}")
    
    print("✓ Depth classification working")
except Exception as e:
    print(f"✗ Depth classification failed: {e}")
    sys.exit(1)

print("\n" + "="*60)
print("All tests passed! Perception module is ready to use.")
print("="*60)
print("\nTo run the full camera application:")
print("  python perception_module.py")
print("\nNote: This requires webcam access and will open OpenCV windows.")
