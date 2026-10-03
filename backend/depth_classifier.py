import numpy as np
from typing import Optional, Tuple
from enum import Enum


class ProximityCategory(Enum):
    """Relative proximity categories for depth classification."""
    VERY_CLOSE = "VERY CLOSE"
    CLOSE = "CLOSE"
    MEDIUM = "MEDIUM"
    FAR = "FAR"


class DepthClassifier:
    """Classifies MiDaS depth values into relative proximity categories."""
    
    def __init__(self, 
                 very_close_threshold: float = 0.25,
                 close_threshold: float = 0.50,
                 medium_threshold: float = 0.75):
        """
        Initialize depth classifier.
        
        Args:
            very_close_threshold: Percentile threshold for VERY CLOSE (0-1)
            close_threshold: Percentile threshold for CLOSE (0-1)
            medium_threshold: Percentile threshold for MEDIUM (0-1)
            
        Note:
            These are percentile thresholds, not metric distances.
            MiDaS provides relative depth, not absolute distance in meters.
        """
        self.very_close_threshold = very_close_threshold
        self.close_threshold = close_threshold
        self.medium_threshold = medium_threshold
        
        # Store depth statistics for adaptive normalization
        self.depth_history = []
        self.max_history_size = 100
    
    def classify(self, depth_value: float, depth_map: Optional[np.ndarray] = None) -> Tuple[ProximityCategory, str]:
        """
        Classify a depth value into a proximity category.
        
        Args:
            depth_value: Raw MiDaS depth value
            depth_map: Full depth map for adaptive normalization (optional)
            
        Returns:
            Tuple of (ProximityCategory, description string)
        """
        if depth_map is not None:
            # Use adaptive normalization based on current scene
            return self._classify_adaptive(depth_value, depth_map)
        else:
            # Use fixed percentile-based classification
            return self._classify_fixed(depth_value)
    
    def _classify_adaptive(self, depth_value: float, depth_map: np.ndarray) -> Tuple[ProximityCategory, str]:
        """
        Classify using adaptive normalization based on current scene depth distribution.

        This adapts to different scenes by using percentiles of the current depth map.
        Note: MiDaS outputs inverse depth (higher values = closer objects).
        """
        # Calculate percentiles of the current depth map
        p25 = np.percentile(depth_map, 25)
        p50 = np.percentile(depth_map, 50)
        p75 = np.percentile(depth_map, 75)

        # Update depth history for smoothing
        self.depth_history.append(depth_value)
        if len(self.depth_history) > self.max_history_size:
            self.depth_history.pop(0)

        # Classify based on percentiles (inverse depth: higher = closer)
        if depth_value >= p75:
            return ProximityCategory.VERY_CLOSE, "Object is very close (top 25% closest)"
        elif depth_value >= p50:
            return ProximityCategory.CLOSE, "Object is close (top 50% closest)"
        elif depth_value >= p25:
            return ProximityCategory.MEDIUM, "Object is at medium distance"
        else:
            return ProximityCategory.FAR, "Object is far (bottom 25% deepest)"
    
    def _classify_fixed(self, depth_value: float) -> Tuple[ProximityCategory, str]:
        """
        Classify using fixed thresholds (less adaptive, faster).

        Note: This requires knowledge of typical MiDaS value ranges.
        Use adaptive classification when possible.
        Note: MiDaS outputs inverse depth (higher values = closer objects).
        """
        # Update depth history
        self.depth_history.append(depth_value)
        if len(self.depth_history) > self.max_history_size:
            self.depth_history.pop(0)

        if len(self.depth_history) < 10:
            # Not enough data, use fixed ranges
            # Typical MiDaS small values range roughly 0-1000+ (inverse depth)
            if depth_value > 600:
                return ProximityCategory.VERY_CLOSE, "Object is very close"
            elif depth_value > 400:
                return ProximityCategory.CLOSE, "Object is close"
            elif depth_value > 200:
                return ProximityCategory.MEDIUM, "Object is at medium distance"
            else:
                return ProximityCategory.FAR, "Object is far"
        else:
            # Use historical data for adaptive classification (inverse depth)
            depth_array = np.array(self.depth_history)
            p25 = np.percentile(depth_array, 25)
            p50 = np.percentile(depth_array, 50)
            p75 = np.percentile(depth_array, 75)

            if depth_value >= p75:
                return ProximityCategory.VERY_CLOSE, "Object is very close"
            elif depth_value >= p50:
                return ProximityCategory.CLOSE, "Object is close"
            elif depth_value >= p25:
                return ProximityCategory.MEDIUM, "Object is at medium distance"
            else:
                return ProximityCategory.FAR, "Object is far"
    
    def get_category_color(self, category: ProximityCategory) -> Tuple[int, int, int]:
        """
        Get BGR color for visualization of a proximity category.
        
        Args:
            category: Proximity category
            
        Returns:
            BGR color tuple
        """
        colors = {
            ProximityCategory.VERY_CLOSE: (0, 0, 255),    # Red
            ProximityCategory.CLOSE: (0, 165, 255),       # Orange
            ProximityCategory.MEDIUM: (0, 255, 255),      # Yellow
            ProximityCategory.FAR: (255, 255, 255)        # White
        }
        return colors.get(category, (255, 255, 255))
    
    def reset_history(self):
        """Reset depth history (useful when scene changes dramatically)."""
        self.depth_history = []
