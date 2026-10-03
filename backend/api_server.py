"""Small HTTP API exposing the existing perception and navigation pipeline."""

import cgi
import json
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from io import BytesIO
from typing import Any, Dict, Optional

import cv2
import numpy as np

from navigation_engine import NavigationDecisionEngine
from ocr_service import read_sign_image
from perception_module import PerceptionModule


_pipeline: Optional[PerceptionModule] = None
_pipeline_lock = threading.Lock()
_inference_lock = threading.Lock()


def _get_pipeline() -> PerceptionModule:
    global _pipeline
    with _pipeline_lock:
        if _pipeline is None:
            _pipeline = PerceptionModule()
        return _pipeline


def _json_value(value: Any) -> Any:
    if hasattr(value, "value"):
        return value.value
    if isinstance(value, dict):
        return {key: _json_value(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [_json_value(item) for item in value]
    if isinstance(value, np.generic):
        return value.item()
    return value


def analyze_image(image_bytes: bytes, perception: Optional[PerceptionModule] = None) -> Dict[str, Any]:
    """Analyze one encoded image using the existing backend components."""
    image = cv2.imdecode(np.frombuffer(image_bytes, dtype=np.uint8), cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError("The uploaded file is not a supported image")

    # PerceptionModule owns mutable MiDaS and classifier state; serialize users
    # of the shared model instances served by ThreadingHTTPServer.
    with _inference_lock:
        results = (perception or _get_pipeline()).process_frame(image)
    detections = []
    for detection in results.get("detections", []):
        detections.append(_json_value({
            key: value for key, value in detection.items()
            if key not in {"depth_value"}
        }))

    decision = NavigationDecisionEngine().decide(results.get("detections", []))
    return _json_value({**decision, "detections": detections})


class NavigationRequestHandler(BaseHTTPRequestHandler):
    """HTTP handler for health checks and single-frame analysis."""

    def _send_json(self, status: int, payload: Dict[str, Any]) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        if self.path == "/health":
            self._send_json(200, {"status": "ok"})
            return
        self._send_json(404, {"error": "Not found"})

    def do_POST(self) -> None:
        if self.path not in {"/analyze-frame", "/read-sign"}:
            self._send_json(404, {"error": "Not found"})
            return

        content_type = self.headers.get("Content-Type", "")
        if not content_type.startswith("multipart/form-data"):
            self._send_json(400, {"error": "Expected multipart/form-data"})
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
            form = cgi.FieldStorage(
                fp=BytesIO(self.rfile.read(length)),
                headers=self.headers,
                environ={"REQUEST_METHOD": "POST", "CONTENT_TYPE": content_type},
            )
            image_field = form["image"] if "image" in form else form["frame"]
            image_bytes = image_field.file.read()
            if self.path == "/read-sign":
                self._send_json(200, read_sign_image(image_bytes))
            else:
                self._send_json(200, analyze_image(image_bytes))
        except (KeyError, ValueError, TypeError) as error:
            self._send_json(400, {"error": str(error)})
        except Exception as error:
            self._send_json(500, {"error": str(error)})

    def log_message(self, format: str, *args: Any) -> None:
        print(f"[api] {format % args}")


def create_server(host: str = "0.0.0.0", port: int = 8000) -> ThreadingHTTPServer:
    return ThreadingHTTPServer((host, port), NavigationRequestHandler)


def run_server(host: str = "0.0.0.0", port: int = 8000) -> None:
    server = create_server(host, port)
    print(f"Navigation API listening on http://{host}:{port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    run_server()
