import os
from supabase import create_client, Client

SUPABASE_URL = "https://opfitfilznxlfuuglmrv.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9wZml0Zmlsem54bGZ1dWdsbXJ2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM1NDEyNDgsImV4cCI6MjA4OTExNzI0OH0.kczvH-wFp5bf0u39Ew-A8TPna7S_nYHHibFYC0Lr1NU"

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

try:
    print("Testing Email/Password Auth...")
    email = "9999999990@cropwatch.ai"
    password = "cropwatch-password"
    
    print("Trying to sign up...")
    try:
        res = supabase.auth.sign_up({"email": email, "password": password})
        print(f"Sign up success! UID: {res.user.id}")
    except Exception as e:
        print(f"Sign up error: {e}")

    print("Trying to log in...")
    try:
        res2 = supabase.auth.sign_in_with_password({"email": email, "password": password})
        print(f"Log in success! UID: {res2.user.id}")
    except Exception as e:
        print(f"Log in error: {e}")

except Exception as e:
    print(f"Global error: {e}")
