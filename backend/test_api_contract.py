"""
Test API contract between backend and Flutter.
Verifies that the JSON response structure matches NavigationModel parsing.
"""
import json
import unittest
from api_server import analyze_image, _json_value
from navigation_engine import NavigationDecisionEngine
from collision_risk import CollisionRisk, HorizontalPosition
from depth_classifier import ProximityCategory


class TestAPIContract(unittest.TestCase):
    """Test API response structure matches Flutter expectations."""

    def test_response_structure_complete(self):
        """Test that a complete response has all required fields."""
        # Simulate a complete detection result
        detection = {
            'class_name': 'person',
            'bbox': (100, 100, 200, 200),
            'confidence': 0.9,
            'proximity_category': ProximityCategory.CLOSE,
            'collision_risk': CollisionRisk.MEDIUM,
            'horizontal_position': HorizontalPosition.CENTER,
            'depth_value': 500.0
        }

        decision = NavigationDecisionEngine().decide([detection])
        # Apply the same filtering as api_server.py line 50-53
        filtered_detection = {key: value for key, value in detection.items() if key not in {"depth_value"}}
        result = _json_value({**decision, "detections": [_json_value(filtered_detection)]})

        # Verify required fields exist
        self.assertIn('action', result)
        self.assertIn('reason', result)
        self.assertIn('priority', result)
        self.assertIn('detections', result)

        # Verify field types
        self.assertIsInstance(result['action'], str)
        self.assertIsInstance(result['reason'], str)
        self.assertIsInstance(result['priority'], str)
        self.assertIsInstance(result['detections'], list)

        # Verify detection structure
        if len(result['detections']) > 0:
            det = result['detections'][0]
            self.assertIn('class_name', det)
            self.assertIn('bbox', det)
            self.assertIn('confidence', det)
            # depth_value should be filtered out (per api_server.py line 52)
            self.assertNotIn('depth_value', det)

    def test_response_empty_detections(self):
        """Test response with no detections."""
        decision = NavigationDecisionEngine().decide([])
        result = _json_value({**decision, "detections": []})

        self.assertEqual(result['action'], 'CONTINUE')
        self.assertEqual(result['detections'], [])
        self.assertIn('reason', result)

    def test_response_unknown_depth(self):
        """Test response when depth is unknown (None)."""
        detection = {
            'class_name': 'person',
            'bbox': (100, 100, 200, 200),
            'confidence': 0.9,
            'proximity_category': None,  # Unknown depth
            'collision_risk': CollisionRisk.MEDIUM,  # Conservative
            'horizontal_position': HorizontalPosition.CENTER,
            'depth_value': None
        }

        decision = NavigationDecisionEngine().decide([detection])
        result = _json_value({**decision, "detections": [_json_value(detection)]})

        # Verify unknown depth is represented as null or "UNKNOWN"
        det = result['detections'][0]
        proximity_value = det.get('proximity_category')
        # Should be None or "UNKNOWN" string
        self.assertTrue(proximity_value is None or proximity_value == "UNKNOWN")

    def test_enum_conversion(self):
        """Test that enum values are converted to strings."""
        enum_values = [
            (CollisionRisk.HIGH, "HIGH"),
            (CollisionRisk.MEDIUM, "MEDIUM"),
            (CollisionRisk.LOW, "LOW"),
            (HorizontalPosition.LEFT, "LEFT"),
            (HorizontalPosition.CENTER, "CENTER"),
            (HorizontalPosition.RIGHT, "RIGHT"),
            (ProximityCategory.VERY_CLOSE, "VERY CLOSE"),
            (ProximityCategory.CLOSE, "CLOSE"),
            (ProximityCategory.MEDIUM, "MEDIUM"),
            (ProximityCategory.FAR, "FAR"),
        ]

        for enum_val, expected_str in enum_values:
            result = _json_value(enum_val)
            self.assertEqual(result, expected_str)

    def test_failure_never_continues_unsafe(self):
        """Test that navigation failures never return false CONTINUE."""
        # Test various failure scenarios

        # Empty detections - CONTINUE is appropriate here
        decision = NavigationDecisionEngine().decide([])
        self.assertEqual(decision['action'], 'CONTINUE')

        # Single detection with unknown depth (MEDIUM risk)
        detection = {
            'class_name': 'person',
            'bbox': (100, 100, 200, 200),
            'confidence': 0.9,
            'proximity_category': None,
            'collision_risk': CollisionRisk.MEDIUM,
            'horizontal_position': HorizontalPosition.CENTER,
        }
        decision = NavigationDecisionEngine().decide([detection])
        # With MEDIUM risk and CENTER position, should not be CONTINUE
        self.assertNotEqual(decision['action'], 'CONTINUE')

        # HIGH risk in CENTER - should be STOP
        detection['collision_risk'] = CollisionRisk.HIGH
        decision = NavigationDecisionEngine().decide([detection])
        self.assertEqual(decision['action'], 'STOP')

    def test_json_serialization(self):
        """Test that the response can be serialized to JSON."""
        detection = {
            'class_name': 'person',
            'bbox': (100, 100, 200, 200),
            'confidence': 0.9,
            'proximity_category': ProximityCategory.CLOSE,
            'collision_risk': CollisionRisk.MEDIUM,
            'horizontal_position': HorizontalPosition.CENTER,
        }

        decision = NavigationDecisionEngine().decide([detection])
        result = _json_value({**decision, "detections": [_json_value(detection)]})

        # Should not raise exception
        json_str = json.dumps(result)
        self.assertIsInstance(json_str, str)

        # Should be deserializable
        parsed = json.loads(json_str)
        self.assertEqual(parsed['action'], result['action'])


def run_tests():
    """Run all tests."""
    print("=" * 70)
    print("API CONTRACT VERIFICATION")
    print("=" * 70)

    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    suite.addTests(loader.loadTestsFromTestCase(TestAPIContract))

    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)

    print("\n" + "=" * 70)
    print(f"Tests run: {result.testsRun}")
    print(f"Successes: {result.testsRun - len(result.failures) - len(result.errors)}")
    print(f"Failures: {len(result.failures)}")
    print(f"Errors: {len(result.errors)}")
    print("=" * 70)

    return result.wasSuccessful()


if __name__ == "__main__":
    success = run_tests()
    exit(0 if success else 1)
