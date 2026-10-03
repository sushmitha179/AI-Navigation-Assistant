import cv2
import numpy as np
from typing import List, Dict, Optional
from yolo_detector import YOLODetector
from midas_depth import MiDaSDepthEstimator
from depth_classifier import DepthClassifier, ProximityCategory
from collision_risk import CollisionRiskAnalyzer


class PerceptionModule:
    """Main perception module integrating YOLO object detection and MiDaS depth estimation."""
    
    def __init__(self, 
                 yolo_model_path: str = "yolo11n.pt",
                 yolo_confidence: float = 0.40,
                 midas_skip_frames: int = 5,
                 frame_size: tuple = (640, 480)):
        """
        Initialize the perception module.
        
        Args:
            yolo_model_path: Path to YOLO model
            yolo_confidence: YOLO confidence threshold
            midas_skip_frames: Frames to skip between MiDaS inferences
            frame_size: Frame size for processing (width, height)
        """
        self.frame_size = frame_size
        
        # Initialize YOLO detector
        self.yolo = YOLODetector(yolo_model_path, yolo_confidence)
        
        # Initialize MiDaS depth estimator
        self.midas = MiDaSDepthEstimator(skip_frames=midas_skip_frames)
        
        # Initialize depth classifier
        self.depth_classifier = DepthClassifier()
        
        # Initialize collision risk analyzer
        self.collision_risk_analyzer = CollisionRiskAnalyzer(
            frame_width=frame_size[0],
            left_threshold=0.33,
            right_threshold=0.67,
            large_bbox_threshold=0.15
        )
        
        print("Perception module initialized successfully!")
    
    def process_frame(self, frame: np.ndarray) -> Dict:
        """
        Process a single frame through the perception pipeline.
        
        Args:
            frame: Input camera frame (BGR format)
            
        Returns:
            Dictionary containing detections, depth map, and processing metadata
        """
        # Resize frame for processing
        frame_resized = cv2.resize(frame, self.frame_size)
        
        # Run YOLO object detection
        detections = self.yolo.detect(frame_resized)
        
        # Run MiDaS depth estimation (non-blocking)
        depth_map = self.midas.estimate_depth(frame_resized)
        
        # Associate depth with detections and analyze collision risk
        enriched_detections = []
        for detection in detections:
            bbox = detection['bbox']
            depth_value = self.midas.get_depth_at_bbox(bbox)
            
            # Classify depth if available
            proximity_category = None
            proximity_description = ""
            if depth_value is not None and depth_map is not None:
                proximity_category, proximity_description = self.depth_classifier.classify(
                    depth_value, depth_map
                )
            
            # Create enriched detection with depth info
            enriched_detection = {
                **detection,
                'depth_value': depth_value,
                'proximity_category': proximity_category,
                'proximity_description': proximity_description
            }
            
            # Analyze collision risk
            collision_risk_analysis = self.collision_risk_analyzer.analyze_detection(
                enriched_detection
            )
            
            # Add collision risk to detection
            enriched_detection['collision_risk'] = collision_risk_analysis['collision_risk']
            enriched_detection['horizontal_position'] = collision_risk_analysis['horizontal_position']
            
            enriched_detections.append(enriched_detection)
        
        # Get risk summary for the frame
        risk_summary = self.collision_risk_analyzer.get_risk_summary(enriched_detections)
        
        return {
            'frame': frame_resized,
            'detections': enriched_detections,
            'depth_map': depth_map,
            'normalized_depth_map': self.midas.get_normalized_depth_map(),
            'risk_summary': risk_summary
        }
    
    def visualize_results(self, results: Dict, show_depth: bool = True) -> np.ndarray:
        """
        Create visualization of perception results.
        
        Args:
            results: Results dictionary from process_frame
            show_depth: Whether to show depth map visualization
            
        Returns:
            Visualization frame
        """
        frame = results['frame'].copy()
        detections = results['detections']
        risk_summary = results.get('risk_summary', {})
        
        # Draw detections with depth and collision risk information
        for detection in detections:
            bbox = detection['bbox']
            class_name = detection['class_name']
            confidence = detection['confidence']
            depth_value = detection['depth_value']
            proximity_category = detection['proximity_category']
            collision_risk = detection.get('collision_risk')
            horizontal_position = detection.get('horizontal_position')
            
            # Get color based on collision risk (priority over proximity)
            if collision_risk:
                risk_color = self._get_risk_color(collision_risk)
                color = risk_color
            elif proximity_category:
                color = self.depth_classifier.get_category_color(proximity_category)
            else:
                color = (0, 255, 0)  # Green for no info
            
            # Draw bounding box
            x1, y1, x2, y2 = bbox
            cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)
            
            # Create label with object info
            label = f"{class_name} ({confidence:.2f})"
            
            # Add horizontal position
            if horizontal_position:
                label += f" | {horizontal_position.value}"
            
            # Add proximity classification if available
            if proximity_category:
                label += f" | {proximity_category.value}"
            
            # Add collision risk if available
            if collision_risk:
                label += f" | {collision_risk.value}"
            
            # Draw label
            label_size, _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.5, 2)
            cv2.rectangle(frame, (x1, y1 - label_size[1] - 10), 
                         (x1 + label_size[0], y1), color, -1)
            cv2.putText(frame, label, (x1, y1 - 5),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 0), 2)
        
        # Add info text with risk summary
        objects_text = f"Objects: {len(detections)}"
        high_risk_text = f"High Risk: {risk_summary.get('high_risk_count', 0)}"
        medium_risk_text = f"Medium Risk: {risk_summary.get('medium_risk_count', 0)}"
        low_risk_text = f"Low Risk: {risk_summary.get('low_risk_count', 0)}"
        
        cv2.putText(frame, objects_text, (10, 30),
                   cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
        cv2.putText(frame, high_risk_text, (10, 60),
                   cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 255), 2)
        cv2.putText(frame, medium_risk_text, (10, 85),
                   cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 165, 255), 2)
        cv2.putText(frame, low_risk_text, (10, 110),
                   cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 2)
        cv2.putText(frame, "Press Q to quit", (10, 140),
                   cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)
        
        return frame
    
    def _get_risk_color(self, collision_risk) -> tuple:
        """Get color for collision risk level."""
        from collision_risk import CollisionRisk
        colors = {
            CollisionRisk.HIGH: (0, 0, 255),      # Red
            CollisionRisk.MEDIUM: (0, 165, 255),   # Orange
            CollisionRisk.LOW: (0, 255, 255)       # Yellow
        }
        return colors.get(collision_risk, (255, 255, 255))
    
    def run_camera(self, camera_index: int = 0):
        """
        Run the perception module with camera input.
        
        Args:
            camera_index: Camera device index
        """
        # Initialize camera
        cap = cv2.VideoCapture(camera_index)
        
        if not cap.isOpened():
            print("Error: Could not open webcam.")
            return
        
        print("Camera started. Press Q to quit.")
        
        try:
            while True:
                # Read frame
                success, frame = cap.read()
                if not success:
                    print("Could not read frame.")
                    break
                
                # Process frame
                results = self.process_frame(frame)
                
                # Create visualization
                vis_frame = self.visualize_results(results)
                
                # Display camera feed
                cv2.imshow("AI Navigation Assistant", vis_frame)
                
                # Display depth map if available
                if results['normalized_depth_map'] is not None:
                    depth_colormap = cv2.applyColorMap(
                        results['normalized_depth_map'],
                        cv2.COLORMAP_MAGMA
                    )
                    cv2.imshow("Depth Map", depth_colormap)
                
                # Print risk summary periodically
                if results.get('risk_summary'):
                    risk_summary = results['risk_summary']
                    if risk_summary.get('high_risk_count', 0) > 0:
                        print(f"High risk objects: {risk_summary['high_risk_count']}")
                
                # Check for quit key (non-blocking)
                key = cv2.waitKey(1) & 0xFF
                if key == ord('q'):
                    print("Quit requested by user.")
                    break
                
        except KeyboardInterrupt:
            print("\nInterrupted by user.")
        finally:
            # Cleanup
            cap.release()
            cv2.destroyAllWindows()
            print("Camera stopped.")


def main():
    """Main entry point for the perception module."""
    print("Initializing AI Navigation Assistant Perception Module...")
    print("=" * 60)
    print("Note: MiDaS provides relative depth, not metric distance.")
    print("Depth values are normalized to scene percentiles.")
    print("Collision risk analysis based on position, size, and depth.")
    print("=" * 60)
    
    # Create perception module
    perception = PerceptionModule(
        yolo_model_path="yolo11n.pt",
        yolo_confidence=0.40,
        midas_skip_frames=5,  # Process depth every 5th frame for CPU efficiency
        frame_size=(640, 480)
    )
    
    # Run camera
    perception.run_camera(camera_index=0)


if __name__ == "__main__":
    main()
