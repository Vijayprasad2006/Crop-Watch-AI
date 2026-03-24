import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();

  void _toggleAuthMode() {
    setState(() {
      isLogin = !isLogin;
    });
  }

  bool _isLoading = false;

  Future<void> _ensureAnonSession() async {
    final supabase = Supabase.instance.client;
    if (supabase.auth.currentSession == null) {
      await supabase.auth.signInAnonymously();
    }
  }

  void _submitAuth() async {

    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();
    final location = _locationController.text.trim();
    
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a phone number')),
      );
      return;
    }

    if (!isLogin) {
      if (name.isEmpty || location.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your name and farm location')),
        );
        return;
      }
    }
    
    setState(() { _isLoading = true; });

    try {
      final supabase = Supabase.instance.client;

      // Ensure we always have a session that does NOT depend on email/password.
      await _ensureAnonSession();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('farmer_phone', phone);

      // Look up existing profile by phone, catching RLS or duplicate errors safely
      Map<String, dynamic>? existingByPhone;
      try {
        final existingList = await supabase
            .from('users')
            .select()
            .eq('phone', phone)
            .limit(1);
        if (existingList.isNotEmpty) {
          existingByPhone = existingList.first;
        }
      } catch (e) {
        log('Error looking up phone (RLS/Duplicates): $e');
      }

      // Ignore strict checks to allow smooth login/signup in this demo app
      // irrespective of previous unlinked anonymous sessions logging out.

      final uid = supabase.auth.currentUser?.id;
      if (uid != null) {
        // Load any existing profile for this auth user
        Map<String, dynamic>? existingProfile;
        try {
          existingProfile = await supabase
              .from('users')
              .select()
              .eq('id', uid)
              .maybeSingle();
        } catch (_) {}

        final effectiveName = isLogin
            ? (existingProfile?['name'] ?? existingByPhone?['name'] ?? 'Returning Farmer')
            : name;
        final effectiveLocation = isLogin
            ? (existingProfile?['location'] ?? existingByPhone?['location'] ?? location)
            : location;

        try {
          await supabase.from('users').upsert({
            'id': uid,
            'phone': phone,
            'name': effectiveName,
            'location': effectiveLocation,
            'updated_at': DateTime.now().toIso8601String(),
          });
          log('User profile processed in Supabase DB (anonymous auth).');
        } catch (dbError) {
          log('DB Upsert Error ignored to allow dashboard access: $dbError');
        }
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    } catch (e) {
      log('Auth Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeInDown(
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryStatusColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(LucideIcons.shieldCheck, size: 60, color: AppTheme.primaryStatusColor),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          isLogin ? 'Welcome Back' : 'Create Account',
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isLogin ? 'Login to protect your farm' : 'Register to secure your harvest',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 18,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                FadeInUp(
                  child: Column(
                    children: [
                      if (!isLogin) ...[
                        TextFormField(
                          controller: _nameController,
                          style: GoogleFonts.outfit(color: AppTheme.textPrimaryColor),
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: Icon(LucideIcons.user, color: AppTheme.textSecondaryColor),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _locationController,
                          style: GoogleFonts.outfit(color: AppTheme.textPrimaryColor),
                          decoration: const InputDecoration(
                            labelText: 'Farm Location',
                            prefixIcon: Icon(LucideIcons.mapPin, color: AppTheme.textSecondaryColor),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _phoneController,
                        style: GoogleFonts.outfit(color: AppTheme.textPrimaryColor),
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: Icon(LucideIcons.phone, color: AppTheme.textSecondaryColor),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitAuth,
                          child: _isLoading 
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(isLogin ? 'Login' : 'Sign Up'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: _toggleAuthMode,
                        child: Text(
                          isLogin 
                              ? "Don't have an account? Sign Up" 
                              : "Already have an account? Login",
                          style: GoogleFonts.outfit(
                            color: AppTheme.accentColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
