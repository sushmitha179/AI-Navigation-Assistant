from enum import Enum
from typing import Dict, Tuple, Optional
import numpy as np


class HorizontalPosition(Enum):
    """Horizontal position of an object in the camera frame."""
    LEFT = "LEFT"
    CENTER = "CENTER"
    RIGHT = "RIGHT"


class CollisionRisk(Enum):
    """Collision risk level for navigation safety."""
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"


class CollisionRiskAnalyzer:
    """Analyzes collision risk based on object position, size, and relative depth."""
    
    def __init__(self, 
                 frame_width: int = 640,
                 left_threshold: float = 0.33,
                 right_threshold: float = 0.67,
                 large_bbox_threshold: float = 0.15):
        """
        Initialize collision risk analyzer.
        
        Args:
            frame_width: Width of the camera frame for position calculation
            left_threshold: Percentage of frame width for LEFT region (0-1)
            right_threshold: Percentage of frame width for RIGHT region (0-1)
            large_bbox_threshold: Minimum bbox area as percentage of frame (0-1)
        """
        self.frame_width = frame_width
        self.left_threshold = left_threshold
        self.right_threshold = right_threshold
        self.large_bbox_threshold = large_bbox_threshold
        
        # Frame area for bbox size calculation
        self.frame_area = frame_width * 480  # Assuming 640x480 standard resolution
    
    def analyze_detection(self, detection: Dict) -> Dict:
        """
        Analyze collision risk for a single detection.
        
        Args:
            detection: Detection dictionary containing:
                - class_name: str
                - bbox: tuple (x1, y1, x2, y2)
                - proximity_category: ProximityCategory enum
                - confidence: float
                
        Returns:
            Dictionary with collision risk analysis results
        """
        # Extract detection information
        class_name = detection['class_name']
        bbox = detection['bbox']
        proximity_category = detection['proximity_category']
        
        # Calculate horizontal position
        horizontal_position = self._get_horizontal_position(bbox)
        
        # Calculate bounding box size
        bbox_area = self._get_bbox_area(bbox)
        bbox_size_ratio = bbox_area / self.frame_area
        is_large_bbox = bbox_size_ratio >= self.large_bbox_threshold
        
        # Determine collision risk
        collision_risk = self._determine_collision_risk(
            proximity_category, 
            horizontal_position, 
            is_large_bbox
        )
        
        # Convert proximity category to string for display
        proximity_str = proximity_category.value if proximity_category else "UNKNOWN"
        
        return {
            'object_name': class_name,
            'horizontal_position': horizontal_position,
            'proximity_category': proximity_str,
            'collision_risk': collision_risk,
            'bbox_area': bbox_area,
            'bbox_size_ratio': bbox_size_ratio,
            'is_large_bbox': is_large_bbox
        }
    
    def _get_horizontal_position(self, bbox: Tuple[int, int, int, int]) -> HorizontalPosition:
        """
        Determine horizontal position based on bounding box center.
        
        Args:
            bbox: Bounding box as (x1, y1, x2, y2)
            
        Returns:
            HorizontalPosition enum
        """
        x1, y1, x2, y2 = bbox
        center_x = (x1 + x2) / 2
        
        # Normalize to frame width
        normalized_x = center_x / self.frame_width
        
        if normalized_x < self.left_threshold:
            return HorizontalPosition.LEFT
        elif normalized_x > self.right_threshold:
            return HorizontalPosition.RIGHT
        else:
            return HorizontalPosition.CENTER
    
    def _get_bbox_area(self, bbox: Tuple[int, int, int, int]) -> float:
        """
        Calculate bounding box area.
        
        Args:
            bbox: Bounding box as (x1, y1, x2, y2)
            
        Returns:
            Area in pixels
        """
        x1, y1, x2, y2 = bbox
        width = x2 - x1
        height = y2 - y1
        return width * height
    
    def _determine_collision_risk(self, 
                                proximity_category,
                                horizontal_position: HorizontalPosition,
                                is_large_bbox: bool) -> CollisionRisk:
        """
        Determine collision risk based on depth, position, and size.
        
        Args:
            proximity_category: Relative depth category (enum or string)
            horizontal_position: Horizontal position of object
            is_large_bbox: Whether the bounding box is large
            
        Returns:
            CollisionRisk enum
        """
        # Convert enum to string if needed
        if proximity_category is not None and hasattr(proximity_category, 'value'):
            proximity_str = proximity_category.value
        else:
            proximity_str = str(proximity_category) if proximity_category else None
        
        # Handle unknown proximity - conservative fallback
        if proximity_str is None or proximity_str == "UNKNOWN":
            return CollisionRisk.MEDIUM
        
        # Apply conservative risk rules
        if proximity_str == "VERY CLOSE":
            if horizontal_position == HorizontalPosition.CENTER:
                return CollisionRisk.HIGH
            else:  # LEFT or RIGHT
                return CollisionRisk.MEDIUM
        
        elif proximity_str == "CLOSE":
            if horizontal_position == HorizontalPosition.CENTER:
                # HIGH if large bbox, MEDIUM otherwise
                return CollisionRisk.HIGH if is_large_bbox else CollisionRisk.MEDIUM
            else:  # LEFT or RIGHT
                return CollisionRisk.MEDIUM
        
        elif proximity_str == "MEDIUM":
            if horizontal_position == HorizontalPosition.CENTER:
                # MEDIUM if large bbox, LOW otherwise
                return CollisionRisk.MEDIUM if is_large_bbox else CollisionRisk.LOW
            else:  # LEFT or RIGHT
                return CollisionRisk.LOW
        
        elif proximity_str == "FAR":
            # FAR objects are always low risk
            return CollisionRisk.LOW
        
        # Default to low risk for unknown categories
        return CollisionRisk.LOW
    
    def analyze_batch(self, detections: list) -> list:
        """
        Analyze collision risk for multiple detections.
        
        Args:
            detections: List of detection dictionaries
            
        Returns:
            List of collision risk analysis results
        """
        results = []
        for detection in detections:
            try:
                risk_analysis = self.analyze_detection(detection)
                results.append(risk_analysis)
            except Exception as e:
                print(f"Error analyzing detection: {e}")
                continue
        return results
    
    def get_high_risk_objects(self, detections: list) -> list:
        """
        Filter and return only high-risk objects.
        
        Args:
            detections: List of detection dictionaries
            
        Returns:
            List of high-risk collision analysis results
        """
        all_risks = self.analyze_batch(detections)
        return [risk for risk in all_risks if risk['collision_risk'] == CollisionRisk.HIGH]
    
    def get_risk_summary(self, detections: list) -> Dict:
        """
        Get summary of collision risks in the current frame.
        
        Args:
            detections: List of detection dictionaries
            
        Returns:
            Dictionary with risk summary statistics
        """
        risk_analyses = self.analyze_batch(detections)
        
        risk_counts = {
            CollisionRisk.HIGH: 0,
            CollisionRisk.MEDIUM: 0,
            CollisionRisk.LOW: 0
        }
        
        position_counts = {
            HorizontalPosition.LEFT: 0,
            HorizontalPosition.CENTER: 0,
            HorizontalPosition.RIGHT: 0
        }
        
        for analysis in risk_analyses:
            risk_counts[analysis['collision_risk']] += 1
            position_counts[analysis['horizontal_position']] += 1
        
        return {
            'total_objects': len(risk_analyses),
            'risk_distribution': {risk.value: count for risk, count in risk_counts.items()},
            'position_distribution': {pos.value: count for pos, count in position_counts.items()},
            'high_risk_count': risk_counts[CollisionRisk.HIGH],
            'medium_risk_count': risk_counts[CollisionRisk.MEDIUM],
            'low_risk_count': risk_counts[CollisionRisk.LOW]
        }
    
    def format_for_display(self, risk_analysis: Dict) -> str:
        """
        Format collision risk analysis for display.
        
        Args:
            risk_analysis: Collision risk analysis dictionary
            
        Returns:
            Formatted string for display
        """
        return (f"{risk_analysis['object_name']} | "
                f"{risk_analysis['horizontal_position'].value} | "
                f"{risk_analysis['proximity_category']} | "
                f"{risk_analysis['collision_risk'].value}")
