import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
// IMPORTED
import '../../features/chat/repositories/chat_repository.dart';
import '../../features/chat/models/chat_room.dart';
import '../../features/settings/services/settings_service.dart';
import 'notification_service.dart';

class NotificationWatcher extends ConsumerWidget {
  final Widget child;

  const NotificationWatcher({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen to userChats stream globally
    ref.listen<AsyncValue<List<ChatRoom>>>(userChatsProvider, (
      previous,
      next,
    ) async {
      // Allow next.value to proceed even if previous is null (for first message scenerio)
      if (next.value == null) return;

      final previousChats = previous?.value != null
          ? {for (var c in previous!.value!) c.id: c}
          : <String, ChatRoom>{}; // Handle empty previous state

      final nextChats = next.value!;
      final currentUser = FirebaseAuth.instance.currentUser;
      final activeRoomId = ref.read(activeChatRoomIdProvider);

      for (var chat in nextChats) {
        final prevChat = previousChats[chat.id];

        // LOGIC REFINED:
        // 1. New Chat: prevChat is null.
        // 2. Updated Chat: Last message time changed.
        bool isNewOrUpdated =
            prevChat == null ||
            chat.lastMessageTime.isAfter(prevChat.lastMessageTime);

        if (isNewOrUpdated) {
          debugPrint('DEBUG (Watcher): Chat ${chat.id} updated!');

          // 3. Check Suppression (Is user inside this chat?)
          if (activeRoomId == chat.id) {
            debugPrint(
              'DEBUG (Watcher): Suppressed notification for active chat ${chat.id}',
            );
            continue;
          }

          // 4. Trigger Notification Logic
          // We only notify if the LAST message was NOT sent by me
          // (Assuming lastMessageSenderId is available or we infer from unread)
          // The unread count check is good, but for the very first message
          // unread count goes from 0 -> 1.

          final myUnreadCount = chat.unreadCounts[currentUser?.uid] ?? 0;
          final prevUnreadCount = prevChat?.unreadCounts[currentUser?.uid] ?? 0;

          bool shouldNotify = false;

          // Condition A: Unread count increased
          if (currentUser != null && myUnreadCount > prevUnreadCount) {
            shouldNotify = true;
          }
          // Condition B: New chat with unread messages (Fix for first message)
          else if (prevChat == null && myUnreadCount > 0) {
            shouldNotify = true;
          }

          if (shouldNotify) {
            // CHECK SETTINGS
            final settings = ref.read(settingsServiceProvider);
            // 1. Master Toggle
            if (!settings.notificationsEnabled) {
              debugPrint('DEBUG (Watcher): Notifications disabled by user.');
              continue;
            }

            // 2. Do Not Disturb (DND) Schedule Check
            if (settings.doNotDisturbEnabled) {
              if (_isCurrentlyInDnd(
                settings.doNotDisturbStart,
                settings.doNotDisturbEnd,
              )) {
                debugPrint(
                  'DEBUG (Watcher): Notification suppressed due to active DND schedule (${settings.doNotDisturbStart} - ${settings.doNotDisturbEnd}).',
                );
                continue;
              }
            }

            // 3. Prepare Body based on Preview Setting
            final String bodyText = settings.notificationPreview
                ? chat.lastMessage
                : 'رسالة جديدة';

            // Trigger Notification
            NotificationService().showNotification(
              chat.isGroup ? chat.groupName ?? 'مجموعة' : 'رسالة جديدة',
              bodyText,
              sound: settings.notificationSound,
              vibrate: settings.notificationVibrate,
            );
          }
        }
      }
    });

    return child;
  }

  bool _isCurrentlyInDnd(String startStr, String endStr) {
    try {
      final now = DateTime.now();
      final currentMinutes = now.hour * 60 + now.minute;

      final startParts = startStr.split(':').map(int.parse).toList();
      final endParts = endStr.split(':').map(int.parse).toList();

      final startMinutes = startParts[0] * 60 + startParts[1];
      final endMinutes = endParts[0] * 60 + endParts[1];

      if (startMinutes < endMinutes) {
        return currentMinutes >= startMinutes && currentMinutes < endMinutes;
      } else if (startMinutes > endMinutes) {
        return currentMinutes >= startMinutes || currentMinutes < endMinutes;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}
