import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' as fln;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'dart:io';
import 'dart:developer';
import 'dart:async';

class AlertService {
  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final fln.FlutterLocalNotificationsPlugin _localNotificationsPlugin = fln.FlutterLocalNotificationsPlugin();
  
  bool _isAlerting = false;
  DateTime? _lastAlertTime;

  // Mock farmer phone number fallback
  final String _mockPhone = "+919876543210";

  Future<String> _getPhone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('farmer_phone') ?? _mockPhone;
    } catch (e) {
      return _mockPhone;
    }
  }

  Future<void> initialize() async {
    try {
      await _flutterTts.setLanguage("en-IN");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      
      // Initialize Notifications
      const fln.AndroidInitializationSettings androidSettings = fln.AndroidInitializationSettings('@mipmap/ic_launcher');
      const fln.InitializationSettings initializationSettings = fln.InitializationSettings(android: androidSettings);
      
      /*
      await _localNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (fln.NotificationResponse response) {
          log('Notification clicked: ${response.payload}');
        },
      );
      */
    } catch (e) {
      log('Init Error: $e');
    }
  }

  Future<void> triggerAlert(BuildContext context, String objectName, {String? imagePath, bool isRepellent = false}) async {
    // Only alert once every 20 seconds to avoid spam (unless it's a manual repellent trigger)
    if (!isRepellent && (_isAlerting || (_lastAlertTime != null && DateTime.now().difference(_lastAlertTime!).inSeconds < 20))) {
      return;
    }

    _isAlerting = true;
    _lastAlertTime = DateTime.now();
    log('Triggering alert for: $objectName');

    try {
      final prefs = await SharedPreferences.getInstance();
      final langCode = prefs.getString('language_code') ?? 'en';
      await _flutterTts.setLanguage(langCode == 'hi' ? 'hi-IN' : (langCode == 'kn' ? 'kn-IN' : 'en-IN'));
      
      // 1. Play sound
      if (isRepellent) {
        // High frequency simulation
        await _audioPlayer.play(AssetSource('sounds/siren.mp3'), volume: 0.6);
      } else {
        await _audioPlayer.play(AssetSource('sounds/siren.mp3'), volume: 1.0);
      }
      
      // 2. Speak TTS Alert (Localized)
      // Map detected class to localization if possible
      String localizedObject = objectName;
      final l10n = AppLocalizations.of(context)!;
      
      if (objectName.toLowerCase().contains('human')) {
        localizedObject = l10n.objHuman;
      } else if (objectName.toLowerCase().contains('cow')) {
        localizedObject = l10n.objCow;
      } else if (objectName.toLowerCase().contains('dog')) {
        localizedObject = l10n.objDog;
      } else if (objectName.toLowerCase().contains('wild')) {
        localizedObject = l10n.objWildAnimal;
      }
      
      final speechMessage = l10n.alertMessage(localizedObject);
      await _flutterTts.speak(speechMessage);
      
      if (!isRepellent) {
        final phone = await _getPhone();
        
        // 3. Show Local Notification
        if (imagePath != null) {
          await _showThreatNotification(objectName, imagePath);
        }
        
        // 4. Trigger SMS
        await _sendSMS(speechMessage, phone);
        
        // 5. Make Emergency Call
        await _makeEmergencyCall(phone);
      }
      
    } catch (e) {
      log('Alert error: $e');
    } finally {
      // Reset alerting state after TTS finishes (approx 4 secs)
      Future.delayed(const Duration(seconds: 4), () {
        _isAlerting = false;
        _audioPlayer.stop();
      });
    }
  }

  Future<void> _showThreatNotification(String objectName, String imagePath) async {
    try {
      // Create BigPictureStyle details to show the captured image in the notification
      final bigPictureStyleInformation = fln.BigPictureStyleInformation(
        fln.FilePathAndroidBitmap(imagePath),
        largeIcon: fln.FilePathAndroidBitmap(imagePath),
        contentTitle: '🚨 FarmGuard Threat Detected!',
        summaryText: 'A $objectName has been detected on your farm.',
      );

      final androidDetails = fln.AndroidNotificationDetails(
        'threat_alerts',
        'Threat Alerts',
        channelDescription: 'Notifications for detected threats',
        importance: fln.Importance.max,
        priority: fln.Priority.high,
        styleInformation: bigPictureStyleInformation,
      );

      /*
      await _localNotificationsPlugin.show(
        DateTime.now().millisecond % 100000,
        '🚨 Threat Detected!',
        'A $objectName has been detected on your farm!',
        fln.NotificationDetails(android: androidDetails),
        payload: imagePath,
      );
      */
    } catch (e) {
      log('Failed to show notification: $e');
    }
  }

  Future<void> _sendSMS(String objectName, String phone) async {
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: <String, String>{
        'body': 'FARMGUARD ALERT: A $objectName has been detected on your farm! Check the app immediately.',
      },
    );
    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      }
    } catch (e) {
      log('Could not launch SMS: $e');
    }
  }

  Future<void> _makeEmergencyCall(String phone) async {
    final Uri callUri = Uri(
      scheme: 'tel',
      path: phone,
    );
    try {
      if (await canLaunchUrl(callUri)) {
        await launchUrl(callUri);
      }
    } catch (e) {
      log('Could not launch Phone: $e');
    }
  }

  Future<void> playUltrasonicSound() async {
    try {
      // Simulate ultrasonic sound with a high-pitched repellent sound
      await _audioPlayer.play(AssetSource('sounds/siren.mp3'), volume: 1.0);
      await Future.delayed(const Duration(seconds: 3));
      await _audioPlayer.stop();
    } catch (e) {
      log('Repellent error: $e');
    }
  }

  void dispose() {
    _flutterTts.stop();
    _audioPlayer.dispose();
  }
}
