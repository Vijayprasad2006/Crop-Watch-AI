import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import 'camera_monitoring_screen.dart';
import 'alert_history_screen.dart';
import 'settings_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/alert_service.dart';
import 'dart:async';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedField = "Main Field - North";
  final List<String> _fields = ["Main Field - North", "East Orchard", "Vegetable Patch"];
  // State for real data
  int _detectionsToday = 0;
  String _lastDetected = 'No threats detected today';
  bool _isLoadingCount = true;

  final AlertService _alertService = AlertService();
  RealtimeChannel? _threatsChannel;
  Timer? _pollingTimer;
  int _lastKnownCount = 0;

  @override
  void initState() {
    super.initState();
    _alertService.initialize();
    _fetchStats(initial: true);
    _setupRealtimeListener();
    
    // Fallback: Poll every 5 seconds in case Supabase Realtime Replication is disabled on this table
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchStats());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _threatsChannel?.unsubscribe();
    _alertService.dispose();
    super.dispose();
  }

  void _setupRealtimeListener() {
    final supabase = Supabase.instance.client;
    // Listen for new rows in the threats table
    _threatsChannel = supabase.channel('public:threats').onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'threats',
      callback: (payload) {
        final newRecord = payload.newRecord;
        if (newRecord != null) {
          final detectedClass = newRecord['detected_class'] as String? ?? 'Unknown Object';
          final imageUrl = newRecord['image_url'] as String?;
          
          if (mounted) {
            _alertService.triggerAlert(context, detectedClass, imagePath: imageUrl);
            // Refresh stats on dashboard
            _fetchStats();
          }
        }
      },
    ).subscribe();
  }

  Future<void> _fetchStats({bool initial = false}) async {
    try {
      final supabase = Supabase.instance.client;
      final uid = supabase.auth.currentUser?.id;
      
      if (uid == null) return;

      // Get start of today
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day).toIso8601String();

      final response = await supabase
          .from('threats')
          .select()
          .gte('created_at', today)
          .order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          final newCount = response.length;
          
          // If polling noticed a new threat that Realtime missed, trigger the alert!
          if (!initial && newCount > _lastKnownCount && response.isNotEmpty) {
             final latest = response.first;
             final detectedClass = latest['detected_class'] as String? ?? 'Unknown Object';
             final imageUrl = latest['image_url'] as String?;
             _alertService.triggerAlert(context, detectedClass, imagePath: imageUrl);
          }
          
          _detectionsToday = newCount;
          _lastKnownCount = newCount;
          
          if (response.isNotEmpty) {
            final last = response.first;
            final detectedAt = DateTime.parse(last['created_at']);
            final timeStr = "${detectedAt.hour}:${detectedAt.minute.toString().padLeft(2, '0')}";
            _lastDetected = "${last['detected_class']} at $timeStr";
          }
          _isLoadingCount = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching stats: $e');
      if (mounted) {
        setState(() { _isLoadingCount = false; });
      }
    }
  }

  String _calculateTheftRisk() {
    if (_detectionsToday == 0) return 'LOW';
    
    final now = DateTime.now();
    bool isNight = now.hour >= 20 || now.hour <= 5;
    
    if (_detectionsToday > 10) return 'CRITICAL';
    if (_detectionsToday > 5 || (isNight && _detectionsToday > 2)) return 'HIGH';
    if (_detectionsToday > 2 || isNight) return 'MEDIUM';
    
    return 'LOW';
  }

  Color _getRiskColor(String risk) {
    switch (risk) {
      case 'CRITICAL': return AppTheme.errorColor;
      case 'HIGH': return AppTheme.errorColor;
      case 'MEDIUM': return AppTheme.warningColor;
      default: return AppTheme.primaryStatusColor;
    }
  }

  void _startMonitoring() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CameraMonitoringScreen()),
    ).then((_) => _fetchStats()); // Refresh stats when coming back
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Dashboard'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.bell),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AlertHistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FadeInDown(
                    child: Text(
                      'Farm Status',
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.surfaceVariantColor),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedField,
                      underline: const SizedBox(),
                      dropdownColor: AppTheme.surfaceColor,
                      items: _fields.map((String field) {
                        return DropdownMenuItem(value: field, child: Text(field, style: GoogleFonts.outfit(fontSize: 14)));
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedField = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FadeInUp(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatusCard(
                        title: 'Theft Risk',
                        value: _calculateTheftRisk(),
                        icon: LucideIcons.shieldAlert,
                        color: _getRiskColor(_calculateTheftRisk()),
                        subtitle: 'AI Predicted Trends',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FadeInUp(
                child: _buildStatusCard(
                  title: 'Camera Status',
                  value: 'Inactive',
                  icon: LucideIcons.cameraOff,
                  color: AppTheme.errorColor,
                ),
              ),
              const SizedBox(height: 16),
              FadeInUp(
                delay: const Duration(milliseconds: 100),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatusCard(
                        title: 'Detections Today',
                        value: _detectionsToday.toString(),
                        icon: LucideIcons.scanLine,
                        color: AppTheme.warningColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FadeInUp(
                delay: const Duration(milliseconds: 200),
                child: _buildStatusCard(
                  title: 'Last Event',
                  value: _lastDetected,
                  icon: LucideIcons.alertTriangle,
                  color: AppTheme.primaryStatusColor,
                ),
              ),
              const SizedBox(height: 48),
              FadeInUp(
                delay: const Duration(milliseconds: 300),
                child: Column(
                  children: [
                    SizedBox(
                      height: 80,
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _startMonitoring,
                        icon: const Icon(LucideIcons.power, size: 32),
                        label: const Text('START MONITORING', style: TextStyle(fontSize: 22, letterSpacing: 1.2)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryStatusColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 8,
                          shadowColor: AppTheme.primaryStatusColor.withOpacity(0.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 60,
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                           // Global Emergency Call
                        },
                        icon: const Icon(LucideIcons.phoneCall, color: AppTheme.errorColor),
                        label: Text('EMERGENCY SOS', style: GoogleFonts.outfit(color: AppTheme.errorColor, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.errorColor, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
    );
  }

  Widget _buildStatusCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.surfaceVariantColor, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    color: AppTheme.textPrimaryColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(color: AppTheme.textSecondaryColor.withOpacity(0.7), fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
