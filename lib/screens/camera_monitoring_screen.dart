import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/ml_service.dart';
import '../services/alert_service.dart';
import '../widgets/bounding_box_painter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'dart:developer';
import '../l10n/app_localizations.dart';

class CameraMonitoringScreen extends StatefulWidget {
  const CameraMonitoringScreen({super.key});

  @override
  State<CameraMonitoringScreen> createState() => _CameraMonitoringScreenState();
}

class _CameraMonitoringScreenState extends State<CameraMonitoringScreen> with SingleTickerProviderStateMixin {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  String? _cameraError;
  late AnimationController _scanAnimationController;
  int _frameCount = 0;
  
  final MLService _mlService = MLService();
  final AlertService _alertService = AlertService();
  final ScreenshotController _screenshotController = ScreenshotController();
  List<dynamic> _recognitions = [];
  bool _isProcessing = false;
  
  bool _recentlyCaptured = false;
  bool _isNightMode = false;
  bool _isFlashOn = false;
  bool _isRepellentActive = false;
  
  // Tracking for suspicious activity
  DateTime? _firstDetectedTime;
  String? _currentlyDetectedClass;
  bool _isSuspicious = false;
  double _theftProbability = 0.0;
  
  // Field selection for logging
  final List<String> _fields = ["Main Field - North", "Apple Orchard", "Rice Field - South", "Storage Area"];
  late String _currentField;

  @override
  void initState() {
    super.initState();
    _currentField = _fields[0];
    _initializeApp();
    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  Future<void> _initializeApp() async {
    // Initialize the camera first so the user sees the preview immediately
    await _initializeCamera();
    
    // Initialize additional services in the background, catching any exceptions
    _mlService.initialize().catchError((e) => log('ML Init Error: $e'));
    _alertService.initialize().catchError((e) => log('Alert Init Error: $e'));
  }

  Future<void> _initializeCamera() async {
    try {
      // 1. Explicitly request required permissions
      Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
        Permission.microphone,
        Permission.location,
        Permission.notification,
      ].request();
      
      if (statuses[Permission.camera] != PermissionStatus.granted) {
        setState(() {
          _cameraError = 'Camera permission denied. Please enable it in settings.';
        });
        log('Camera permission denied.');
        return;
      }
      
      if (statuses[Permission.location] != PermissionStatus.granted) {
        log('Location permission denied. GPS features will be disabled.');
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _cameraError = 'No cameras found on this device.';
        });
        return;
      }

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();
      if (!mounted) return;
      
      setState(() {
        _isCameraInitialized = true;
      });
      
      // Delay before starting image stream to prevent black screen on some Android devices
      await Future.delayed(const Duration(milliseconds: 800));
      
      _frameCount = 0;
      _controller!.startImageStream(_onCameraImage);
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraError = 'Camera Error: $e';
        });
      }
      debugPrint('Camera Initialization Error: $e');
    }
  }

  void _onCameraImage(CameraImage image) {
    _frameCount++;
    if (_frameCount % 10 != 0) return;
        
    if (_isProcessing) return;
    _isProcessing = true;
        
    final results = _mlService.processCameraImage(image);
        
    setState(() {
      _recognitions = results;
    });
        
    if (results.isNotEmpty) {
      final topResult = results.first;
      final detectedClass = topResult['detectedClass'];
          
      // Suspicious activity detection logic
      if (_currentlyDetectedClass == detectedClass) {
        final duration = DateTime.now().difference(_firstDetectedTime!).inSeconds;
        if (duration > 5 && !_isSuspicious) {
          setState(() { _isSuspicious = true; });
          log('SUSPICIOUS ACTIVITY: $detectedClass detected for $duration seconds');
        }
             
        // AI Theft Prediction Logic
        if (detectedClass.contains('Human')) {
          setState(() {
            _theftProbability = (duration / 20.0).clamp(0.0, 1.0) * 100;
          });
        }
      } else {
        _firstDetectedTime = DateTime.now();
        _currentlyDetectedClass = detectedClass;
        _isSuspicious = false;
        setState(() { _theftProbability = 0.0; });
      }

      if (topResult['confidenceInClass'] > 0.6 && !_recentlyCaptured) {
        String label = detectedClass;
            
        // Smart Night Mode: Enable flashlight if it's night and a threat is detected
        if (_isNightMode && !_isFlashOn) {
          _controller?.setFlashMode(FlashMode.torch);
          setState(() { _isFlashOn = true; });
              
          // Turn off after 5 seconds
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted && _isFlashOn) {
              _controller?.setFlashMode(FlashMode.off);
              setState(() { _isFlashOn = false; });
            }
          });
        }
            
        _handleThreatDetection(label);
      }
    } else {
      _currentlyDetectedClass = null;
      _isSuspicious = false;
    }
        
    _isProcessing = false;
  }

  Future<void> _handleThreatDetection(String detectedClass) async {
    _recentlyCaptured = true;
    
    // 1. Capture Image and Start Video Recording
    String? imagePath;
    String? videoPath;
    try {
      final directory = await getApplicationDocumentsDirectory();
      String baseName = 'threat_${DateTime.now().millisecondsSinceEpoch}';
      String fileName = '$baseName.png';
      String videoFileName = '$baseName.mp4';

      // Prefer a real camera still (better quality than UI screenshot).
      if (_controller != null && _controller!.value.isInitialized) {
        try {
          final wasStreaming = _controller!.value.isStreamingImages;
          if (wasStreaming) {
            await _controller!.stopImageStream();
          }
          final XFile still = await _controller!.takePicture();
          final stillFile = File(still.path);
          final targetPath = '${directory.path}/$fileName';
          await stillFile.copy(targetPath);
          imagePath = targetPath;
          log('Captured camera photo at: $imagePath');
          if (wasStreaming) {
            await _controller!.startImageStream(_onCameraImage);
          }
        } catch (e) {
          log('Camera photo capture failed, falling back to screenshot: $e');
        }
      }

      imagePath ??= await _screenshotController.captureAndSave(
        directory.path,
        fileName: fileName,
        delay: const Duration(milliseconds: 100),
      );
      log('Captured image at: $imagePath');

      // Start Video Recording
      if (_controller != null && _controller!.value.isInitialized) {
        await _controller!.startVideoRecording();
        log('Started video recording...');
        
        // Record for 3 seconds
        await Future.delayed(const Duration(seconds: 3));
        
        final XFile videoFile = await _controller!.stopVideoRecording();
        videoPath = videoFile.path;
        log('Stopped video recording. Saved at: $videoPath');
      }
      
      // Upload to Supabase Storage
      final supabase = Supabase.instance.client;
      final uid = supabase.auth.currentUser?.id ?? 'unknown_user';
      
      String? publicImageUrl;
      String? publicVideoUrl;

      if (imagePath != null) {
        final file = File(imagePath);
        final storagePath = '$uid/images/$fileName';
        await supabase.storage.from('threats').upload(storagePath, file);
        publicImageUrl = supabase.storage.from('threats').getPublicUrl(storagePath);
      }

      if (videoPath != null) {
        final vFile = File(videoPath);
        final vStoragePath = '$uid/videos/$videoFileName';
        await supabase.storage.from('threats').upload(vStoragePath, vFile); 
        publicVideoUrl = supabase.storage.from('threats').getPublicUrl(vStoragePath);
      }
      
      // Get precise location for logging
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      } catch (e) {
        log('Could not get GPS for log: $e');
      }

      // Save event to Supabase Database
      await supabase.from('threats').insert({
        'user_id': uid,
        'detected_class': detectedClass,
        'image_url': publicImageUrl,
        'video_url': publicVideoUrl,
        'latitude': position?.latitude,
        'longitude': position?.longitude,
        'field_name': _currentField,
        'status': 'alerted'
      });
      log('Saved threat event, image & video to Supabase ✅');
      
    } catch (e) {
      log('Error in threat detection handling: $e');
    }

    // 2. Trigger the SMS, Voice Alert, & Local Notification
    _alertService.triggerAlert(context, detectedClass, imagePath: imagePath);
    
    // Cooldown before next screenshot capture
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted) _recentlyCaptured = false;
    });
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    _mlService.dispose();
    _alertService.dispose();
    _scanAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Screenshot(
      controller: _screenshotController,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Feed
          if (_cameraError != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  _cameraError!,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          if (_isCameraInitialized && _controller != null)
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                _isNightMode ? Colors.indigo.withOpacity(0.3) : Colors.transparent, 
                BlendMode.darken
              ),
              child: CameraPreview(_controller!),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryStatusColor),
            ),
          
          // Advanced AI Scanner Overlay
          if (_isCameraInitialized) ...[
            AnimatedBuilder(
              animation: _scanAnimationController,
              builder: (context, child) {
                return Positioned(
                  top: MediaQuery.of(context).size.height * _scanAnimationController.value - 100,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppTheme.primaryStatusColor.withOpacity(0.1),
                          AppTheme.primaryStatusColor.withOpacity(0.4),
                        ],
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: 2,
                        color: AppTheme.primaryStatusColor,
                      ),
                    ),
                  ),
                );
              },
            ),
            if (_recognitions.isNotEmpty)
              Positioned.fill(
                child: CustomPaint(
                  painter: BoundingBoxPainter(
                    _recognitions,
                    Size(_controller!.value.previewSize?.height ?? 1, _controller!.value.previewSize?.width ?? 1),
                    MediaQuery.of(context).size,
                  ),
                ),
              ),
          ],
          
          // Right Side Vertical Controls (must be a direct child of Stack)
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 100, right: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSideButton(
                      icon: _isNightMode ? LucideIcons.moon : LucideIcons.sun,
                      label: 'Night',
                      active: _isNightMode,
                      onTap: () => setState(() => _isNightMode = !_isNightMode),
                    ),
                    const SizedBox(height: 16),
                    _buildSideButton(
                      icon: LucideIcons.shieldAlert,
                      label: 'Repel',
                      active: _isRepellentActive,
                      onTap: () async {
                        setState(() => _isRepellentActive = true);
                        await _alertService.triggerAlert(context, 'Ultrasonic Repellent', isRepellent: true);
                        setState(() => _isRepellentActive = false);
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildSideButton(
                      icon: LucideIcons.phoneCall,
                      label: 'SOS',
                      color: AppTheme.errorColor,
                      onTap: () => _alertService.triggerAlert(context, 'EMERGENCY SOS'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // UI Overlays
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          padding: const EdgeInsets.all(12),
                        ),
                        icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _currentField,
                            dropdownColor: AppTheme.surfaceColor,
                            icon: const Icon(LucideIcons.chevronDown, color: Colors.white, size: 16),
                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                            items: _fields.map((String field) {
                              return DropdownMenuItem<String>(
                                value: field,
                                child: Text(field),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _currentField = newValue;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryStatusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.primaryStatusColor, width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.radio, color: AppTheme.primaryStatusColor, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'LIVE AI SCAN',
                              style: GoogleFonts.outfit(
                                color: AppTheme.primaryStatusColor,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: _isFlashOn ? AppTheme.warningColor : Colors.black54,
                          padding: const EdgeInsets.all(12),
                        ),
                        icon: Icon(_isFlashOn ? LucideIcons.flashlight : LucideIcons.flashlightOff, color: Colors.white),
                        onPressed: () {
                          setState(() { _isFlashOn = !_isFlashOn; });
                          _controller?.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
                        },
                      ),
                    ],
                  ),
                ),
                
                // Bottom Controls
                FadeInUp(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: AppTheme.surfaceVariantColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isSuspicious 
                                ? l10n.suspiciousActivity 
                                : (_recognitions.isNotEmpty ? 'THREAT DETECTED' : 'Monitoring Active'),
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _isSuspicious || _recognitions.isNotEmpty ? AppTheme.errorColor : AppTheme.primaryStatusColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _recognitions.isNotEmpty 
                                ? _recognitions.first['detectedClass'].toString()
                                : 'Detecting: Humans, Animals',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                            if (_theftProbability > 0) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    '${l10n.theftProbability}: ',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  Text(
                                    '${_theftProbability.toStringAsFixed(0)}%',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _theftProbability > 50 ? AppTheme.errorColor : AppTheme.warningColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                width: 120,
                                child: LinearProgressIndicator(
                                  value: _theftProbability / 100,
                                  backgroundColor: Colors.white10,
                                  color: _theftProbability > 50 ? AppTheme.errorColor : AppTheme.warningColor,
                                  minHeight: 4,
                                ),
                              ),
                            ],
                          ],
                        ),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _recognitions.isNotEmpty ? AppTheme.errorColor : AppTheme.primaryStatusColor, 
                              width: 2
                            ),
                            color: _recognitions.isNotEmpty ? AppTheme.errorColor.withOpacity(0.2) : Colors.transparent,
                          ),
                          child: Center(
                            child: Icon(
                              _recognitions.isNotEmpty ? LucideIcons.alertTriangle : LucideIcons.shieldCheck, 
                              color: _recognitions.isNotEmpty ? AppTheme.errorColor : AppTheme.primaryStatusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildSideButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
    Color? color,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: active ? (color ?? AppTheme.primaryStatusColor) : Colors.black54,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
