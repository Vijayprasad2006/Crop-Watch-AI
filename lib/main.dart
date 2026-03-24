import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer';
import 'package:provider/provider.dart';
import 'services/locale_provider.dart';
import 'l10n/app_localizations.dart';
import 'theme/app_theme.dart';
import 'screens/language_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Supabase.initialize(
      url: 'https://opfitfilznxlfuuglmrv.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9wZml0Zmlsem54bGZ1dWdsbXJ2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM1NDEyNDgsImV4cCI6MjA4OTExNzI0OH0.kczvH-wFp5bf0u39Ew-A8TPna7S_nYHHibFYC0Lr1NU',
    );
    log('Supabase Initialized Successfully');
  } catch (e) {
    log('Supabase Init Error: $e');
  }
  
  final prefs = await SharedPreferences.getInstance();
  final String savedLangCode = prefs.getString('language_code') ?? '';

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider(savedLangCode)),
      ],
      child: const FarmGuardApp(),
    ),
  );
}

class FarmGuardApp extends StatelessWidget {
  const FarmGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;

    return MaterialApp(
      title: 'FarmGuard AI',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.darkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: localeProvider.locale,
      home: session != null 
          ? const DashboardScreen() 
          : LanguageSelectionScreen(),
    );
  }
}
