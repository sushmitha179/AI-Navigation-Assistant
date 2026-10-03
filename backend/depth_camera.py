import torch
import cv2
import numpy as np

print("Loading MiDaS...")

model_type = "MiDaS_small"

midas = torch.hub.load("intel-isl/MiDaS", model_type)
midas.eval()

midas_transforms = torch.hub.load(
    "intel-isl/MiDaS",
    "transforms"
)

transform = midas_transforms.small_transform

print("MiDaS loaded successfully!")
print("Starting camera...")

cap = cv2.VideoCapture(0)

if not cap.isOpened():
    print("Error: Could not open webcam.")
    exit()

print("Camera started. Press Q to quit.")

frame_count = 0
depth_map = None

while True:

    success, frame = cap.read()

    if not success:
        print("Could not read frame.")
        break

    # Smaller frame for CPU
    frame = cv2.resize(frame, (320, 240))

    frame_count += 1

    # Run MiDaS only every 5th frame
    if frame_count % 5 == 0:

        img = cv2.cvtColor(
            frame,
            cv2.COLOR_BGR2RGB
        )

        input_batch = transform(img)

        with torch.no_grad():

            prediction = midas(input_batch)

            prediction = torch.nn.functional.interpolate(
                prediction.unsqueeze(1),
                size=img.shape[:2],
                mode="bicubic",
                align_corners=False
            ).squeeze()

        depth_map = prediction.cpu().numpy()

    # Display depth if available
    if depth_map is not None:

        depth_normalized = cv2.normalize(
            depth_map,
            None,
            0,
            255,
            cv2.NORM_MINMAX
        )

        depth_normalized = depth_normalized.astype(
            np.uint8
        )

        depth_colormap = cv2.applyColorMap(
            depth_normalized,
            cv2.COLORMAP_MAGMA
        )

        cv2.imshow(
            "MiDaS Depth",
            depth_colormap
        )

    cv2.imshow(
        "Camera",
        frame
    )

    if cv2.waitKey(1) & 0xFF == ord("q"):
        break

cap.release()
cv2.destroyAllWindows()

print("Camera stopped.")