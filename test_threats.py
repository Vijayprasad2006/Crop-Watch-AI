import os
from supabase import create_client, Client

SUPABASE_URL = "https://opfitfilznxlfuuglmrv.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9wZml0Zmlsem54bGZ1dWdsbXJ2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM1NDEyNDgsImV4cCI6MjA4OTExNzI0OH0.kczvH-wFp5bf0u39Ew-A8TPna7S_nYHHibFYC0Lr1NU"

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

try:
    print("Authenticating anonymously...")
    auth_response = supabase.auth.sign_in_anonymously()
    print(f"UID: {auth_response.user.id}")

    print("Checking threats table...")
    try:
        res = supabase.table("threats").select("*").execute()
        print(f"Threats table: {res.data}")
    except Exception as e:
        print(f"Threats table error: {e}")

    print("Listing files in 'threats' bucket...")
    try:
        files = supabase.storage.from_("threats").list()
        print(f"Storage root files/folders: {files}")
        for folder in files:
            if folder['id'] is None and folder['name']:  # It's a folder
                print(f"Files in folder {folder['name']}:")
                sub_files = supabase.storage.from_("threats").list(folder['name'])
                print(sub_files)
                for sub_f in sub_files:
                     if sub_f['id'] is None and sub_f['name']: # subfolder
                          print(f"Files in subfolder {folder['name']}/{sub_f['name']}:")
                          sub_sub = supabase.storage.from_("threats").list(f"{folder['name']}/{sub_f['name']}")
                          print(sub_sub)
    except Exception as e:
        print(f"Storage error: {e}")

except Exception as e:
    print(f"Global Error: {e}")
