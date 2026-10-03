import torch
import cv2
import numpy as np
from ultralytics import YOLO

print("Loading YOLO...")
yolo = YOLO("yolo11n.pt")
print("YOLO loaded!")

print("Loading MiDaS...")
midas = torch.hub.load("intel-isl/MiDaS", "MiDaS_small")
midas.eval()

midas_transforms = torch.hub.load(
    "intel-isl/MiDaS",
    "transforms"
)

transform = midas_transforms.small_transform

print("MiDaS loaded!")

cap = cv2.VideoCapture(0)

if not cap.isOpened():
    print("Error: Could not open webcam.")
    exit()

print("Camera started.")
print("Press Q to quit.")

while True:

    # -------------------------
    # Read camera frame
    # -------------------------
    success, frame = cap.read()

    if not success:
        print("Could not read frame.")
        break

    frame = cv2.resize(frame, (640, 480))

    # -------------------------
    # YOLO
    # -------------------------
    results = yolo(
        frame,
        imgsz=416,
        conf=0.40,
        verbose=False
    )

    result = results[0]

    # -------------------------
    # MiDaS
    # -------------------------
    rgb = cv2.cvtColor(
        frame,
        cv2.COLOR_BGR2RGB
    )

    input_batch = transform(rgb)

    with torch.no_grad():
        prediction = midas(input_batch)

        prediction = torch.nn.functional.interpolate(
            prediction.unsqueeze(1),
            size=frame.shape[:2],
            mode="bicubic",
            align_corners=False
        ).squeeze()

    depth_map = prediction.cpu().numpy()

    # -------------------------
    # Process YOLO objects
    # -------------------------
    for box in result.boxes:

        x1, y1, x2, y2 = box.xyxy[0].cpu().numpy()

        x1 = max(0, int(x1))
        y1 = max(0, int(y1))
        x2 = min(frame.shape[1], int(x2))
        y2 = min(frame.shape[0], int(y2))

        class_id = int(box.cls[0])

        object_name = yolo.names[class_id]

        confidence = float(box.conf[0])

        object_depth = depth_map[
            y1:y2,
            x1:x2
        ]

        if object_depth.size > 0:

            depth_value = float(
                np.median(object_depth)
            )

            print(
                f"{object_name} | "
                f"confidence: {confidence:.2f} | "
                f"depth: {depth_value:.2f}"
            )

        # Draw bounding box
        cv2.rectangle(
            frame,
            (x1, y1),
            (x2, y2),
            (0, 255, 0),
            2
        )

        cv2.putText(
            frame,
            f"{object_name} {confidence:.2f}",
            (x1, y1 - 10),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.6,
            (0, 255, 0),
            2
        )

    # -------------------------
    # Show camera
    # -------------------------
    cv2.imshow(
        "YOLO + MiDaS",
        frame
    )

    # -------------------------
    # Check Q
    # -------------------------
    key = cv2.waitKey(1) & 0xFF

    if key == ord("q"):
        print("Q pressed. Exiting...")
        break

cap.release()
cv2.destroyAllWindows()

print("Program stopped.")