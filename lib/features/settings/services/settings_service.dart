import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import '../../../../core/local/local_storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService(ref.read(localStorageServiceProvider));
});

class SettingsService {
  final LocalStorageService _local;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  SettingsService(this._local);

  String? get _uid => _auth.currentUser?.uid;

  Future<void> init() async {
    if (_uid != null) {
      await _local.openUserBox(_uid!);
    }
  }

  // --- Generic Helpers ---
  Future<void> _setBool(String key, bool value) async {
    if (_uid == null) return;
    await _local.saveUserSetting(_uid!, key, value);
  }

  bool _getBool(String key, {bool defaultValue = false}) {
    if (_uid == null) return defaultValue;
    final val = _local.getUserSetting(_uid!, key);
    return val is bool ? val : defaultValue;
  }

  // --- Privacy ---
  Future<void> setOnlineStatus(bool value) =>
      _setBool('privacy_online_status', value);
  bool get onlineStatus =>
      _getBool('privacy_online_status', defaultValue: true);

  Future<void> setTypingIndicator(bool value) =>
      _setBool('privacy_typing', value);
  bool get typingIndicator => _getBool('privacy_typing', defaultValue: true);

  Future<void> setReadReceipts(bool value) =>
      _setBool('privacy_read_receipts', value);
  bool get readReceipts =>
      _getBool('privacy_read_receipts', defaultValue: true);

  // --- Security ---
  Future<void> setAppLock(bool value) => _setBool('security_app_lock', value);
  bool get appLock => _getBool('security_app_lock', defaultValue: false);

  // --- Appearance ---
  Future<void> setThemeMode(String value) async {
    final uid = _uid;
    if (uid == null) return;
    await _local.saveUserSetting(uid, 'appearance_theme_mode', value);
  }

  String get themeMode {
    if (_uid == null) return 'system';
    return _local.getUserSetting(_uid!, 'appearance_theme_mode') as String? ??
        'system';
  }

  // --- Notifications ---
  Future<void> setNotificationsEnabled(bool value) =>
      _setBool('notifications_enabled', value);
  bool get notificationsEnabled =>
      _getBool('notifications_enabled', defaultValue: true);

  Future<void> setNotificationSound(bool value) =>
      _setBool('notifications_sound', value);
  bool get notificationSound =>
      _getBool('notifications_sound', defaultValue: true);

  Future<void> setNotificationVibrate(bool value) =>
      _setBool('notifications_vibrate', value);
  bool get notificationVibrate =>
      _getBool('notifications_vibrate', defaultValue: true);

  Future<void> setNotificationPreview(bool value) =>
      _setBool('notifications_preview', value);
  bool get notificationPreview =>
      _getBool('notifications_preview', defaultValue: true);

  // Do Not Disturb
  Future<void> setDoNotDisturbEnabled(bool value) =>
      _setBool('notifications_dnd_enabled', value);
  bool get doNotDisturbEnabled =>
      _getBool('notifications_dnd_enabled', defaultValue: false);

  Future<void> setDoNotDisturbStart(String time) async {
    final uid = _uid;
    if (uid == null) return;
    await _local.saveUserSetting(uid, 'notifications_dnd_start', time);
  }

  String get doNotDisturbStart {
    if (_uid == null) return '22:00';
    return _local.getUserSetting(_uid!, 'notifications_dnd_start') as String? ??
        '22:00';
  }

  Future<void> setDoNotDisturbEnd(String time) async {
    final uid = _uid;
    if (uid == null) return;
    await _local.saveUserSetting(uid, 'notifications_dnd_end', time);
  }

  String get doNotDisturbEnd {
    if (_uid == null) return '08:00';
    return _local.getUserSetting(_uid!, 'notifications_dnd_end') as String? ??
        '08:00';
  }

  // --- Security ---
  Future<void> setAutoLockTimeout(int seconds) async {
    final uid = _uid;
    if (uid == null) return;
    await _local.saveUserSetting(uid, 'security_auto_lock_timeout', seconds);
  }

  int get autoLockTimeout {
    if (_uid == null) return 0;
    final val = _local.getUserSetting(_uid!, 'security_auto_lock_timeout');
    return val is int ? val : 0;
  }

  // --- Language ---
  Future<void> setLanguage(String langCode) async {
    final uid = _uid;
    if (uid == null) return;
    await _local.saveUserSetting(uid, 'app_language', langCode);
  }

  String get language {
    if (_uid == null) return 'ar';
    return _local.getUserSetting(_uid!, 'app_language') as String? ?? 'ar';
  }

  // --- Storage ---
  Future<Map<String, int>> calculateStorageUsage(String userId) async {
    int totalSize = 0;
    int mediaSize = 0;
    int textSize = 0;

    try {
      // Get all conversations
      final conversations = await _local.getAllConversations(userId);

      for (final conv in conversations) {
        final chatId = conv['id'] as String? ?? '';
        if (chatId.isEmpty) continue;

        final boxName =
            '${LocalStorageService.messagesBoxPrefix}${userId}_$chatId';

        try {
          if (!Hive.isBoxOpen(boxName)) {
            await _local.openUserBox(userId);
          }

          if (Hive.isBoxOpen(boxName)) {
            final box = Hive.box(boxName);

            for (final key in box.keys) {
              final msg = box.get(key);
              if (msg == null) continue;

              final msgMap = Map<String, dynamic>.from(msg as Map);
              final msgType = msgMap['type'] as String? ?? 'text';

              // Estimate size (rough calculation)
              final jsonStr = msgMap.toString();
              final msgSize = utf8.encode(jsonStr).length;
              totalSize += msgSize;

              if (msgType == 'image' ||
                  msgType == 'audio' ||
                  msgType == 'voice') {
                mediaSize += msgSize;
              } else {
                textSize += msgSize;
              }
            }
          }
        } catch (e) {
          // Skip boxes that can't be opened
          continue;
        }
      }
    } catch (e) {
      debugPrint('Error calculating storage: $e');
    }

    return {'total': totalSize, 'media': mediaSize, 'text': textSize};
  }
}
