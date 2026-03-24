import os
from supabase import create_client, Client

SUPABASE_URL = "https://opfitfilznxlfuuglmrv.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9wZml0Zmlsem54bGZ1dWdsbXJ2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM1NDEyNDgsImV4cCI6MjA4OTExNzI0OH0.kczvH-wFp5bf0u39Ew-A8TPna7S_nYHHibFYC0Lr1NU"

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

try:
    print("Signing in with NEW anonymous user...")
    auth_response = supabase.auth.sign_in_anonymously()
    uid = auth_response.user.id
    print(f"NEW UID: {uid}")

    print("Upserting phone 1234567890 which was already used...")
    data = {
        "id": uid,
        "phone": "1234567890",
        "name": "Another User",
        "location": "Another Location",
    }
    res2 = supabase.table("users").upsert(data).execute()
    print(f"Upsert response: {res2}")

except Exception as e:
    print(f"Error occurred: {e}")
