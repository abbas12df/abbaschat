import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ============================================================================
  // BRAND COLORS (Enhanced for better contrast and aesthetics)
  // ============================================================================
  static const Color primaryBrand = Color(0xFF6C63FF); // Modern Indigo
  static const Color primaryBrandLight = Color(0xFF8B84FF); // Lighter variant
  static const Color primaryBrandDark = Color(0xFF5A52E5); // Darker variant
  static const Color secondaryBrand = Color(0xFF00BFA5); // Teal Accent
  static const Color secondaryBrandLight = Color(0xFF33D4C1); // Lighter variant
  static const Color secondaryBrandDark = Color(0xFF009688); // Darker variant

  // ============================================================================
  // DARK MODE SEMANTIC COLORS
  // ============================================================================

  // Backgrounds & Surfaces (Layered for depth)
  static const Color darkBackground = Color(0xFF0D1117); // Base background
  static const Color darkSurface = Color(
    0xFF21262D,
  ); // Elevated surface (Lighter)
  static const Color darkSurfaceVariant = Color(
    0xFF30363D,
  ); // Cards, dialogs (Lighter)
  static const Color darkSurfaceHigh = Color(0xFF484F58); // Highest elevation

  // Text Hierarchy (High Contrast for Accessibility)
  static const Color darkTextPrimary = Colors.white; // Pure White
  static const Color darkTextSecondary = Color(
    0xFFE6EDF3,
  ); // White-ish (was too dark)
  static const Color darkTextTertiary = Color(0xFF8B949E); // Light Gray

  // Icons (High Visibility)
  static const Color darkIconColor = Colors.white; // Pure White for icons

  // Borders & Dividers
  static const Color darkBorder = Color(0xFF30363D); // Subtle borders
  static const Color darkDivider = Color(0xFF30363D); // Divider lines

  // Interactive States
  static const Color darkHover = Color(0xFF30363D); // Hover state
  static const Color darkPressed = Color(0xFF21262D); // Pressed state
  static const Color darkSelected = Color(0xFF1C2128); // Selected state

  // Status Colors
  static const Color darkSuccess = Color(0xFF3FB950); // Success/online
  static const Color darkWarning = Color(0xFFD29922); // Warning
  static const Color darkError = Color(0xFFF85149); // Error/offline
  static const Color darkInfo = Color(0xFF58A6FF); // Info

  // ============================================================================
  // MESSAGE BUBBLE COLORS
  // ============================================================================

  // Sent messages (user)
  static const Color myMessageStart = Color(0xFF0084FF);
  static const Color myMessageEnd = Color(0xFF0066CC);
  static const Color myMessageText = Colors.white;
  static const Color myMessageDarkBg = Color(0xFF1C2128);
  static const Color myMessageDarkText = Color(0xFFE6EDF3);

  // Received messages (other)
  static const Color otherMessageLight = Color(0xFFF0F0F0);
  static const Color otherMessageDark = Color(0xFF21262D);
  static const Color otherMessageTextLight = Color(0xFF1F2328);
  static const Color otherMessageTextDark = Color(0xFFE6EDF3);

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  static TextTheme _buildTextTheme(TextTheme base, Color color) {
    return GoogleFonts.cairoTextTheme(
      base,
    ).apply(displayColor: color, bodyColor: color);
  }

  // ============================================================================
  // LIGHT THEME
  // ============================================================================

  static ThemeData lightTheme() {
    final ColorScheme colorScheme = ColorScheme.light(
      primary: primaryBrand,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFE6E3FF),
      onPrimaryContainer: Color(0xFF1F1A4D),
      secondary: secondaryBrand,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFB2F5EA),
      onSecondaryContainer: Color(0xFF003D33),
      surface: Colors.white,
      onSurface: Color(0xFF1F2328),
      surfaceVariant: Color(0xFFF6F8FA),
      onSurfaceVariant: Color(0xFF57606A),
      background: Colors.white,
      onBackground: Color(0xFF1F2328),
      error: Color(0xFFCF222E),
      onError: Colors.white,
      errorContainer: Color(0xFFFFEBEE),
      onErrorContainer: Color(0xFF8B0000),
      outline: Color(0xFFD0D7DE),
      outlineVariant: Color(0xFFE5E7EB),
      shadow: Colors.black,
      scrim: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.white,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1F2328),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        iconTheme: IconThemeData(color: Color(0xFF1F2328)),
        titleTextStyle: TextStyle(
          color: Color(0xFF1F2328),
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Card
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: Color(0xFFE5E7EB),
        thickness: 1,
        space: 1,
      ),

      // Icon
      iconTheme: IconThemeData(color: Color(0xFF57606A), size: 24),

      // Text
      textTheme: _buildTextTheme(
        ThemeData.light().textTheme,
        Color(0xFF1F2328),
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBrand,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFFF6F8FA),
        hintStyle: TextStyle(color: Color(0xFF57606A)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryBrand, width: 2),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),

      // ListTile
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: Color(0xFFF6F8FA),
        iconColor: Color(0xFF57606A),
        textColor: Color(0xFF1F2328),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: TextStyle(
          color: Color(0xFF1F2328),
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(color: Color(0xFF57606A), fontSize: 14),
      ),

      // Bottom Sheet
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Color(0xFF1F2328),
        contentTextStyle: TextStyle(color: Colors.white),
        actionTextColor: primaryBrand,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: Color(0xFFF6F8FA),
        selectedColor: primaryBrand,
        disabledColor: Color(0xFFE5E7EB),
        labelStyle: TextStyle(color: Color(0xFF1F2328)),
        secondaryLabelStyle: TextStyle(color: Color(0xFF57606A)),
        side: BorderSide(color: Color(0xFFD0D7DE)),
      ),
    );
  }

  // ============================================================================
  // DARK THEME (ENHANCED)
  // ============================================================================

  static ThemeData darkTheme() {
    final ColorScheme colorScheme = ColorScheme.dark(
      // Primary colors
      primary: primaryBrand,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF4A42CC),
      onPrimaryContainer: darkTextPrimary,

      // Secondary colors
      secondary: secondaryBrand,
      onSecondary: Colors.black,
      secondaryContainer: Color(0xFF008C7A),
      onSecondaryContainer: darkTextPrimary,

      // Surfaces
      surface: darkSurface,
      onSurface: darkTextPrimary,
      surfaceVariant: darkSurfaceVariant,
      onSurfaceVariant: darkTextSecondary,

      // Backgrounds
      background: darkBackground,
      onBackground: darkTextPrimary,

      // Errors
      error: darkError,
      onError: Colors.white,
      errorContainer: Color(0xFF8B2E24),
      onErrorContainer: Color(0xFFFFCCCB),

      // Outlines & Borders
      outline: darkBorder,
      outlineVariant: darkDivider,

      // Shadows & Overlays
      shadow: Colors.black,
      scrim: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkBackground,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        iconTheme: IconThemeData(color: darkTextPrimary),
        titleTextStyle: TextStyle(
          color: darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Card
      cardTheme: CardThemeData(
        color: darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: darkBorder, width: 1),
        ),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: darkDivider,
        thickness: 1,
        space: 1,
      ),

      // Icon (Brighter for better visibility)
      iconTheme: IconThemeData(color: darkIconColor, size: 24),

      // Text
      textTheme: TextTheme(
        displayLarge: TextStyle(color: darkTextPrimary),
        displayMedium: TextStyle(color: darkTextPrimary),
        displaySmall: TextStyle(color: darkTextPrimary),
        headlineLarge: TextStyle(color: darkTextPrimary),
        headlineMedium: TextStyle(color: darkTextPrimary),
        headlineSmall: TextStyle(color: darkTextPrimary),
        titleLarge: TextStyle(color: darkTextPrimary),
        titleMedium: TextStyle(color: darkTextPrimary),
        titleSmall: TextStyle(color: darkTextPrimary),
        bodyLarge: TextStyle(color: darkTextPrimary),
        bodyMedium: TextStyle(color: darkTextPrimary),
        bodySmall: TextStyle(color: darkTextSecondary),
        labelLarge: TextStyle(color: darkTextPrimary),
        labelMedium: TextStyle(color: darkTextSecondary),
        labelSmall: TextStyle(color: darkTextTertiary),
      ).apply(fontFamily: GoogleFonts.cairo().fontFamily),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBrand,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primaryBrand),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkTextPrimary,
          side: BorderSide(color: darkBorder),
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        hintStyle: TextStyle(color: darkTextTertiary),
        labelStyle: TextStyle(color: darkTextSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryBrand, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: darkError),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),

      // ListTile
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: darkSelected,
        iconColor: darkIconColor, // Brighter icons
        textColor: darkTextPrimary,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: TextStyle(
          color: darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(color: darkTextSecondary, fontSize: 14),
      ),

      // Bottom Sheet
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: darkSurface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkSurfaceHigh,
        contentTextStyle: TextStyle(color: darkTextPrimary),
        actionTextColor: primaryBrand,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: darkSurfaceVariant,
        selectedColor: primaryBrand,
        disabledColor: darkSurface,
        labelStyle: TextStyle(color: darkTextPrimary),
        secondaryLabelStyle: TextStyle(color: darkTextSecondary),
        side: BorderSide(color: darkBorder),
      ),

      // Popup Menu
      popupMenuTheme: PopupMenuThemeData(
        color: darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: TextStyle(color: darkTextPrimary),
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryBrand;
          }
          return darkTextTertiary;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryBrand.withValues(alpha: 0.5);
          }
          return darkBorder;
        }),
      ),

      // Checkbox
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryBrand;
          }
          return Colors.transparent;
        }),
        checkColor: MaterialStateProperty.all(Colors.white),
        side: BorderSide(color: darkBorder, width: 2),
      ),

      // Radio
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryBrand;
          }
          return darkBorder;
        }),
      ),

      // Progress Indicator
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primaryBrand,
        linearTrackColor: darkBorder,
        circularTrackColor: darkBorder,
      ),

      // Floating Action Button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryBrand,
        foregroundColor: Colors.white,
        elevation: 6,
      ),
    );
  }
}
