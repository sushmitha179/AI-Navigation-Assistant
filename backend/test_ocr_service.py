import unittest

import cv2
import numpy as np

from ocr_service import read_sign_image


class FakeOCREngine:
    def __init__(self, results):
        self.results = results

    def __call__(self, image):
        return self.results, [0.01, 0.02, 0.03]


class TestSignboardOCR(unittest.TestCase):
    def setUp(self):
        success, self.image = cv2.imencode(
            ".jpg", np.full((40, 80, 3), 255, dtype=np.uint8)
        )
        self.assertTrue(success)

    def test_extracts_text_and_average_confidence(self):
        engine = FakeOCREngine([
            ([], "EXIT", 0.9),
            ([], "24 HOURS", 0.7),
            ([], "noise", 0.2),
        ])

        result = read_sign_image(self.image.tobytes(), engine)

        self.assertEqual(result["text"], "EXIT 24 HOURS")
        self.assertEqual(result["confidence"], 0.8)
        self.assertEqual(result["word_count"], 3)

    def test_empty_or_low_confidence_text_requests_retry(self):
        result = read_sign_image(
            self.image.tobytes(), FakeOCREngine([([], "blurred", 0.2)])
        )

        self.assertEqual(result["text"], "")
        self.assertEqual(result["confidence"], 0.0)

    def test_rejects_invalid_image(self):
        with self.assertRaises(ValueError):
            read_sign_image(b"not an image", FakeOCREngine([]))


if __name__ == "__main__":
    unittest.main()