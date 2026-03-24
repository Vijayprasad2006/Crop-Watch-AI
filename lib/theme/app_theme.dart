import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryStatusColor = Color(0xFF00C853); // Bright Green
  static const Color primaryDarkColor = Color(0xFF003013); 
  static const Color accentColor = Color(0xFFB2FF59);
  
  // Background Colors
  static const Color backgroundColor = Color(0xFF0A0F0D); // Deep dark green/black
  static const Color surfaceColor = Color(0xFF1E2822); // Slightly lighter surface
  static const Color surfaceVariantColor = Color(0xFF2C3931);

  // Text Colors
  static const Color textPrimaryColor = Color(0xFFFFFFFF);
  static const Color textSecondaryColor = Color(0xFFA0AAB2);

  // Alert Colors
  static const Color errorColor = Color(0xFFFF3D00);
  static const Color warningColor = Color(0xFFFFC107);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryStatusColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryStatusColor,
        secondary: accentColor,
        surface: surfaceColor,
        surfaceContainerHighest: surfaceVariantColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: textPrimaryColor,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: textPrimaryColor),
        displayMedium: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: textPrimaryColor),
        titleLarge: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w600, color: textPrimaryColor),
        bodyLarge: GoogleFonts.outfit(fontSize: 16, color: textPrimaryColor),
        bodyMedium: GoogleFonts.outfit(fontSize: 14, color: textSecondaryColor),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: surfaceVariantColor, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryStatusColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimaryColor),
        iconTheme: const IconThemeData(color: textPrimaryColor),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariantColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryStatusColor, width: 2),
        ),
        labelStyle: GoogleFonts.outfit(color: textSecondaryColor),
        hintStyle: GoogleFonts.outfit(color: textSecondaryColor),
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      ),
    );
  }

  static InputDecoration inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: textSecondaryColor),
    );
  }
}
