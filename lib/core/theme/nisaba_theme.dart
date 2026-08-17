import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Nisaba Design System - Bubbly Premium Edition
class NisabaTheme {
  NisabaTheme._();

  // ============================================================================
  // BRAND COLORS (Vibrant & Premium)
  // ============================================================================
  static const Color primary = Color(0xFF6366F1); // Indigo Vibrant
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF4338CA);
  
  static const Color secondary = Color(0xFF14B8A6); // Teal Vibrant
  static const Color accent = Color(0xFFF43F5E); // Rose

  // ============================================================================
  // STATUS COLORS
  // ============================================================================
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // ============================================================================
  // LIGHT MODE
  // ============================================================================
  static const Color lightBackground = Color(0xFFF8FAFC); // Very light blue/gray
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF1F5F9);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextTertiary = Color(0xFF94A3B8);
  static const Color lightDivider = Colors.transparent; // No dividers in bubbly UI

  // ============================================================================
  // DARK MODE
  // ============================================================================
  static const Color darkBackground = Color(0xFF0B0F19); // Deep dark blue
  static const Color darkSurface = Color(0xFF131B2F);
  static const Color darkSurfaceVariant = Color(0xFF1E293B);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextTertiary = Color(0xFF64748B);
  static const Color darkDivider = Colors.transparent;

  // ============================================================================
  // SPACING SCALE
  // ============================================================================
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space48 = 48;

  // ============================================================================
  // RADII (Bubbly / Squircle style)
  // ============================================================================
  static const double radiusS = 16;
  static const double radiusM = 20;
  static const double radiusL = 24;
  static const double radiusXL = 32;

  // ============================================================================
  // SHADOWS (Soft / Glowing)
  // ============================================================================
  static List<BoxShadow> get softShadowLight => [
        BoxShadow(
          color: const Color(0xFF64748B).withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
          spreadRadius: 0,
        )
      ];

  static List<BoxShadow> get softShadowDark => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 24,
          offset: const Offset(0, 8),
          spreadRadius: 0,
        )
      ];

  static List<BoxShadow> primaryGlow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.3),
          blurRadius: 16,
          offset: const Offset(0, 6),
          spreadRadius: 0,
        )
      ];

  // ============================================================================
  // TYPOGRAPHY (Bold, Playful yet professional)
  // ============================================================================
  static TextTheme _buildTextTheme(Color primaryText, Color secondaryText) {
    return GoogleFonts.tajawalTextTheme().copyWith(
      displayLarge: GoogleFonts.tajawal(
        color: primaryText,
        fontSize: 34,
        fontWeight: FontWeight.w900,
        height: 1.2,
      ),
      displayMedium: GoogleFonts.tajawal(
        color: primaryText,
        fontSize: 28,
        fontWeight: FontWeight.w800,
        height: 1.2,
      ),
      displaySmall: GoogleFonts.tajawal(
        color: primaryText,
        fontSize: 24,
        fontWeight: FontWeight.w800,
        height: 1.3,
      ),
      headlineLarge: GoogleFonts.tajawal(
        color: primaryText,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      headlineMedium: GoogleFonts.tajawal(
        color: primaryText,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      headlineSmall: GoogleFonts.tajawal(
        color: primaryText,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.4,
      ),
      titleLarge: GoogleFonts.tajawal(
        color: primaryText,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        height: 1.4,
      ),
      titleMedium: GoogleFonts.tajawal(
        color: primaryText,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      titleSmall: GoogleFonts.tajawal(
        color: primaryText,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      bodyLarge: GoogleFonts.tajawal(
        color: primaryText,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.tajawal(
        color: primaryText,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.5,
      ),
      bodySmall: GoogleFonts.tajawal(
        color: secondaryText,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.4,
      ),
      labelLarge: GoogleFonts.tajawal(
        color: primaryText,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.4,
      ),
      labelMedium: GoogleFonts.tajawal(
        color: secondaryText,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      labelSmall: GoogleFonts.tajawal(
        color: secondaryText,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
    );
  }

  // ============================================================================
  // LIGHT THEME
  // ============================================================================
  static ThemeData lightTheme() {
    const colorScheme = ColorScheme.light(
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFE0E7FF),
      onPrimaryContainer: primaryDark,
      secondary: secondary,
      onSecondary: Colors.white,
      surface: lightSurface,
      onSurface: lightTextPrimary,
      surfaceContainerHighest: lightSurfaceVariant,
      error: error,
      onError: Colors.white,
      outline: Colors.transparent, // No hard borders
      outlineVariant: Colors.transparent,
      shadow: Color(0x0F000000),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: lightBackground,
      textTheme: _buildTextTheme(lightTextPrimary, lightTextSecondary),

      // AppBar - transparent, floating feeling
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.tajawal(
          color: lightTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusL),
        ),
        margin: EdgeInsets.zero,
      ),

      // Divider - hidden
      dividerTheme: const DividerThemeData(
        color: Colors.transparent,
        thickness: 0,
        space: 16,
      ),

      // Icons
      iconTheme: const IconThemeData(
        color: lightTextSecondary,
        size: 24,
      ),

      // Inputs - Capsule shaped (Pill)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurfaceVariant,
        hintStyle: GoogleFonts.tajawal(
          color: lightTextTertiary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100), // Pill shape
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: space24,
          vertical: 18,
        ),
      ),

      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXL)),
        ),
      ),
      
      // Floating Action Button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusL),
        ),
      ),
    );
  }

  // ============================================================================
  // DARK THEME
  // ============================================================================
  static ThemeData darkTheme() {
    const colorScheme = ColorScheme.dark(
      primary: primaryLight,
      onPrimary: Colors.white,
      primaryContainer: primaryDark,
      onPrimaryContainer: Colors.white,
      secondary: secondary,
      onSecondary: Colors.white,
      surface: darkSurface,
      onSurface: darkTextPrimary,
      surfaceContainerHighest: darkSurfaceVariant,
      error: error,
      onError: Colors.white,
      outline: Colors.transparent,
      outlineVariant: Colors.transparent,
      shadow: Color(0x33000000),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkBackground,
      textTheme: _buildTextTheme(darkTextPrimary, darkTextSecondary),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.tajawal(
          color: darkTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),

      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusL),
        ),
        margin: EdgeInsets.zero,
      ),

      dividerTheme: const DividerThemeData(
        color: Colors.transparent,
        thickness: 0,
        space: 16,
      ),

      iconTheme: const IconThemeData(
        color: darkTextSecondary,
        size: 24,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceVariant,
        hintStyle: GoogleFonts.tajawal(
          color: darkTextTertiary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: const BorderSide(color: primaryLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: space24,
          vertical: 18,
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXL)),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryLight,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusL),
        ),
      ),
    );
  }
}
