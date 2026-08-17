import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:screen_protector/screen_protector.dart';

class ScreenSecurityService {
  static const String _boxName = 'security_prefs';
  static const String _keyPreventScreenshots = 'prevent_screenshots';

  /// Applies global screenshot protection based on saved Hive preference.
  static Future<void> applyGlobalProtection() async {
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS)) return;
    try {
      final isEnabled = await isGlobalProtectionEnabled();
      if (isEnabled) {
        await enableProtection();
      } else {
        await disableProtection();
      }
    } catch (e) {
      debugPrint('Error applying global screenshot protection: $e');
    }
  }

  /// Returns true if global screenshot protection is enabled in security settings.
  static Future<bool> isGlobalProtectionEnabled() async {
    try {
      final box = await Hive.openBox(_boxName);
      return box.get(_keyPreventScreenshots, defaultValue: false) as bool;
    } catch (e) {
      debugPrint('Error reading screenshot protection setting: $e');
      return false;
    }
  }

  /// Sets global screenshot protection preference and applies it immediately.
  static Future<void> setGlobalProtection(bool enabled) async {
    try {
      final box = await Hive.openBox(_boxName);
      await box.put(_keyPreventScreenshots, enabled);
      if (enabled) {
        await enableProtection();
      } else {
        await disableProtection();
      }
    } catch (e) {
      debugPrint('Error updating screenshot protection setting: $e');
    }
  }

  /// Syncs protection for an active room.
  /// If the room is protected OR global protection is enabled, protection is turned ON.
  /// Otherwise, protection is turned OFF.
  static Future<void> syncRoomProtection({
    required bool isRoomProtectionEnabled,
  }) async {
    try {
      final globalEnabled = await isGlobalProtectionEnabled();
      if (isRoomProtectionEnabled || globalEnabled) {
        await enableProtection();
      } else {
        await disableProtection();
      }
    } catch (e) {
      debugPrint('Error syncing room screenshot protection: $e');
    }
  }

  /// Enables protection for the current screen only.
  static Future<void> enableProtection() async {
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS)) return;
    try {
      await ScreenProtector.preventScreenshotOn();
    } catch (e) {
      debugPrint('Error enabling screen protection: $e');
    }
  }

  /// Disables protection for the current screen.
  static Future<void> disableProtection() async {
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS)) return;
    try {
      await ScreenProtector.preventScreenshotOff();
    } catch (e) {
      debugPrint('Error disabling screen protection: $e');
    }
  }
}
