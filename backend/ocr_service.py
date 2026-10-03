"""On-demand sign text extraction using RapidOCR's CPU ONNX runtime."""

import threading
from typing import Any, Dict, Optional

import cv2
import numpy as np
from rapidocr_onnxruntime import RapidOCR


_engine: Optional[RapidOCR] = None
_engine_lock = threading.Lock()


def read_sign_image(image_bytes: bytes, engine: Optional[Any] = None) -> Dict[str, Any]:
    """Recognize text from one encoded image; OCR is never run per camera frame."""
    image = cv2.imdecode(np.frombuffer(image_bytes, dtype=np.uint8), cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError("The uploaded file is not a supported image")

    global _engine
    if engine is None:
        with _engine_lock:
            if _engine is None:
                _engine = RapidOCR()
            results, _ = _engine(image)
    else:
        results, _ = engine(image)

    recognized = []
    for item in results or []:
        if len(item) < 3:
            continue
        text = str(item[1]).strip()
        try:
            confidence = float(item[2])
        except (TypeError, ValueError):
            continue
        if text and confidence >= 0.35:
            recognized.append((text, confidence))

    text = " ".join(item[0] for item in recognized)
    confidence = (
        sum(item[1] for item in recognized) / len(recognized)
        if recognized
        else 0.0
    )
    return {
        "text": text,
        "confidence": round(confidence, 4),
        "word_count": sum(len(item[0].split()) for item in recognized),
    }