# AI Navigation Assistant - Perception Module

A modular, optimized perception system combining YOLO object detection, MiDaS depth estimation, and collision risk analysis for visually impaired navigation assistance.

## Overview

This perception module provides real-time object detection, relative depth estimation, and collision risk assessment using:
- **YOLO11n**: Fast object detection
- **MiDaS Small**: Monocular depth estimation
- **Collision Risk Analysis**: Position, size, and depth-based risk assessment
- **Responsive Architecture**: Non-blocking depth inference for smooth UI

## Key Features

- **Modular Design**: Separate components for detection, depth estimation, classification, and risk analysis
- **Non-blocking Depth**: MiDaS runs in background threads to prevent UI freezing
- **Relative Depth Classification**: Objects classified as VERY CLOSE, CLOSE, MEDIUM, or FAR
- **Collision Risk Analysis**: Conservative risk assessment (LOW, MEDIUM, HIGH) based on position, size, and depth
- **CPU Optimized**: Frame skipping and efficient processing for CPU-only devices
- **Clean Quit**: Responsive OpenCV interface with immediate Q key response

## Architecture

### Components

1. **yolo_detector.py**: YOLO object detection module
   - Handles YOLO11n model loading and inference
   - Returns bounding boxes, class names, and confidence scores

2. **midas_depth.py**: MiDaS depth estimation module
   - Non-blocking depth inference using background threads
   - Configurable frame skipping for CPU efficiency
   - Provides depth values for bounding box regions

3. **depth_classifier.py**: Depth classification module
   - Converts MiDaS depth values to relative proximity categories
   - Adaptive normalization based on scene percentiles
   - Categories: VERY CLOSE, CLOSE, MEDIUM, FAR

4. **collision_risk.py**: Collision risk analysis module
   - Analyzes collision risk based on position, size, and depth
   - Horizontal position classification (LEFT, CENTER, RIGHT)
   - Risk levels: LOW, MEDIUM, HIGH
   - Conservative safety-first risk assessment

5. **perception_module.py**: Main integration module
   - Combines YOLO, MiDaS, and collision risk processing
   - Associates depth and risk with detected objects
   - Provides enhanced visualization with risk information
   - Camera interface with real-time processing

## Files Changed

### New Files Created
- `yolo_detector.py` - YOLO detection module
- `midas_depth.py` - MiDaS depth estimation with non-blocking inference
- `depth_classifier.py` - Depth classification system
- `collision_risk.py` - Collision risk analysis module
- `perception_module.py` - Main perception module integrating all components
- `test_perception.py` - Component testing script
- `test_collision_risk.py` - Collision risk unit tests
- `test_integration.py` - Integration testing script
- `demo_perception.py` - Demo script with synthetic input
- `requirements.txt` - Python dependencies
- `COLLISION_RISK_DOCUMENTATION.md` - Detailed collision risk documentation

### Original Files (Preserved)
- `camera_detection.py` - Original YOLO-only implementation
- `depth_camera.py` - Original MiDaS-only implementation
- `depth_test.py` - Original MiDaS test script

## Installation

Ensure you have the required dependencies:

```bash
cd backend
pip install -r requirements.txt
```

Or install manually:
```bash
pip install torch torchvision opencv-python ultralytics numpy
```

## Usage

### Run Full Camera Application

```bash
cd backend
python perception_module.py
```

This will:
1. Open your webcam
2. Display detected objects with bounding boxes
3. Show relative depth classification for each object
4. Display collision risk analysis (HIGH/MEDIUM/LOW)
5. Show horizontal position (LEFT/CENTER/RIGHT)
6. Display a depth map visualization
7. Allow clean exit with the Q key

### Test Components Without Camera

```bash
cd backend
python test_perception.py
```

This tests all module components without requiring camera access.

### Test Collision Risk Analysis

```bash
cd backend
python test_collision_risk.py
```

This runs comprehensive unit tests for the collision risk analysis module.

### Test Integration

```bash
cd backend
python test_integration.py
```

This tests the integration of collision risk analysis with the perception module.

### Run Demo with Synthetic Input

```bash
cd backend
python demo_perception.py
```

This demonstrates the perception pipeline with synthetic test data.

## Depth Classification

The system uses **relative depth classification**, not metric distance:

- **VERY CLOSE**: Top 25% closest objects in the scene
- **CLOSE**: Top 50% closest objects in the scene  
- **MEDIUM**: Objects at median distance
- **FAR**: Bottom 25% deepest objects in the scene

### Important Notes

- MiDaS provides **relative depth**, not absolute distance in meters
- Raw MiDaS values (e.g., 400-700) are scene-dependent and should not be interpreted as metric units
- Classification adapts to each scene using percentile-based normalization
- Categories are relative to the current scene content

## Collision Risk Analysis

The system provides conservative collision risk assessment for navigation safety:

### Risk Determination

Collision risk is determined based on:
- **Horizontal Position**: LEFT, CENTER, RIGHT
- **Bounding Box Size**: Large or small relative to frame
- **Relative Depth**: VERY CLOSE, CLOSE, MEDIUM, FAR

### Risk Levels

- **HIGH**: Objects that pose immediate collision risk
  - VERY CLOSE + CENTER
  - CLOSE + CENTER + large bounding box

- **MEDIUM**: Objects that require caution
  - VERY CLOSE + LEFT/RIGHT
  - CLOSE + CENTER + small bounding box
  - CLOSE + LEFT/RIGHT
  - MEDIUM + CENTER + large bounding box

- **LOW**: Objects that pose minimal immediate risk
  - MEDIUM + CENTER + small bounding box
  - MEDIUM + LEFT/RIGHT
  - FAR (any position)

### Output Format

Each detection includes:
- `collision_risk`: LOW, MEDIUM, or HIGH
- `horizontal_position`: LEFT, CENTER, or RIGHT
- Formatted display: "object | position | proximity | risk"

### Important Notes

- **Conservative rules**: System errs on side of caution for safety
- **Relative assessment**: Risk is relative to current scene, not absolute
- **Position-based**: CENTER objects pose higher collision risk
- **Size consideration**: Larger objects indicate closer proximity
- **Navigation integration**: Structured output for decision engines

See `COLLISION_RISK_DOCUMENTATION.md` for detailed technical documentation.

## Performance Optimization

The module includes several CPU optimizations:

1. **Frame Skipping**: MiDaS processes every Nth frame (default: 5)
2. **Background Threading**: Depth estimation runs in separate threads
3. **Efficient Resizing**: Frames resized to 640x480 for processing
4. **Non-blocking UI**: OpenCV window remains responsive during inference

## Configuration

Key parameters in `perception_module.py`:

```python
PerceptionModule(
    yolo_model_path="yolo11n.pt",      # YOLO model file
    yolo_confidence=0.40,              # Detection confidence threshold
    midas_skip_frames=5,               # Frames between depth estimations
    frame_size=(640, 480)              # Processing resolution
)
```

Adjust `midas_skip_frames` based on your CPU performance:
- Lower value (1-3): Smoother depth updates, higher CPU usage
- Higher value (5-10): Lower CPU usage, less frequent depth updates

## Visualization

The main application displays:

1. **Main Window**: Camera feed with:
   - Bounding boxes around detected objects
   - Object names and confidence scores
   - Horizontal position (LEFT/CENTER/RIGHT)
   - Depth values and proximity categories
   - Collision risk levels (HIGH/MEDIUM/LOW)
   - Risk summary statistics (High/Medium/Low counts)
   - Color-coded by collision risk (Red=HIGH, Orange=MEDIUM, Yellow=LOW)

2. **Depth Map Window**: Normalized depth visualization using magma colormap

## Troubleshooting

### "Could not open webcam"
- Check webcam permissions
- Try different camera index: `perception.run_camera(camera_index=1)`

### Slow performance
- Increase `midas_skip_frames` parameter
- Reduce `frame_size` resolution
- Close other applications

### Import errors
- Ensure virtual environment is activated
- Install dependencies: `pip install -r requirements.txt`

## Future Extensions

The modular architecture supports easy addition of:
- OCR for text reading
- VLM for scene understanding
- Navigation path planning
- Audio feedback system
- Flutter mobile interface

Note: Collision risk analysis is now integrated and ready for navigation decision engine consumption.

## License

This is part of the AI-Powered Intelligent Navigation and Scene Understanding Assistant project for visually impaired people.
