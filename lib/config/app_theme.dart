import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryBlue = Color(0xFF1A56DB);
  static const Color primaryDark = Color(0xFF1E3A5F);
  static const Color accentTeal = Color(0xFF0EA5E9);
  static const Color surfaceGray = Color(0xFFF8FAFC);

  static ThemeData get lightTheme {
    final interText = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      textTheme: interText.copyWith(
        displayLarge: interText.displayLarge?.copyWith(fontSize: 32, fontWeight: FontWeight.w700, color: primaryDark),
        headlineLarge: interText.headlineLarge?.copyWith(fontSize: 26, fontWeight: FontWeight.w700, color: primaryDark),
        headlineMedium: interText.headlineMedium?.copyWith(fontSize: 22, fontWeight: FontWeight.w600, color: primaryDark),
        headlineSmall: interText.headlineSmall?.copyWith(fontSize: 18, fontWeight: FontWeight.w600, color: primaryDark),
        titleLarge: interText.titleLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: primaryDark),
        titleMedium: interText.titleMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: primaryDark),
        titleSmall: interText.titleSmall?.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: primaryDark),
        bodyLarge: interText.bodyLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w400, color: const Color(0xFF334155), height: 1.5),
        bodyMedium: interText.bodyMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w400, color: const Color(0xFF334155), height: 1.5),
        bodySmall: interText.bodySmall?.copyWith(fontSize: 12, fontWeight: FontWeight.w400, color: const Color(0xFF475569), height: 1.45),
        labelLarge: interText.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: primaryDark),
        labelMedium: interText.labelMedium?.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: primaryDark),
        labelSmall: interText.labelSmall?.copyWith(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.light,
        primary: primaryBlue,
        secondary: accentTeal,
        surface: Colors.white,
        surfaceVariant: const Color(0xFFF1F5F9),
        background: surfaceGray,
        onSurfaceVariant: const Color(0xFF475569),
        outline: const Color(0xFFCBD5E1),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: primaryDark,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: primaryDark,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        color: Colors.white,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side: const BorderSide(color: primaryBlue),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        labelStyle: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
        hintStyle: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF94A3B8)),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E8F0),
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    final interText = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      textTheme: interText,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.dark,
        primary: const Color(0xFF60A5FA),
        secondary: accentTeal,
        surface: const Color(0xFF1E293B),
        surfaceVariant: const Color(0xFF0F172A),
        background: const Color(0xFF0F172A),
        onSurfaceVariant: const Color(0xFF94A3B8),
        outline: const Color(0xFF334155),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
