import cv2
import numpy as np
import tensorflow as tf
from supabase import create_client, Client
import time
import os

# --- Configuration ---
SUPABASE_URL = "https://opfitfilznxlfuuglmrv.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9wZml0Zmlsem54bGZ1dWdsbXJ2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM1NDEyNDgsImV4cCI6MjA4OTExNzI0OH0.kczvH-wFp5bf0u39Ew-A8TPna7S_nYHHibFYC0Lr1NU"
MODEL_PATH = "assets/models/ssd_mobilenet.tflite"
LABELS_PATH = "assets/models/labels.txt"

# --- Initialization ---
print("Initializing Supabase...")
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# Try to authenticate anonymously to get a UID
try:
    auth_response = supabase.auth.sign_in_anonymously()
    uid = auth_response.user.id
    print(f"Authenticated anonymously with UID: {uid}")
    
    # Upsert user to satisfy foreign key constraints before inserting threats
    print("Upserting user profile to satisfy foreign keys...")
    supabase.table("users").upsert({"id": uid, "phone": "0000000002", "name": "Laptop Scanner"}).execute()
except Exception as e:
    print(f"Auth error (using fallback UID): {e}")
    uid = "laptop_node"

print("Loading TFLite Model...")
interpreter = tf.lite.Interpreter(model_path=MODEL_PATH)
interpreter.allocate_tensors()

input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

with open(LABELS_PATH, 'r') as f:
    labels = [line.strip() for line in f.readlines()]

def format_label(label):
    if label == "person": return "Human / Unknown Person"
    return "Unknown Object Detected"

# --- Open Camera ---
print("Starting Camera...")
cap = cv2.VideoCapture(0, cv2.CAP_DSHOW)

last_alert_time = 0
ALERT_COOLDOWN = 15 # seconds

while True:
    ret, frame = cap.read()
    if not ret:
        print("Failed to grab frame")
        break

    # Prepare input for model (300x300 RGB)
    img_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    img_resized = cv2.resize(img_rgb, (300, 300))
    input_data = np.expand_dims(img_resized, axis=0)

    # Some SSD models use uint8, some use float32. Our dart code handles uint8.
    if input_details[0]['dtype'] == np.uint8:
        pass # Already uint8
    else:
        input_data = (np.float32(input_data) / 255.0)

    interpreter.set_tensor(input_details[0]['index'], input_data)
    interpreter.invoke()

    # The mobile net outputs are typically at indices 0, 1, 2, 3 but can vary by model.
    # Usually: Boxes, Classes, Scores, Num Object
    boxes = interpreter.get_tensor(output_details[0]['index'])[0]
    classes = interpreter.get_tensor(output_details[1]['index'])[0]
    scores = interpreter.get_tensor(output_details[2]['index'])[0]

    threat_detected = False
    best_threat_label = None
    best_threat_score = 0

    h, w, _ = frame.shape

    for i in range(len(scores)):
        if scores[i] > 0.45:
            class_idx = int(classes[i])
            label = labels[class_idx] if class_idx < len(labels) else "Unknown"
            
            l = label.lower()
            is_relevant = any(kw in l for kw in ['person', 'dog', 'cat', 'cow', 'horse', 'sheep', 'bird', 'elephant', 'bear', 'zebra', 'giraffe'])
            
            if is_relevant:
                threat_detected = True
                if scores[i] > best_threat_score:
                    best_threat_score = scores[i]
                    best_threat_label = format_label(label)

                y_min = int(max(1, (boxes[i][0] * h)))
                x_min = int(max(1, (boxes[i][1] * w)))
                y_max = int(min(h, (boxes[i][2] * h)))
                x_max = int(min(w, (boxes[i][3] * w)))

                # Draw bounding box
                cv2.rectangle(frame, (x_min, y_min), (x_max, y_max), (0, 0, 255), 2)
                cv2.putText(frame, f"{format_label(label)} ({scores[i]*100:.0f}%)", (x_min, y_min - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 255), 2)

    cv2.imshow("CropWatch AI Laptop Scanner", frame)

    current_time = time.time()
    if threat_detected and (current_time - last_alert_time) > ALERT_COOLDOWN:
        print(f"THREAT DETECTED: {best_threat_label}")
        
        # Play a local siren/alert sound on the laptop
        try:
            import winsound
            print("Playing alarm sound...")
            for _ in range(3):
                winsound.Beep(1000, 400) # frequency, duration (ms)
                winsound.Beep(1500, 400)
        except Exception as e:
            print("Could not play Windows alert sound.")
        
        # Save screenshot
        filename = f"threat_{int(current_time*1000)}.png"
        filepath = os.path.join("build", filename)
        os.makedirs("build", exist_ok=True)
        cv2.imwrite(filepath, frame)
        
        # Upload to Supabase Storage
        try:
            print(f"Uploading {filename} to Supabase...")
            storage_path = f"{uid}/images/{filename}"
            with open(filepath, "rb") as f:
                supabase.storage.from_("threat_images").upload(storage_path, f.read())
            
            # Get public URL
            public_url = supabase.storage.from_("threat_images").get_public_url(storage_path)

            # Insert into database table
            new_alert = {
                "user_id": uid,
                "detected_class": best_threat_label,
                "image_url": public_url
            }
            supabase.table("threats").insert(new_alert).execute()
            print("Successfully synced to CropWatch AI App!")
            
        except Exception as e:
            print(f"Failed to sync alert: {e}")

        last_alert_time = current_time

    # Press 'q' to quit
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
