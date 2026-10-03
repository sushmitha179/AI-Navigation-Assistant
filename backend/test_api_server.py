import threading
import time
import json
import unittest
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from unittest.mock import patch

import cv2
import numpy as np

from api_server import analyze_image, create_server
from collision_risk import CollisionRisk, HorizontalPosition


class FakePerception:
    def process_frame(self, frame):
        return {
            "detections": [{
                "class_name": "person",
                "confidence": 0.95,
                "bbox": (1, 1, 20, 20),
                "collision_risk": CollisionRisk.HIGH,
                "horizontal_position": HorizontalPosition.CENTER,
                "proximity_category": "VERY CLOSE",
                "depth_value": 10.0,
            }]
        }


class TestApiServer(unittest.TestCase):
    def test_analyze_image_returns_navigation_and_detections(self):
        success, encoded = cv2.imencode(".jpg", np.zeros((20, 20, 3), dtype=np.uint8))
        self.assertTrue(success)

        result = analyze_image(encoded.tobytes(), FakePerception())

        self.assertEqual(result["action"], "STOP")
        self.assertEqual(result["priority"], "HIGH")
        self.assertEqual(result["relevant_object"], "person")
        self.assertEqual(result["detections"][0]["collision_risk"], "HIGH")
        self.assertNotIn("depth_value", result["detections"][0])

    def test_shared_perception_inference_is_serialized(self):
        class ConcurrentPerception:
            def __init__(self):
                self.lock = threading.Lock()
                self.active = 0
                self.max_active = 0

            def process_frame(self, frame):
                with self.lock:
                    self.active += 1
                    self.max_active = max(self.max_active, self.active)
                time.sleep(0.02)
                with self.lock:
                    self.active -= 1
                return {"detections": []}

        success, encoded = cv2.imencode(
            ".jpg", np.zeros((20, 20, 3), dtype=np.uint8)
        )
        self.assertTrue(success)
        perception = ConcurrentPerception()

        with ThreadPoolExecutor(max_workers=4) as executor:
            results = list(executor.map(
                lambda _: analyze_image(encoded.tobytes(), perception), range(8)
            ))

        self.assertEqual(len(results), 8)
        self.assertEqual(perception.max_active, 1)

    def test_read_sign_endpoint_returns_ocr_text_and_confidence(self):
        success, encoded = cv2.imencode(
            ".jpg", np.zeros((20, 20, 3), dtype=np.uint8)
        )
        self.assertTrue(success)
        boundary = "ocr-test-boundary"
        body = (
            f"--{boundary}\r\n"
            'Content-Disposition: form-data; name="image"; filename="sign.jpg"\r\n'
            "Content-Type: image/jpeg\r\n\r\n"
        ).encode() + encoded.tobytes() + f"\r\n--{boundary}--\r\n".encode()

        server = create_server(host="127.0.0.1", port=0)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            request = urllib.request.Request(
                f"http://127.0.0.1:{server.server_port}/read-sign",
                data=body,
                headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
                method="POST",
            )
            with patch(
                "api_server.read_sign_image",
                return_value={"text": "EXIT", "confidence": 0.9, "word_count": 1},
            ) as ocr:
                with urllib.request.urlopen(request, timeout=3) as response:
                    payload = json.loads(response.read())
                ocr.assert_called_once_with(encoded.tobytes())
            self.assertEqual(payload["text"], "EXIT")
            self.assertEqual(payload["confidence"], 0.9)
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=3)


if __name__ == "__main__":
    unittest.main()
