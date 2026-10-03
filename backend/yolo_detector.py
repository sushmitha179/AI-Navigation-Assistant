from ultralytics import YOLO
import cv2
from typing import List, Dict, Tuple
import numpy as np


class YOLODetector:
    """YOLO object detection module for identifying objects in camera frames."""
    
    def __init__(self, model_path: str = "yolo11n.pt", confidence_threshold: float = 0.40):
        """
        Initialize YOLO detector.
        
        Args:
            model_path: Path to YOLO model file
            confidence_threshold: Minimum confidence for object detection
        """
        self.model = YOLO(model_path)
        self.confidence_threshold = confidence_threshold
        print(f"YOLO model loaded from {model_path}")
    
    def detect(self, frame: np.ndarray, imgsz: int = 416) -> List[Dict]:
        """
        Detect objects in a frame.
        
        Args:
            frame: Input image frame (BGR format)
            imgsz: Input size for YOLO inference
            
        Returns:
            List of detected objects with bounding boxes, class names, and confidence
        """
        results = self.model(
            frame,
            imgsz=imgsz,
            conf=self.confidence_threshold,
            verbose=False
        )
        
        result = results[0]
        detections = []
        
        for box in result.boxes:
            class_id = int(box.cls[0])
            object_name = self.model.names[class_id]
            confidence = float(box.conf[0])
            
            # Get bounding box coordinates
            x1, y1, x2, y2 = box.xyxy[0].cpu().numpy()
            
            detections.append({
                'class_name': object_name,
                'confidence': confidence,
                'bbox': (int(x1), int(y1), int(x2), int(y2)),
                'class_id': class_id
            })
        
        return detections
    
    def get_class_names(self) -> Dict[int, str]:
        """Get mapping of class IDs to class names."""
        return self.model.names
