import 'package:flutter/material.dart';
import 'nisaba_theme.dart';

/// Helper class for consistent theme-aware color usage
class ThemeHelper {
  /// Get primary color with theme awareness
  static Color primaryColor(BuildContext context) {
    return Theme.of(context).colorScheme.primary;
  }

  /// Get secondary color with theme awareness
  static Color secondaryColor(BuildContext context) {
    return Theme.of(context).colorScheme.secondary;
  }

  /// Get surface color with theme awareness
  static Color surfaceColor(BuildContext context) {
    return Theme.of(context).colorScheme.surface;
  }

  /// Get background color with theme awareness
  static Color backgroundColor(BuildContext context) {
    return Theme.of(context).scaffoldBackgroundColor;
  }

  /// Get text color based on theme
  static Color textColor(BuildContext context, {bool isPrimary = true}) {
    final theme = Theme.of(context);
    if (isPrimary) {
      return theme.colorScheme.onSurface;
    }
    return theme.colorScheme.onSurfaceVariant;
  }

  /// Get message bubble color for sent messages
  static Color sentMessageColor(BuildContext context) {
    return Theme.of(context).colorScheme.primary;
  }

  /// Get message bubble color for received messages
  static Color receivedMessageColor(BuildContext context) {
    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }

  /// Get message text color for sent messages
  static Color sentMessageTextColor(BuildContext context) {
    return Theme.of(context).colorScheme.onPrimary;
  }

  /// Get message text color for received messages
  static Color receivedMessageTextColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  /// Get error color
  static Color errorColor(BuildContext context) {
    return Theme.of(context).colorScheme.error;
  }

  /// Get success color
  static Color successColor(BuildContext context) {
    return NisabaTheme.success;
  }

  /// Get warning color
  static Color warningColor(BuildContext context) {
    return NisabaTheme.warning;
  }

  /// Get divider color
  static Color dividerColor(BuildContext context) {
    return Theme.of(context).dividerColor;
  }

  /// Get card color
  static Color cardColor(BuildContext context) {
    return Theme.of(context).cardColor;
  }

  /// Get overlay/scrim color
  static Color scrimColor(BuildContext context, {double opacity = 0.5}) {
    return Theme.of(context).colorScheme.scrim.withOpacity(opacity);
  }

  /// Get shadow color
  static Color shadowColor(BuildContext context, {double opacity = 0.1}) {
    return Theme.of(context).colorScheme.shadow.withOpacity(opacity);
  }

  /// Check if dark mode is active
  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }
}
