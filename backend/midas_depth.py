import torch
import cv2
import numpy as np
import threading
from typing import Optional, Tuple
from queue import Queue


class MiDaSDepthEstimator:
    """MiDaS depth estimation module with non-blocking inference."""
    
    def __init__(self, model_type: str = "MiDaS_small", skip_frames: int = 5):
        """
        Initialize MiDaS depth estimator.
        
        Args:
            model_type: MiDaS model variant (small for CPU efficiency)
            skip_frames: Number of frames to skip between depth estimations
        """
        print("Loading MiDaS...")
        self.model_type = model_type
        self.skip_frames = skip_frames
        
        # Load MiDaS model
        self.midas = torch.hub.load("intel-isl/MiDaS", model_type)
        self.midas.eval()
        
        # Load transforms
        midas_transforms = torch.hub.load("intel-isl/MiDaS", "transforms")
        self.transform = midas_transforms.small_transform
        
        # Depth map storage
        self.depth_map = None
        self.depth_map_lock = threading.Lock()
        
        # Frame processing
        self.frame_count = 0
        self.processing = False
        
        print("MiDaS loaded successfully!")
    
    def estimate_depth(self, frame: np.ndarray) -> Optional[np.ndarray]:
        """
        Estimate depth for a frame (non-blocking).
        
        Args:
            frame: Input image frame (BGR format)
            
        Returns:
            Depth map as numpy array, or None if not ready
        """
        self.frame_count += 1
        
        # Skip frames to reduce CPU load
        if self.frame_count % self.skip_frames != 0:
            return self._get_latest_depth()
        
        # If already processing, skip this frame
        if self.processing:
            return self._get_latest_depth()
        
        # Process depth in background thread
        self.processing = True
        thread = threading.Thread(target=self._process_depth, args=(frame.copy(),))
        thread.daemon = True
        thread.start()
        
        return self._get_latest_depth()
    
    def _process_depth(self, frame: np.ndarray):
        """Process depth estimation in background thread."""
        try:
            # Convert BGR to RGB
            img = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            
            # Apply transform
            input_batch = self.transform(img)
            
            # Run inference
            with torch.no_grad():
                prediction = self.midas(input_batch)
                
                # Resize to original image dimensions
                prediction = torch.nn.functional.interpolate(
                    prediction.unsqueeze(1),
                    size=img.shape[:2],
                    mode="bicubic",
                    align_corners=False
                ).squeeze()
            
            # Convert to numpy and store
            depth_map = prediction.cpu().numpy()
            
            with self.depth_map_lock:
                self.depth_map = depth_map
                
        except Exception as e:
            print(f"Depth estimation error: {e}")
        finally:
            with self.depth_map_lock:
                self.processing = False
    
    def _get_latest_depth(self) -> Optional[np.ndarray]:
        """Get the latest available depth map."""
        with self.depth_map_lock:
            return self.depth_map.copy() if self.depth_map is not None else None
    
    def get_depth_at_bbox(self, bbox: Tuple[int, int, int, int]) -> Optional[float]:
        """
        Get median depth value within a bounding box region.
        
        Args:
            bbox: Bounding box as (x1, y1, x2, y2)
            
        Returns:
            Median depth value in the region, or None if depth map unavailable
        """
        depth_map = self._get_latest_depth()
        if depth_map is None:
            return None
        
        x1, y1, x2, y2 = bbox
        
        # Ensure bbox is within image bounds
        h, w = depth_map.shape
        x1 = max(0, min(x1, w))
        y1 = max(0, min(y1, h))
        x2 = max(0, min(x2, w))
        y2 = max(0, min(y2, h))
        
        if x2 <= x1 or y2 <= y1:
            return None
        
        # Extract depth values in the region
        region_depth = depth_map[y1:y2, x1:x2]
        
        # Return median depth (robust to outliers)
        return float(np.median(region_depth))
    
    def get_normalized_depth_map(self) -> Optional[np.ndarray]:
        """
        Get normalized depth map for visualization.
        
        Returns:
            Normalized depth map as uint8 array, or None if unavailable
        """
        depth_map = self._get_latest_depth()
        if depth_map is None:
            return None
        
        # Normalize to 0-255 range
        depth_normalized = cv2.normalize(
            depth_map,
            None,
            0,
            255,
            cv2.NORM_MINMAX
        )
        
        return depth_normalized.astype(np.uint8)
