import os
from supabase import create_client, Client

SUPABASE_URL = "https://opfitfilznxlfuuglmrv.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9wZml0Zmlsem54bGZ1dWdsbXJ2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM1NDEyNDgsImV4cCI6MjA4OTExNzI0OH0.kczvH-wFp5bf0u39Ew-A8TPna7S_nYHHibFYC0Lr1NU"

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

try:
    print("Authenticating anonymously...")
    auth_response = supabase.auth.sign_in_anonymously()
    uid = auth_response.user.id
    print(f"UID: {uid}")

    print("Checking if user exists...")
    res = supabase.table("users").select("*").eq("phone", "1234567890").execute()
    print(f"Select response: {res}")

    print("Upserting user...")
    data = {
        "id": uid,
        "phone": "1234567890",
        "name": "Test Python",
        "location": "Test Location",
    }
    res2 = supabase.table("users").upsert(data).execute()
    print(f"Upsert response: {res2}")

except Exception as e:
    print(f"Error: {e}")
