from ultralytics import YOLO
import cv2

model = YOLO("yolo11n.pt")

cap = cv2.VideoCapture(0)

if not cap.isOpened():
    print("Error: Could not open webcam.")
    exit()

print("Camera started. Press Q to quit.")

while True:

    success, frame = cap.read()

    if not success:
        print("Could not read frame.")
        break

    frame = cv2.resize(frame, (640, 480))

    results = model(
        frame,
        imgsz=416,
        conf=0.40,
        verbose=False
    )

    result = results[0]

    # Print only detected object names
    detected_objects = []

    for box in result.boxes:

        class_id = int(box.cls[0])
        object_name = model.names[class_id]
        confidence = float(box.conf[0])

        detected_objects.append(
            f"{object_name} ({confidence:.2f})"
        )

    if detected_objects:
        print("Detected:", ", ".join(detected_objects))
    else:
        print("Detected: Nothing")

    # Show original camera frame only
    cv2.imshow(
        "AI Navigation Camera",
        frame
    )

    if cv2.waitKey(1) & 0xFF == ord("q"):
        break

cap.release()
cv2.destroyAllWindows()