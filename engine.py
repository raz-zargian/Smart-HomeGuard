import cv2
import ultralytics
from ultralytics import YOLO
import cv2
import base64
import requests
from datetime import datetime

AWS_URL="https://your-aws-endpoint.com/api/upload"
CAM_URL="rtsp://eyal:qwer1234@10.100.102.23:554/cam/realmonitor?channel=2&subtype=1"
class Camera:
    def __init__(self,camera_type="webcam",stream_url=None):
        self.camera_type=camera_type
        if self.camera_type=="webcam":
            self.source=0
        elif self.camera_type=="pi_camera":
            self.source=0
        elif self.camera_type=="wifi":
            if stream_url is None:
                raise ValueError("Stream URL must be provided for wifi camera")
            self.source=stream_url
        else:
            raise ValueError("Invalid camera type. Supported types are: webcam, pi_camera, wifi")
        self.cap=cv2.VideoCapture(self.source)
        if not self.cap.isOpened():
            print(f"[ERROR] Could not open {self.camera_type} camera at source: {self.source}")
    def get_frame(self):
        ret,frame=self.cap.read()
        if not ret:
            print(f"[ERROR] Failed to capture frame from {self.camera_type} camera")
            return None
        return frame
    def release(self):
        self.cap.release()
        print(f"[INFO] Released {self.camera_type} camera resources")

class PersonDetector:
    def __init__(self,model_path="yolov8n.pt"):
        self.model=YOLO(model_path)

        self.cache={}
        self.cache_cooldown=60

    def clean_cache(self,current_time):
        self.cache={
            person_id:timestamp for person_id,timestamp in self.cache.items()
            if current_time-timestamp<self.cache_cooldown
        }

    def detect_and_get_crop(self,frame):
        results=self.model(frame,classes=0,conf=0.8,persist=True,verbose=False)

        self.clean_cache(current_time=datetime.now())


        if len(results) > 0 and results[0].boxes is not None and results[0].boxes.id is not None:
            cropped_persons=[]
            boxes = results[0].boxes.xyxy.cpu().numpy().astype(int)
            ids = results[0].boxes.id.cpu().numpy().astype(int)

            for box, person_id in zip(boxes, ids):
                if person_id not in self.cache:
                    x1, y1, x2, y2 = map(int, box.xyxy[0])
                    cropped_persons.append(frame[y1:y2,x1:x2])
                    self.cache[person_id] = datetime.now()

            return cropped_persons

def send_to_aws(cropped_persons,endpoint_url):
    base64_images=[]
    for crop in cropped_persons:
        success,buffer=cv2.imencode(".jpg",crop)
        if not success:
            print("[ERROR] Failed to encode cropped image")
            continue
        img_base64=base64.b64encode(buffer.tobytes()).decode('utf-8')
        base64_images.append(img_base64)
    payload={
        "date":datetime.now().isoformat(),
        "images":base64_images
    }
    try:
        response= requests.post(endpoint_url,json=payload)
        if response.status_code==200:
           print(f"Successfully sent {len(base64_images)} crops to AWS!")
        else:
            print(f"[ERROR] Failed to send data to AWS. Status code: {response.status_code}, Response: {response.text}")
    except Exception as e:
        print(f"[ERROR] Exception occurred while sending data to AWS: {e}")

def main():
    cam=Camera(camera_type="webcam")
    detector=PersonDetector()
    while True:
        frame = cam.get_frame()
        if frame is None:
            print("[ERROR] Failed to capture frame from camera")
            break
        detections=detector.detect_and_get_crop(frame)
        if len(detections) > 0:
            print(f"Detected {len(detections)} person(s) in the frame")
            send_to_aws(detections,endpoint_url=AWS_URL)


import cv2


def test_camera():
    # 1. הגדרת הפרטים (וודאי שהם מדויקים)
    ip = "10.100.102.23"
    user = "eyal"
    pwd = "qwer1234"  # הכניסי כאן את הסיסמה של ה-NVR
    channel = 1  # ערוץ המצלמה שאת רוצה לראות (1-6)

    rtsp_url = f"rtsp://{user}:{pwd}@{ip}:554/cam/realmonitor?channel={channel}&subtype=1"

    print(f"Connecting to: {rtsp_url}")

    # 3. פתיחת זרם הוידאו
    cap = cv2.VideoCapture(rtsp_url)

    if not cap.isOpened():
        print("Error: Could not open video stream. Check IP, Password or RTSP settings.")
        return

    print("Success! Press 'q' on your keyboard to close the window.")

    while True:
        # קריאת פריים בודד
        ret, frame = cap.read()

        if not ret:
            print("Lost connection to camera.")
            break

        # הצגת התמונה בחלון
        cv2.imshow("Camera Test - Smart Home Guard", frame)

        # המתנה ללחיצה על 'q' כדי לצאת
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    # שחרור משאבים
    cap.release()
    cv2.destroyAllWindows()

def show_camera():
    # פתיחת החיבור למצלמה
    cap = cv2.VideoCapture(CAM_URL)

    if not cap.isOpened():
        print("error")
        return

    print("sucsses")

    while True:
        ret, frame = cap.read()

        if not ret:
            print("error")
            break

        # --- השורה שפותחת את החלון ---
        cv2.imshow("Smart Home Guard - Live View", frame)

        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    show_camera()