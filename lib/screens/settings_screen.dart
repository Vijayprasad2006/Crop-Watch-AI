import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import 'auth_screen.dart';
import 'language_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _phone;
  String? _name;
  String? _location;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      if (user != null) {
        final userData = await supabase
            .from('users')
            .select()
            .eq('id', user.id)
            .maybeSingle();
            
        if (userData != null) {
          setState(() {
            _phone = userData['phone'];
            _name = userData['name'];
            _location = userData['location'];
            _isLoading = false;
          });
        } else {
          setState(() { _isLoading = false; });
        }
      } else {
        setState(() { _isLoading = false; });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _updateProfile() async {
    final nameController = TextEditingController(text: _name);
    final locationController = TextEditingController(text: _location);

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text('Update Profile', style: GoogleFonts.outfit(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: AppTheme.inputDecoration('Name', LucideIcons.user),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: locationController,
              style: const TextStyle(color: Colors.white),
              decoration: AppTheme.inputDecoration('Location', LucideIcons.mapPin),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: AppTheme.textSecondaryColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16)),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updated == true) {
      setState(() => _isLoading = true);
      try {
        final supabase = Supabase.instance.client;
        final user = supabase.auth.currentUser;
        if (user != null) {
          await supabase.from('users').update({
            'name': nameController.text.trim(),
            'location': locationController.text.trim(),
          }).eq('id', user.id);
          
          await _loadUserProfile();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile updated successfully')),
            );
          }
        }
      } catch (e) {
        debugPrint('Error updating profile: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update profile')),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'FarmGuard AI',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(LucideIcons.shieldCheck, color: AppTheme.primaryStatusColor, size: 48),
      applicationLegalese: 'Developed by Team CropWatch for the Global AI Hackathon',
      children: [
        const SizedBox(height: 24),
        const Text(
          'FarmGuard AI is an advanced farm monitoring and protection system powered by artificial intelligence. '
          'It helps farmers detect intruders and wild animals in real-time using cutting-edge edge-based computer vision.',
        ),
        const SizedBox(height: 16),
        const Text(
          'Features:\n'
          '• Real-time AI threat detection\n'
          '• Smart Night Mode with auto-flashlight\n'
          '• Localized multi-language voice alerts\n'
          '• Automatic cloud incident logging\n'
          '• Ultrasonic deterrent simulation',
        ),
      ],
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text('Logout', style: GoogleFonts.outfit(color: Colors.white)),
        content: Text('Are you sure you want to logout?', style: GoogleFonts.outfit(color: AppTheme.textSecondaryColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: AppTheme.textSecondaryColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Logout', style: GoogleFonts.outfit(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('language_code');
      await Supabase.instance.client.auth.signOut();
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryStatusColor))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileSection(),
                const SizedBox(height: 32),
                Text(
                  'Account',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSettingTile(
                  icon: LucideIcons.user,
                  title: 'Update Profile',
                  onTap: _updateProfile,
                ),
                _buildSettingTile(
                  icon: LucideIcons.languages,
                  title: 'Change Language',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LanguageSelectionScreen(isFromSettings: true),
                      ),
                    );
                  },
                ),
                _buildSettingTile(
                  icon: LucideIcons.bell,
                  title: 'Notifications',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Notification settings coming soon')),
                    );
                  },
                ),
                const SizedBox(height: 32),
                Text(
                  'App',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSettingTile(
                  icon: LucideIcons.helpCircle,
                  title: 'Help & Support',
                  onTap: () {},
                ),
                _buildSettingTile(
                  icon: LucideIcons.info,
                  title: 'About FarmGuard AI',
                  onTap: _showAbout,
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(LucideIcons.logOut, color: AppTheme.errorColor),
                    label: Text(
                      'Logout',
                      style: GoogleFonts.outfit(
                        color: AppTheme.errorColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.errorColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildProfileSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.surfaceVariantColor),
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppTheme.primaryStatusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.user, color: AppTheme.primaryStatusColor, size: 35),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name ?? 'Farmer',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _phone ?? '',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _location ?? 'No location set',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: AppTheme.primaryStatusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariantColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.textPrimaryColor, size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.outfit(
            color: AppTheme.textPrimaryColor,
            fontSize: 16,
          ),
        ),
        trailing: const Icon(LucideIcons.chevronRight, color: AppTheme.textSecondaryColor, size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        tileColor: AppTheme.surfaceColor,
      ),
    );
  }
}
