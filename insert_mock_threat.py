import os
import time
from supabase import create_client, Client

SUPABASE_URL = "https://opfitfilznxlfuuglmrv.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9wZml0Zmlsem54bGZ1dWdsbXJ2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM1NDEyNDgsImV4cCI6MjA4OTExNzI0OH0.kczvH-wFp5bf0u39Ew-A8TPna7S_nYHHibFYC0Lr1NU"

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

try:
    print("Authenticating anonymously...")
    auth_response = supabase.auth.sign_in_anonymously()
    uid = auth_response.user.id
    
    print("Upserting user profile to satisfy foreign keys...")
    supabase.table("users").upsert({"id": uid, "phone": "0000000001", "name": "Mock User"}).execute()
    
    current_time = time.time()
    
    new_alert = {
        "user_id": uid,
        "detected_class": "Human / Unknown Person",
        "image_url": "https://via.placeholder.com/300?text=Mock+Threat"
    }
    
    print("Inserting mock threat...")
    res = supabase.table("threats").insert(new_alert).execute()
    print(f"Success: {res.data}")

except Exception as e:
    print(f"Error: {e}")
