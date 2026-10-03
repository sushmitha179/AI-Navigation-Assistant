"""
Unit tests for depth classifier module.
Tests verify inverse depth polarity (higher values = closer objects).
"""
import unittest
import numpy as np
from depth_classifier import DepthClassifier, ProximityCategory


class TestDepthClassifier(unittest.TestCase):
    """Test cases for DepthClassifier."""

    def setUp(self):
        """Set up test fixtures."""
        self.classifier = DepthClassifier()

    def test_adaptive_classification_inverse_depth(self):
        """Test that adaptive classification uses inverse depth (higher = closer)."""
        # Create a synthetic depth map with values 0-100
        depth_map = np.random.rand(480, 640) * 100

        # Calculate percentiles
        p25 = np.percentile(depth_map, 25)
        p50 = np.percentile(depth_map, 50)
        p75 = np.percentile(depth_map, 75)

        # Test HIGH depth value (should be VERY CLOSE with inverse depth)
        category, desc = self.classifier._classify_adaptive(p75 + 10, depth_map)
        self.assertEqual(category, ProximityCategory.VERY_CLOSE)

        # Test MEDIUM-HIGH depth value (should be CLOSE)
        category, desc = self.classifier._classify_adaptive(p50 + 5, depth_map)
        self.assertEqual(category, ProximityCategory.CLOSE)

        # Test MEDIUM depth value (should be MEDIUM)
        category, desc = self.classifier._classify_adaptive(p25 + 5, depth_map)
        self.assertEqual(category, ProximityCategory.MEDIUM)

        # Test LOW depth value (should be FAR)
        category, desc = self.classifier._classify_adaptive(p25 - 5, depth_map)
        self.assertEqual(category, ProximityCategory.FAR)

    def test_fixed_classification_inverse_depth(self):
        """Test that fixed classification uses inverse depth (higher = closer)."""
        # Clear history to force fixed classification
        self.classifier.depth_history = []

        # Test HIGH value (should be VERY CLOSE)
        category, desc = self.classifier._classify_fixed(800)
        self.assertEqual(category, ProximityCategory.VERY_CLOSE)

        # Test MEDIUM-HIGH value (should be CLOSE)
        category, desc = self.classifier._classify_fixed(500)
        self.assertEqual(category, ProximityCategory.CLOSE)

        # Test MEDIUM value (should be MEDIUM)
        category, desc = self.classifier._classify_fixed(300)
        self.assertEqual(category, ProximityCategory.MEDIUM)

        # Test LOW value (should be FAR)
        category, desc = self.classifier._classify_fixed(100)
        self.assertEqual(category, ProximityCategory.FAR)

    def test_classify_with_depth_map(self):
        """Test classify method with depth map (adaptive mode)."""
        depth_map = np.random.rand(480, 640) * 100
        p75 = np.percentile(depth_map, 75)

        category, desc = self.classifier.classify(p75 + 10, depth_map)
        self.assertEqual(category, ProximityCategory.VERY_CLOSE)
        self.assertIn("very close", desc.lower())

    def test_classify_without_depth_map(self):
        """Test classify method without depth map (fixed mode)."""
        # Clear history to ensure fixed mode
        self.classifier.depth_history = []

        category, desc = self.classifier.classify(800, None)
        self.assertEqual(category, ProximityCategory.VERY_CLOSE)
        self.assertIn("very close", desc.lower())

    def test_history_management(self):
        """Test depth history management."""
        initial_size = len(self.classifier.depth_history)

        # Add some values
        for i in range(5):
            self.classifier.classify(i * 100, None)

        # History should have grown
        self.assertGreater(len(self.classifier.depth_history), initial_size)

        # Fill history beyond max size
        for i in range(200):
            self.classifier.classify(i, None)

        # History should be capped at max_history_size
        self.assertLessEqual(len(self.classifier.depth_history), self.classifier.max_history_size)

    def test_reset_history(self):
        """Test history reset functionality."""
        # Add some values
        for i in range(10):
            self.classifier.classify(i * 100, None)

        self.assertGreater(len(self.classifier.depth_history), 0)

        # Reset
        self.classifier.reset_history()

        # History should be empty
        self.assertEqual(len(self.classifier.depth_history), 0)

    def test_category_colors(self):
        """Test category color mapping."""
        colors = {
            ProximityCategory.VERY_CLOSE: (0, 0, 255),    # Red
            ProximityCategory.CLOSE: (0, 165, 255),       # Orange
            ProximityCategory.MEDIUM: (0, 255, 255),      # Yellow
            ProximityCategory.FAR: (255, 255, 255)        # White
        }

        for category, expected_color in colors.items():
            color = self.classifier.get_category_color(category)
            self.assertEqual(color, expected_color)


def run_tests():
    """Run all tests and display results."""
    print("=" * 70)
    print("DEPTH CLASSIFIER MODULE - UNIT TESTS")
    print("=" * 70)

    # Create test suite
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()

    # Add all test cases
    suite.addTests(loader.loadTestsFromTestCase(TestDepthClassifier))

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
