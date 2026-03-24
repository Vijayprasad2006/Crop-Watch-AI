import 'package:supabase/supabase.dart';

void main() async {
  print("Starting test");
  final SUPABASE_URL = "https://opfitfilznxlfuuglmrv.supabase.co";
  final SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9wZml0Zmlsem54bGZ1dWdsbXJ2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM1NDEyNDgsImV4cCI6MjA4OTExNzI0OH0.kczvH-wFp5bf0u39Ew-A8TPna7S_nYHHibFYC0Lr1NU";
  
  final supabase = SupabaseClient(SUPABASE_URL, SUPABASE_KEY);
  
  try {
    final response = await supabase.auth.signInAnonymously();
    final uid = response.user?.id;
    print("Anon UID: $uid");
    
    // Test selecting a phone number
    final existing = await supabase.from('users').select().eq('phone', '1234567890').maybeSingle();
    print("Existing user: $existing");
    
    // Test upserting
    final data = {
      'id': uid,
      'phone': '1234567890',
      'name': 'Test',
      'location': 'Test',
      'updated_at': DateTime.now().toIso8601String(),
    };
    print("Upserting: $data");
    await supabase.from('users').upsert(data);
    print("Upsert Success!");
  } catch (e) {
    print("Error occurred: $e");
  }
}
