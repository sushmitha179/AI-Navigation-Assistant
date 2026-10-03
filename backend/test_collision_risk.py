"""
Unit tests for collision risk analysis module.
Tests use synthetic detections to verify risk analysis logic.
"""
import unittest
from collision_risk import CollisionRiskAnalyzer, HorizontalPosition, CollisionRisk
from depth_classifier import ProximityCategory


class TestCollisionRiskAnalyzer(unittest.TestCase):
    """Test cases for CollisionRiskAnalyzer."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.analyzer = CollisionRiskAnalyzer(
            frame_width=640,
            left_threshold=0.33,
            right_threshold=0.67,
            large_bbox_threshold=0.15
        )
    
    def create_detection(self, class_name: str, bbox: tuple, 
                        proximity_category: ProximityCategory, confidence: float = 0.8):
        """Helper method to create synthetic detection."""
        return {
            'class_name': class_name,
            'bbox': bbox,
            'proximity_category': proximity_category,
            'confidence': confidence
        }
    
    def test_horizontal_position_calculation(self):
        """Test horizontal position calculation from bounding boxes."""
        # LEFT position (center_x < 33% of frame width)
        left_bbox = (50, 100, 150, 200)  # center_x = 100
        result = self.analyzer.analyze_detection(
            self.create_detection("person", left_bbox, ProximityCategory.CLOSE)
        )
        self.assertEqual(result['horizontal_position'], HorizontalPosition.LEFT)
        
        # CENTER position (33% < center_x < 67%)
        center_bbox = (250, 100, 350, 200)  # center_x = 300
        result = self.analyzer.analyze_detection(
            self.create_detection("person", center_bbox, ProximityCategory.CLOSE)
        )
        self.assertEqual(result['horizontal_position'], HorizontalPosition.CENTER)
        
        # RIGHT position (center_x > 67%)
        right_bbox = (500, 100, 600, 200)  # center_x = 550
        result = self.analyzer.analyze_detection(
            self.create_detection("person", right_bbox, ProximityCategory.CLOSE)
        )
        self.assertEqual(result['horizontal_position'], HorizontalPosition.RIGHT)
    
    def test_bbox_area_calculation(self):
        """Test bounding box area calculation."""
        # Small bbox
        small_bbox = (100, 100, 150, 150)  # 50x50 = 2500 pixels
        result = self.analyzer.analyze_detection(
            self.create_detection("person", small_bbox, ProximityCategory.CLOSE)
        )
        self.assertEqual(result['bbox_area'], 2500)
        self.assertFalse(result['is_large_bbox'])
        
        # Large bbox (assuming threshold 0.15 of 640x480 = 46080 pixels)
        large_bbox = (100, 100, 400, 400)  # 300x300 = 90000 pixels
        result = self.analyzer.analyze_detection(
            self.create_detection("person", large_bbox, ProximityCategory.CLOSE)
        )
        self.assertEqual(result['bbox_area'], 90000)
        self.assertTrue(result['is_large_bbox'])
    
    def test_very_close_risk_rules(self):
        """Test collision risk rules for VERY CLOSE objects."""
        # VERY CLOSE + CENTER = HIGH risk
        center_bbox = (250, 100, 350, 200)
        result = self.analyzer.analyze_detection(
            self.create_detection("person", center_bbox, ProximityCategory.VERY_CLOSE)
        )
        self.assertEqual(result['collision_risk'], CollisionRisk.HIGH)
        
        # VERY CLOSE + LEFT = MEDIUM risk
        left_bbox = (50, 100, 150, 200)
        result = self.analyzer.analyze_detection(
            self.create_detection("person", left_bbox, ProximityCategory.VERY_CLOSE)
        )
        self.assertEqual(result['collision_risk'], CollisionRisk.MEDIUM)
        
        # VERY CLOSE + RIGHT = MEDIUM risk
        right_bbox = (500, 100, 600, 200)
        result = self.analyzer.analyze_detection(
            self.create_detection("person", right_bbox, ProximityCategory.VERY_CLOSE)
        )
        self.assertEqual(result['collision_risk'], CollisionRisk.MEDIUM)
    
    def test_close_risk_rules(self):
        """Test collision risk rules for CLOSE objects."""
        # CLOSE + CENTER + large bbox = HIGH risk
        # Need bbox area >= 46080 pixels (0.15 of 640x480)
        large_center_bbox = (150, 50, 450, 400)  # 300x350 = 105000 pixels (large)
        result = self.analyzer.analyze_detection(
            self.create_detection("person", large_center_bbox, ProximityCategory.CLOSE)
        )
        self.assertEqual(result['collision_risk'], CollisionRisk.HIGH)
        
        # CLOSE + CENTER + small bbox = MEDIUM risk
        small_center_bbox = (300, 100, 350, 150)  # 50x50 = 2500 pixels (small)
        result = self.analyzer.analyze_detection(
            self.create_detection("person", small_center_bbox, ProximityCategory.CLOSE)
        )
        self.assertEqual(result['collision_risk'], CollisionRisk.MEDIUM)
        
        # CLOSE + LEFT = MEDIUM risk
        left_bbox = (50, 100, 150, 200)
        result = self.analyzer.analyze_detection(
            self.create_detection("person", left_bbox, ProximityCategory.CLOSE)
        )
        self.assertEqual(result['collision_risk'], CollisionRisk.MEDIUM)
    
    def test_medium_risk_rules(self):
        """Test collision risk rules for MEDIUM distance objects."""
        # MEDIUM + CENTER + large bbox = MEDIUM risk
        # Need bbox area >= 46080 pixels
        large_center_bbox = (150, 50, 450, 400)  # 300x350 = 105000 pixels (large)
        result = self.analyzer.analyze_detection(
            self.create_detection("person", large_center_bbox, ProximityCategory.MEDIUM)
        )
        self.assertEqual(result['collision_risk'], CollisionRisk.MEDIUM)
        
        # MEDIUM + CENTER + small bbox = LOW risk
        small_center_bbox = (300, 100, 350, 150)  # 50x50 = 2500 pixels (small)
        result = self.analyzer.analyze_detection(
            self.create_detection("person", small_center_bbox, ProximityCategory.MEDIUM)
        )
        self.assertEqual(result['collision_risk'], CollisionRisk.LOW)
        
        # MEDIUM + LEFT = LOW risk
        left_bbox = (50, 100, 150, 200)
        result = self.analyzer.analyze_detection(
            self.create_detection("person", left_bbox, ProximityCategory.MEDIUM)
        )
        self.assertEqual(result['collision_risk'], CollisionRisk.LOW)
    
    def test_far_risk_rules(self):
        """Test collision risk rules for FAR objects."""
        # FAR + CENTER = LOW risk (regardless of size)
        center_bbox = (250, 100, 350, 200)
        result = self.analyzer.analyze_detection(
            self.create_detection("person", center_bbox, ProximityCategory.FAR)
        )
        self.assertEqual(result['collision_risk'], CollisionRisk.LOW)
        
        # FAR + LEFT = LOW risk
        left_bbox = (50, 100, 150, 200)
        result = self.analyzer.analyze_detection(
            self.create_detection("person", left_bbox, ProximityCategory.FAR)
        )
        self.assertEqual(result['collision_risk'], CollisionRisk.LOW)
        
        # FAR + RIGHT = LOW risk
        right_bbox = (500, 100, 600, 200)
        result = self.analyzer.analyze_detection(
            self.create_detection("person", right_bbox, ProximityCategory.FAR)
        )
        self.assertEqual(result['collision_risk'], CollisionRisk.LOW)
    
    def test_unknown_proximity(self):
        """Test handling of unknown proximity categories."""
        bbox = (250, 100, 350, 200)
        result = self.analyzer.analyze_detection(
            self.create_detection("person", bbox, None)
        )
        # Unknown depth should be conservative (MEDIUM risk, not LOW)
        self.assertEqual(result['collision_risk'], CollisionRisk.MEDIUM)
        self.assertEqual(result['proximity_category'], "UNKNOWN")
    
    def test_batch_analysis(self):
        """Test batch analysis of multiple detections."""
        detections = [
            self.create_detection("person", (250, 100, 350, 200), ProximityCategory.VERY_CLOSE),
            self.create_detection("car", (50, 100, 150, 200), ProximityCategory.CLOSE),
            self.create_detection("chair", (500, 100, 600, 200), ProximityCategory.FAR)
        ]
        
        results = self.analyzer.analyze_batch(detections)
        
        self.assertEqual(len(results), 3)
        self.assertEqual(results[0]['collision_risk'], CollisionRisk.HIGH)
        self.assertEqual(results[1]['collision_risk'], CollisionRisk.MEDIUM)
        self.assertEqual(results[2]['collision_risk'], CollisionRisk.LOW)
    
    def test_high_risk_filtering(self):
        """Test filtering high-risk objects."""
        detections = [
            self.create_detection("person", (250, 100, 350, 200), ProximityCategory.VERY_CLOSE),
            self.create_detection("car", (50, 100, 150, 200), ProximityCategory.CLOSE),
            self.create_detection("chair", (500, 100, 600, 200), ProximityCategory.FAR)
        ]
        
        high_risk = self.analyzer.get_high_risk_objects(detections)
        
        self.assertEqual(len(high_risk), 1)
        self.assertEqual(high_risk[0]['object_name'], "person")
        self.assertEqual(high_risk[0]['collision_risk'], CollisionRisk.HIGH)
    
    def test_risk_summary(self):
        """Test risk summary generation."""
        detections = [
            self.create_detection("person", (250, 100, 350, 200), ProximityCategory.VERY_CLOSE),
            self.create_detection("car", (50, 100, 150, 200), ProximityCategory.CLOSE),
            self.create_detection("chair", (500, 100, 600, 200), ProximityCategory.FAR),
            self.create_detection("table", (200, 100, 400, 300), ProximityCategory.CLOSE)
        ]
        
        summary = self.analyzer.get_risk_summary(detections)
        
        self.assertEqual(summary['total_objects'], 4)
        self.assertEqual(summary['high_risk_count'], 1)
        self.assertEqual(summary['medium_risk_count'], 2)
        self.assertEqual(summary['low_risk_count'], 1)
        
        # Check risk distribution
        self.assertEqual(summary['risk_distribution']['HIGH'], 1)
        self.assertEqual(summary['risk_distribution']['MEDIUM'], 2)
        self.assertEqual(summary['risk_distribution']['LOW'], 1)
    
    def test_display_formatting(self):
        """Test display formatting of risk analysis."""
        detection = self.create_detection("person", (250, 100, 350, 200), ProximityCategory.VERY_CLOSE)
        result = self.analyzer.analyze_detection(detection)
        
        formatted = self.analyzer.format_for_display(result)
        
        self.assertIn("person", formatted)
        self.assertIn("CENTER", formatted)
        self.assertIn("VERY CLOSE", formatted)
        self.assertIn("HIGH", formatted)
        
        # Check format: "object | position | proximity | risk"
        parts = formatted.split(" | ")
        self.assertEqual(len(parts), 4)
    
    def test_edge_case_boundaries(self):
        """Test edge cases at position boundaries."""
        # Test exact boundary at left_threshold (33% of 640 = 211.2)
        boundary_left = (200, 100, 222, 200)  # center_x = 211
        result = self.analyzer.analyze_detection(
            self.create_detection("person", boundary_left, ProximityCategory.CLOSE)
        )
        # Should be CENTER since 211 > 211.2? Actually 211 < 211.2, so LEFT
        self.assertEqual(result['horizontal_position'], HorizontalPosition.LEFT)
        
        # Test exact boundary at right_threshold (67% of 640 = 428.8)
        boundary_right = (420, 100, 437, 200)  # center_x = 428.5
        result = self.analyzer.analyze_detection(
            self.create_detection("person", boundary_right, ProximityCategory.CLOSE)
        )
        # Should be CENTER since 428.5 < 428.8
        self.assertEqual(result['horizontal_position'], HorizontalPosition.CENTER)
    
    def test_different_object_types(self):
        """Test risk analysis with different object types."""
        objects = ["person", "car", "bicycle", "dog", "chair"]
        
        for obj_type in objects:
            detection = self.create_detection(obj_type, (250, 100, 350, 200), ProximityCategory.VERY_CLOSE)
            result = self.analyzer.analyze_detection(detection)
            self.assertEqual(result['object_name'], obj_type)
            self.assertEqual(result['collision_risk'], CollisionRisk.HIGH)


class TestRealWorldScenarios(unittest.TestCase):
    """Test real-world navigation scenarios."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.analyzer = CollisionRiskAnalyzer(frame_width=640)
    
    def test_pedestrian_crossing_scenario(self):
        """Test scenario: pedestrian crossing in front."""
        detections = [
            {'class_name': 'person', 'bbox': (280, 150, 360, 350), 
             'proximity_category': ProximityCategory.VERY_CLOSE, 'confidence': 0.9}
        ]
        
        results = self.analyzer.analyze_batch(detections)
        self.assertEqual(results[0]['collision_risk'], CollisionRisk.HIGH)
        self.assertEqual(results[0]['horizontal_position'], HorizontalPosition.CENTER)
    
    def test_parked_car_scenario(self):
        """Test scenario: parked car on the side."""
        detections = [
            {'class_name': 'car', 'bbox': (20, 100, 200, 300), 
             'proximity_category': ProximityCategory.CLOSE, 'confidence': 0.85}
        ]
        
        results = self.analyzer.analyze_batch(detections)
        self.assertEqual(results[0]['collision_risk'], CollisionRisk.MEDIUM)
        self.assertEqual(results[0]['horizontal_position'], HorizontalPosition.LEFT)
    
    def test_multiple_objects_scenario(self):
        """Test scenario: multiple objects with different risks."""
        detections = [
            {'class_name': 'person', 'bbox': (280, 150, 360, 350), 
             'proximity_category': ProximityCategory.VERY_CLOSE, 'confidence': 0.9},
            {'class_name': 'car', 'bbox': (450, 100, 620, 280), 
             'proximity_category': ProximityCategory.FAR, 'confidence': 0.8},
            {'class_name': 'chair', 'bbox': (50, 200, 150, 350), 
             'proximity_category': ProximityCategory.MEDIUM, 'confidence': 0.7}
        ]
        
        summary = self.analyzer.get_risk_summary(detections)
        self.assertEqual(summary['high_risk_count'], 1)  # person VERY CLOSE + CENTER
        self.assertEqual(summary['medium_risk_count'], 0)  # chair MEDIUM + LEFT = LOW
        self.assertEqual(summary['low_risk_count'], 2)  # car FAR, chair MEDIUM + LEFT


def run_tests():
    """Run all tests and display results."""
    print("=" * 70)
    print("COLLISION RISK ANALYSIS MODULE - UNIT TESTS")
    print("=" * 70)
    
    # Create test suite
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    
    # Add all test cases
    suite.addTests(loader.loadTestsFromTestCase(TestCollisionRiskAnalyzer))
    suite.addTests(loader.loadTestsFromTestCase(TestRealWorldScenarios))
    
    # Run tests
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    # Print summary
    print("\n" + "=" * 70)
    print("TEST SUMMARY")
    print("=" * 70)
    print(f"Tests run: {result.testsRun}")
    print(f"Successes: {result.testsRun - len(result.failures) - len(result.errors)}")
    print(f"Failures: {len(result.failures)}")
    print(f"Errors: {len(result.errors)}")
    
    if result.wasSuccessful():
        print("\n[OK] All tests passed successfully!")
    else:
        print("\n[FAIL] Some tests failed. Please review the output above.")
    
    print("=" * 70)
    
    return result.wasSuccessful()


if __name__ == "__main__":
    success = run_tests()
    exit(0 if success else 1)
