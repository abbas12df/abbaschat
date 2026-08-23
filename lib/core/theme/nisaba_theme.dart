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
  static const Color darkAction = Color(0xFFA5B4FC);

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
  static const Color lightBackground = Color(
    0xFFF8FAFC,
  ); // Very light blue/gray
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF1F5F9);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextTertiary = Color(0xFF94A3B8);
  static const Color lightDivider = Color(0xFFE2E8F0);

  // ============================================================================
  // DARK MODE
  // ============================================================================
  static const Color darkBackground = Color(0xFF0B0F19); // Deep dark blue
  static const Color darkSurface = Color(0xFF131B2F);
  static const Color darkSurfaceVariant = Color(0xFF1E293B);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkTextTertiary = Color(0xFFA8B7CB);
  static const Color darkDivider = Color(0xFF334155);

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
  static const double radiusS = 12;
  static const double radiusM = 16;
  static const double radiusL = 20;
  static const double radiusXL = 28;

  // ============================================================================
  // SHADOWS (Soft / Glowing)
  // ============================================================================
  static List<BoxShadow> get softShadowLight => [
    BoxShadow(
      color: const Color(0xFF64748B).withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get softShadowDark => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 24,
      offset: const Offset(0, 8),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> primaryGlow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.3),
      blurRadius: 16,
      offset: const Offset(0, 6),
      spreadRadius: 0,
    ),
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
      onSecondary: Color(0xFF042F2E),
      secondaryContainer: Color(0xFFCCFBF1),
      onSecondaryContainer: Color(0xFF134E4A),
      tertiary: accent,
      onTertiary: Color(0xFF4C0519),
      surface: lightSurface,
      onSurface: lightTextPrimary,
      onSurfaceVariant: Color(0xFF475569),
      surfaceContainerLowest: Color(0xFFFAFCFF),
      surfaceContainerLow: Color(0xFFF8FAFC),
      surfaceContainer: Color(0xFFF1F5F9),
      surfaceContainerHigh: Color(0xFFE8EEF6),
      surfaceContainerHighest: lightSurfaceVariant,
      error: error,
      onError: Colors.white,
      outline: Color(0xFFCBD5E1),
      outlineVariant: Color(0xFFE2E8F0),
      shadow: Color(0x240F172A),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: lightBackground,
      textTheme: _buildTextTheme(lightTextPrimary, lightTextSecondary),

      // AppBar: consistent surface with a subtle hierarchy edge.
      appBarTheme: AppBarTheme(
        backgroundColor: lightBackground,
        foregroundColor: lightTextPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
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

      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E8F0),
        thickness: 1,
        space: 1,
      ),

      iconTheme: const IconThemeData(color: lightTextSecondary, size: 24),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: lightTextSecondary,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.all(10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 10,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: lightTextSecondary,
        textColor: lightTextPrimary,
        tileColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurfaceVariant,
        labelStyle: GoogleFonts.tajawal(
          color: lightTextSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: GoogleFonts.tajawal(
          color: lightTextTertiary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
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
        modalBackgroundColor: lightSurface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXL)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusL),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: darkBackground,
        contentTextStyle: GoogleFonts.tajawal(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: primaryLight,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.all(16),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: Color(0xFFE2E8F0),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightSurface,
        indicatorColor: Color(0xFFE0E7FF),
        labelTextStyle: MaterialStatePropertyAll<TextStyle>(
          TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightSurfaceVariant,
        selectedColor: primary,
        disabledColor: lightSurfaceVariant.withValues(alpha: 0.5),
        labelStyle: GoogleFonts.tajawal(
          color: lightTextPrimary,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: GoogleFonts.tajawal(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: lightSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.tajawal(
          color: lightTextPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusM),
          ),
          textStyle: GoogleFonts.tajawal(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          foregroundColor: primaryDark,
          side: const BorderSide(color: Color(0xFFCBD5E1)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusM),
          ),
          textStyle: GoogleFonts.tajawal(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          foregroundColor: primaryDark,
          textStyle: GoogleFonts.tajawal(fontWeight: FontWeight.w700),
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
      primary: darkAction,
      onPrimary: Color(0xFF1E1B4B),
      primaryContainer: Color(0xFF4338CA),
      onPrimaryContainer: Color(0xFFF5F7FF),
      secondary: secondary,
      onSecondary: Color(0xFF042F2E),
      secondaryContainer: Color(0xFF115E59),
      onSecondaryContainer: Color(0xFFCCFBF1),
      tertiary: accent,
      onTertiary: Color(0xFFFFE4E6),
      surface: darkSurface,
      onSurface: darkTextPrimary,
      onSurfaceVariant: Color(0xFFE2E8F0),
      surfaceContainerLowest: Color(0xFF080B12),
      surfaceContainerLow: Color(0xFF0F1523),
      surfaceContainer: Color(0xFF131B2F),
      surfaceContainerHigh: Color(0xFF1A263A),
      surfaceContainerHighest: Color(0xFF2A3A55),
      error: error,
      onError: Colors.white,
      outline: Color(0xFF64748B),
      outlineVariant: Color(0xFF526581),
      shadow: Color(0x66000000),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkBackground,
      textTheme: _buildTextTheme(darkTextPrimary, darkTextSecondary),

      appBarTheme: AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: darkTextPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
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
          side: BorderSide(color: Color(0xFF526581), width: 0.8),
        ),
        margin: EdgeInsets.zero,
      ),

      dividerTheme: const DividerThemeData(
        color: Color(0xFF334155),
        thickness: 1,
        space: 1,
      ),

      iconTheme: const IconThemeData(color: darkTextSecondary, size: 24),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: darkTextSecondary,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.all(10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 10,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: darkTextSecondary,
        textColor: darkTextPrimary,
        tileColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.disabled)) {
            return const Color(0xFF64748B);
          }
          if (states.contains(MaterialState.selected)) {
            return colorScheme.onPrimary;
          }
          return darkTextPrimary;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.disabled)) {
            return const Color(0xFF1E293B);
          }
          if (states.contains(MaterialState.selected)) {
            return colorScheme.primary;
          }
          return const Color(0xFF334155);
        }),
        trackOutlineColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return colorScheme.primary;
          }
          return const Color(0xFF64748B);
        }),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFF1B2940),
        labelStyle: GoogleFonts.tajawal(
          color: darkTextSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: GoogleFonts.tajawal(
          color: darkTextTertiary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF526581)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF526581)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: darkAction, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: space24,
          vertical: 18,
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        modalBackgroundColor: darkSurface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXL)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusL),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: darkSurfaceVariant,
        contentTextStyle: GoogleFonts.tajawal(
          color: darkTextPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: primaryLight,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.all(16),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: darkAction,
        linearTrackColor: Color(0xFF526581),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        indicatorColor: Color(0xFF5146CD),
        labelTextStyle: MaterialStatePropertyAll<TextStyle>(
          TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Color(0xFF243653),
        selectedColor: Color(0xFF5146CD),
        disabledColor: darkSurfaceVariant.withValues(alpha: 0.5),
        labelStyle: GoogleFonts.tajawal(
          color: darkTextPrimary,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: GoogleFonts.tajawal(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        side: const BorderSide(color: Color(0xFF475569)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.tajawal(
          color: darkTextPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          backgroundColor: primaryDark,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusM),
          ),
          textStyle: GoogleFonts.tajawal(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          foregroundColor: primaryLight,
          side: const BorderSide(color: Color(0xFF475569)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusM),
          ),
          textStyle: GoogleFonts.tajawal(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          foregroundColor: primaryLight,
          textStyle: GoogleFonts.tajawal(fontWeight: FontWeight.w700),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusL),
        ),
      ),
    );
  }
}
