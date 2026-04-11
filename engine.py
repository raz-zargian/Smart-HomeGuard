# yolo export model=yolov8n.pt format=onnx imgsz=288,352
import os

from ultralytics import YOLO
import cv2
import base64
import requests
from datetime import datetime
import yaml

class Camera:
    def __init__(self,camera_type="webcam",stream_url=None,video_path=None,show_debug=False):
        self.camera_type=camera_type
        self.show_debug=show_debug
        if self.camera_type=="webcam":
            self.source=0
        elif self.camera_type=="pi_camera":
            self.source=0
        elif self.camera_type=="wifi":
            if stream_url is None:
                raise ValueError("Stream URL must be provided for wifi camera")
            self.source=stream_url
        elif self.camera_type=="test":
            if video_path is None:
                raise ValueError("Video path must be provided for test camera")
            self.source=video_path
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
        if self.show_debug:
            print(f"[DEBUG] Captured frame from {self.camera_type} camera with shape: {frame.shape}")
            cv2.imshow("Smart Home Guard - Live View", frame)
        return frame
    
    def release(self):
        self.cap.release()
        print(f"[INFO] Released {self.camera_type} camera resources")

class PersonDetector:
    
    def __init__(self,model_path="yolov8n.pt",show_debug="save"):
        self.model=YOLO(model_path)
        self.show_debug=show_debug

        self.cache={}
        self.cache_cooldown=60

        if self.show_debug in "saveshow":
            os.makedirs("save",exist_ok=True)
            os.makedirs("show",exist_ok=True)

    def clean_cache(self,current_time):
        self.cache={
            person_id:timestamp for person_id,timestamp in self.cache.items()
            if (current_time - timestamp).total_seconds()<self.cache_cooldown
        }

    def add_bbox(self, frame, x1, y1, x2, y2, person_id):
        cv2.rectangle(frame,(x1,y1),(x2,y2),(0,255,0),2)
        cv2.putText(frame,f"ID: {person_id}",(x1,y1-10),cv2.FONT_HERSHEY_SIMPLEX,0.9,(0,255,0),2)

    def detect_and_get_crop(self,frame):
        
        results=self.model.track(frame,classes=0,conf=0.8,persist=True,verbose=False)
        
        self.clean_cache(current_time=datetime.now())

        if len(results) > 0 and results[0].boxes is not None and results[0].boxes.id is not None:
            cropped_persons=[]
            boxes = results[0].boxes.xyxy.cpu().numpy().astype(int)
            ids = results[0].boxes.id.cpu().numpy().astype(int)

            debug_frame=frame.copy() if self.show_debug=="show" or self.show_debug=="save" else None

            for box, person_id in zip(boxes, ids):
                x1, y1, x2, y2 = box
                crop=frame[y1:y2, x1:x2]
                if debug_frame is not None:
                    self.add_bbox(debug_frame, x1, y1, x2, y2, person_id)

                if person_id not in self.cache:
                    
                    cropped_persons.append(crop)
                    self.cache[person_id] = datetime.now()

                    if self.show_debug=="save":
                        cv2.imwrite(f"save/detected_person_{person_id}.jpg", crop)

                    

            if self.show_debug=="save":
                
                cv2.imwrite("save/debug_frame.jpg", debug_frame)      
            if self.show_debug=="show":

                cv2.imshow("show/Detected Persons", debug_frame)
                cv2.waitKey(1)


            return cropped_persons
        return []


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
    config_path="privateInfo.yaml"
    model_path="yolov8n.onnx"
    
    with open(config_path,"r") as f:
        config=yaml.safe_load(f)
    AWS_URL=config.get("AWS_URL")
    CAM_URL=config.get("CAM_URL")

    
    cam=Camera(camera_type="test",stream_url=CAM_URL,video_path="examples/cctv1.mp4")
    detector=PersonDetector(model_path=model_path)
    while True:
        frame = cam.get_frame()
       
        if frame is None:
            print("[ERROR] Failed to capture frame from camera")
            break
        detections=detector.detect_and_get_crop(frame)
        if len(detections) > 0:
            print(f"Detected {len(detections)} person(s) in the frame")
            cv2.imshow("Smart Home Guard - Live View", frame)
           # send_to_aws(detections,endpoint_url=AWS_URL)


def show_camera(CAM_URL):
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

        cv2.imshow("Smart Home Guard - Live View", frame)

        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    #show_camera()
    main()    
