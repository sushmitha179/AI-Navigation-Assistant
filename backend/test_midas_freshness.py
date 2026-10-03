import threading
import unittest

import numpy as np

from midas_depth import MiDaSDepthEstimator


class TestMiDaSDepthFreshness(unittest.TestCase):
    def test_depth_map_expires_after_skip_frame_window(self):
        estimator = MiDaSDepthEstimator.__new__(MiDaSDepthEstimator)
        estimator.depth_map_lock = threading.Lock()
        estimator.depth_map = np.full((4, 4), 100.0)
        estimator.depth_map_frame_count = 10
        estimator.frame_count = 15
        estimator.skip_frames = 5

        self.assertIsNotNone(
            estimator._get_latest_depth(max_age_frames=estimator.skip_frames)
        )
        self.assertIsNotNone(estimator.get_depth_at_bbox((0, 0, 2, 2)))

        estimator.frame_count = 16
        self.assertIsNone(
            estimator._get_latest_depth(max_age_frames=estimator.skip_frames)
        )
        self.assertIsNone(estimator.get_depth_at_bbox((0, 0, 2, 2)))


if __name__ == "__main__":
    unittest.main()