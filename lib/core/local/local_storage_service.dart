import 'package:hive_flutter/hive_flutter.dart';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../security/secure_storage_service.dart';

final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  final secureStorage = ref.watch(secureStorageServiceProvider);
  return LocalStorageService(secureStorage);
});

final chatMuteProvider = StreamProvider.family
    .autoDispose<bool, ({String userId, String roomId})>((ref, arg) {
      return ref
          .watch(localStorageServiceProvider)
          .watchMuteStatus(arg.userId, arg.roomId);
    });

class LocalStorageService {
  final SecureStorageService _secureStorage;
  Uint8List? _encryptionKey;

  LocalStorageService(this._secureStorage);

  static const String conversationBox = 'conversations';
  static const String messagesBoxPrefix = 'messages_';
  static const String contactsBox = 'contacts';

  Future<void> init() async {
    if (_encryptionKey != null) return;
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<void>();

    try {
      await Hive.initFlutter();
      _encryptionKey = await _secureStorage.getHiveEncryptionKey();
      _initCompleter!.complete();
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null; // Reset on error so we can retry
      rethrow;
    }
  }

  Completer<void>? _initCompleter;

  /// Opens a box securely.
  /// If encryption fails (old data), it migrates data to an encrypted box.
  Future<Box> _openSecureBox(String name) async {
    if (_encryptionKey == null) {
      await init();
    }

    try {
      // 1. Try opening with encryption
      return await Hive.openBox(
        name,
        encryptionCipher: HiveAesCipher(_encryptionKey!),
      );
    } catch (e) {
      // 1.5 Check for PathNotFound (File missing)
      // If file is missing, Hive should have created it, but if it failed with PathNotFound,
      // it might be a race condition or OS error. We should NOT try to migrate (read) a missing file.
      if (e.toString().contains('PathNotFoundException') ||
          e.toString().contains('No such file')) {
        // Just try opening again (it might create it now) or rethrow if persistent
        return await Hive.openBox(
          name,
          encryptionCipher: HiveAesCipher(_encryptionKey!),
        );
      }

      // 2. Encryption failed. Assuming old plaintext data.
      print(
        'DEBUG: Encrypted open failed for $name. Attempting migration. Error: $e',
      );

      // Try opening plain
      Box plainBox;
      try {
        plainBox = await Hive.openBox(name);
      } catch (e2) {
        // Just rethrow original if plain also fails
        print('DEBUG: Plain open also failed for $name: $e2');
        rethrow;
      }

      // 3. Migrate Data
      final data = Map<dynamic, dynamic>.from(plainBox.toMap());
      await plainBox.close();
      await Hive.deleteBoxFromDisk(name); // Delete plaintext file

      // 4. Re-open Encrypted and Restore
      final encryptedBox = await Hive.openBox(
        name,
        encryptionCipher: HiveAesCipher(_encryptionKey!),
      );
      await encryptedBox.putAll(data);
      print('DEBUG: Successfully migrated $name to Encrypted Storage.');

      return encryptedBox;
    }
  }

  // --- User Specific ---
  Future<void> openUserBox(String userId) async {
    await _openSecureBox('conversations_$userId');
    await _openSecureBox('settings_$userId'); // Open settings box

    // Open deduplication box and run cleanup
    await _openSecureBox('processed_message_hashes_$userId');
    _cleanupProcessedHashes(userId); // Run async without blocking
  }

  // --- Replay Protection (Deduplication) ---
  Future<bool> isMessageHashProcessed(
    String userId,
    String hash, {
    Duration window = const Duration(minutes: 5),
  }) async {
    final boxName = 'processed_message_hashes_$userId';
    var box = await _openSecureBox(boxName);
    if (!box.isOpen) box = await _openSecureBox(boxName);

    if (box.isOpen) {
      final timestamp = box.get(hash);
      if (timestamp != null) {
        final time = DateTime.fromMillisecondsSinceEpoch(timestamp as int);
        if (DateTime.now().difference(time) <= window) {
          return true; // Recently processed, reject
        }
      }
    }
    return false;
  }

  Future<void> markMessageHashProcessed(String userId, String hash) async {
    final boxName = 'processed_message_hashes_$userId';
    var box = await _openSecureBox(boxName);
    if (!box.isOpen) box = await _openSecureBox(boxName);

    if (box.isOpen) {
      await box.put(hash, DateTime.now().millisecondsSinceEpoch);
    }
  }

  Future<void> _cleanupProcessedHashes(
    String userId, {
    Duration maxAge = const Duration(hours: 48),
  }) async {
    final boxName = 'processed_message_hashes_$userId';
    try {
      if (!Hive.isBoxOpen(boxName)) return;
      final box = Hive.box(boxName);

      final now = DateTime.now();
      final keysToDelete = [];
      for (final key in box.keys) {
        final timestamp = box.get(key);
        if (timestamp != null) {
          final time = DateTime.fromMillisecondsSinceEpoch(timestamp as int);
          if (now.difference(time) > maxAge) {
            keysToDelete.add(key);
          }
        }
      }
      if (keysToDelete.isNotEmpty) {
        await box.deleteAll(keysToDelete);
        print('DEBUG: Cleaned up ${keysToDelete.length} old processed hashes.');
      }
    } catch (e) {
      print('DEBUG: Error cleaning up hashes: $e');
    }
  }

  // --- Settings ---
  Future<void> saveUserSetting(String userId, String key, dynamic value) async {
    final box = await _openSecureBox('settings_$userId');
    await box.put(key, value);
  }

  dynamic getUserSetting(String userId, String key) {
    if (!Hive.isBoxOpen('settings_$userId')) return null;
    final box = Hive.box('settings_$userId');
    return box.get(key);
  }

  // --- Mute Settings ---
  Future<void> setMuteStatus(String userId, String roomId, bool isMuted) async {
    await saveUserSetting(userId, 'mute_$roomId', isMuted);
  }

  bool isMuted(String userId, String roomId) {
    final val = getUserSetting(userId, 'mute_$roomId');
    return val == true;
  }

  Stream<bool> watchMuteStatus(String userId, String roomId) async* {
    final boxName = 'settings_$userId';
    if (!Hive.isBoxOpen(boxName)) {
      await openUserBox(userId);
    }
    if (Hive.isBoxOpen(boxName)) {
      final box = Hive.box(boxName);
      final key = 'mute_$roomId';
      yield box.get(key) == true;
      yield* box.watch(key: key).map((event) => event.value == true);
    } else {
      yield false;
    }
  }

  // --- Messages ---
  Future<void> saveMessage(
    String userId,
    String chatId,
    Map<String, dynamic> message,
  ) async {
    try {
      final boxName = '$messagesBoxPrefix${userId}_$chatId';
      var box = await _openSecureBox(boxName);

      // Retry if box is not open (handles race conditions after deletion)
      if (!box.isOpen) {
        box = await _openSecureBox(boxName);
      }

      if (box.isOpen) {
        // DEBUG: Log imageUrl before saving for images
        if (message['type'] == 'image' && message['imageUrl'] != null) {
          print(
            'DEBUG: Saving message ${message['id']} with imageUrl: ${message['imageUrl']}',
          );
        }
        await box.put(message['id'], message);

        // DEBUG: Verify it was saved correctly
        if (message['type'] == 'image' && message['imageUrl'] != null) {
          final saved = box.get(message['id']);
          if (saved != null) {
            final savedMap = Map<String, dynamic>.from(saved);
            print(
              'DEBUG: ✓ Message saved. imageUrl in box: ${savedMap['imageUrl']}',
            );
          }
        }
      } else {
        print('DEBUG: Error - Box still closed after retry in saveMessage');
      }
    } catch (e) {
      print('DEBUG: Error saving message: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getMessages(
    String userId,
    String chatId,
  ) async {
    try {
      final boxName = '$messagesBoxPrefix${userId}_$chatId';
      var box = await _openSecureBox(boxName);

      if (!box.isOpen) {
        box = await _openSecureBox(boxName);
      }

      if (!box.isOpen) {
        return [];
      }

      return box.values.map((e) => Map<String, dynamic>.from(e)).toList()..sort(
        (a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int),
      );
    } catch (e) {
      print('DEBUG: Error getting messages for $chatId: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMessagesPaginated(
    String userId,
    String chatId, {
    int offset = 0,
    int limit = 20,
  }) async {
    try {
      final boxName = '$messagesBoxPrefix${userId}_$chatId';
      var box = await _openSecureBox(boxName);

      if (!box.isOpen) {
        box = await _openSecureBox(boxName);
      }

      if (!box.isOpen) {
        return [];
      }

      // Optimization: For huge boxes, 'box.values' might still be heavy if it loads everything.
      // However, Hive usually keeps values in memory for small boxes.
      // For lazy boxes (if we migrated), we would need different logic.
      // Assuming standard Box for now (which is memory-based).
      // If we want TRUE memory safety for millions of messages, we need LazyBox.
      // For now, this just reduces the list sorting/rendering overhead.

      final allMessages = box.values
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      // Sort Descending (Newest first)
      allMessages.sort(
        (a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int),
      );

      // Pagination logic
      if (offset >= allMessages.length) return [];

      final end = (offset + limit > allMessages.length)
          ? allMessages.length
          : offset + limit;

      return allMessages.sublist(offset, end);
    } catch (e) {
      print('DEBUG: Error getting paginated messages for $chatId: $e');
      return [];
    }
  }

  Stream<List<Map<String, dynamic>>> watchMessages(
    String userId,
    String chatId,
  ) {
    final boxName = '$messagesBoxPrefix${userId}_$chatId';

    // Use Stream.fromFuture to handle async box opening gracefully
    return Stream.fromFuture(_openSecureBox(boxName)).asyncExpand((box) async* {
      // Yield initial data immediately
      try {
        if (box.isOpen) {
          final initialData =
              box.values.map((e) => Map<String, dynamic>.from(e)).toList()
                ..sort(
                  (a, b) =>
                      (b['timestamp'] as int).compareTo(a['timestamp'] as int),
                );
          yield initialData;
        } else {
          yield [];
        }
      } catch (e) {
        yield [];
      }

      // Return stream that follows with updates
      yield* box.watch().map((_) {
        if (!box.isOpen) return <Map<String, dynamic>>[];
        try {
          return box.values.map((e) => Map<String, dynamic>.from(e)).toList()
            ..sort(
              (a, b) =>
                  (b['timestamp'] as int).compareTo(a['timestamp'] as int),
            );
        } catch (e) {
          return <Map<String, dynamic>>[];
        }
      });
    });
  }

  // New: Watch a SINGLE conversation (High Performance)
  Stream<Map<String, dynamic>?> watchConversation(
    String userId,
    String chatId,
  ) async* {
    if (!Hive.isBoxOpen('conversations_$userId')) {
      await _openSecureBox('conversations_$userId');
    }
    final box = Hive.box('conversations_$userId');

    // Yield initial
    yield Map<String, dynamic>.from(box.get(chatId) ?? {});

    // Watch specific key
    yield* box.watch(key: chatId).map((event) {
      if (event.value == null) return null;
      return Map<String, dynamic>.from(event.value);
    });
  }

  Future<void> markMessageAsRead(
    String userId,
    String chatId,
    String messageId,
  ) async {
    try {
      // Check if conversation exists first to avoid opening deleted box
      if (!Hive.box('conversations_$userId').containsKey(chatId)) {
        return;
      }

      final boxName = '$messagesBoxPrefix${userId}_$chatId';
      var box = await _openSecureBox(boxName);

      if (!box.isOpen) {
        box = await _openSecureBox(boxName);
      }

      if (box.isOpen) {
        final data = box.get(messageId);
        if (data != null) {
          final msg = Map<String, dynamic>.from(data);
          msg['isRead'] = true;
          await box.put(messageId, msg);
        }
      }
    } catch (e) {
      print('DEBUG: Error marking message as read: $e');
    }
  }

  Future<void> deleteMessage(
    String userId,
    String chatId,
    String messageId,
  ) async {
    try {
      final boxName = '$messagesBoxPrefix${userId}_$chatId';
      var box = await _openSecureBox(boxName);

      if (!box.isOpen) {
        box = await _openSecureBox(boxName);
      }

      if (box.isOpen) {
        await box.delete(messageId);
      }
    } catch (e) {
      print('DEBUG: Error deleting message: $e');
    }
  }

  Future<void> updateConversationLastMessage(
    String userId,
    String chatId,
    String lastMessage,
    DateTime timestamp,
  ) async {
    try {
      final conv = getConversation(userId, chatId);
      if (conv != null) {
        conv['lastMessage'] = lastMessage;
        conv['timestamp'] = timestamp.millisecondsSinceEpoch;
        await updateConversation(userId, chatId, conv);
      }
    } catch (e) {
      print('DEBUG: Error updating conversation last message: $e');
    }
  }

  Future<void> updateMessage(
    String userId,
    String chatId,
    String messageId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final boxName = '$messagesBoxPrefix${userId}_$chatId';
      var box = await _openSecureBox(boxName);

      if (!box.isOpen) {
        box = await _openSecureBox(boxName);
      }

      if (box.isOpen) {
        final data = box.get(messageId);
        if (data != null) {
          final msg = Map<String, dynamic>.from(data);
          updates.forEach((key, value) => msg[key] = value);
          await box.put(messageId, msg);
        }
      }
    } catch (e) {
      print('DEBUG: Error updating message: $e');
    }
  }

  // Used when I read the chat -> mark OTHERS' messages as read
  Future<void> markRoomMessagesAsRead(String userId, String chatId) async {
    try {
      final boxName = '$messagesBoxPrefix${userId}_$chatId';
      var box = await _openSecureBox(boxName);
      if (!box.isOpen) box = await _openSecureBox(boxName); // Retry

      if (box.isOpen) {
        final keys = box.keys.toList();
        for (var key in keys) {
          final val = box.get(key);
          if (val != null) {
            final msg = Map<String, dynamic>.from(val);
            // If message is NOT from me, and not read, mark read
            if (msg['senderId'] != userId && (msg['isRead'] == false)) {
              msg['isRead'] = true;
              await box.put(key, msg);
            }
          }
        }
      }
    } catch (e) {
      print('DEBUG: Error marking room as read: $e');
    }
  }

  // Used when OTHER receives my read_receipt -> mark MY messages as read
  Future<void> markMessagesAsReadByOther(String userId, String chatId) async {
    try {
      final boxName = '$messagesBoxPrefix${userId}_$chatId';
      var box = await _openSecureBox(boxName);
      if (!box.isOpen) box = await _openSecureBox(boxName); // Retry

      if (box.isOpen) {
        final keys = box.keys.toList();
        for (var key in keys) {
          final val = box.get(key);
          if (val != null) {
            final msg = Map<String, dynamic>.from(val);
            // If message IS from me, and not read, mark read (double check)
            if (msg['senderId'] == userId && (msg['isRead'] == false)) {
              msg['isRead'] = true;
              await box.put(key, msg);
            }
          }
        }
      }
    } catch (e) {
      print('DEBUG: Error marking messages as read by other: $e');
    }
  }

  // --- Conversations ---
  Future<void> updateConversation(
    String userId,
    String chatId,
    Map<String, dynamic> data,
  ) async {
    final box = Hive.box('conversations_$userId');

    // Merge Strategy: Preserve pendingRequests if not provided in update
    final existingParams = box.get(chatId);
    if (existingParams != null) {
      final existing = Map<String, dynamic>.from(existingParams);
      if (data['pendingRequests'] == null &&
          existing['pendingRequests'] != null) {
        data['pendingRequests'] = existing['pendingRequests'];
      }
    }

    await box.put(chatId, data);
  }

  Future<void> deleteConversation(String userId, String chatId) async {
    // SAFETY: Validate parameters
    if (userId.isEmpty || chatId.isEmpty) {
      print('ERROR: deleteConversation called with empty userId or chatId!');
      print('  userId: "$userId"');
      print('  chatId: "$chatId"');
      return;
    }

    print(
      'DEBUG: deleteConversation called for userId=$userId, chatId=$chatId',
    );

    // 1. Delete the conversation entry from conversations box
    final conversationsBox = Hive.box('conversations_$userId');

    // SAFETY: Check if the key exists before deleting
    if (!conversationsBox.containsKey(chatId)) {
      print('WARNING: Conversation $chatId not found in box, skipping delete');
    } else {
      await conversationsBox.delete(chatId);
      print('DEBUG: Deleted conversation $chatId from conversations box');
    }

    // 2. Delete the messages box - must close first if open
    final messagesBoxName = '${messagesBoxPrefix}${userId}_$chatId';

    try {
      // Open or get the box (this handles both cases)
      Box messagesBox;
      if (Hive.isBoxOpen(messagesBoxName)) {
        messagesBox = Hive.box(messagesBoxName);
      } else {
        messagesBox = await _openSecureBox(messagesBoxName);
      }

      // Clear all data
      await messagesBox.clear();

      print('DEBUG: Successfully cleared messages box: $messagesBoxName');
    } catch (e) {
      print('DEBUG: Error clearing messages box $messagesBoxName: $e');
    }
  }

  Map<String, dynamic>? getConversation(String userId, String chatId) {
    if (!Hive.isBoxOpen('conversations_$userId')) return null;
    final box = Hive.box('conversations_$userId');
    final data = box.get(chatId);
    if (data == null) return null;
    final m = Map<String, dynamic>.from(data);
    m['id'] = chatId;
    return m;
  }

  Future<List<Map<String, dynamic>>> getAllConversations(String userId) async {
    if (!Hive.isBoxOpen('conversations_$userId')) {
      await _openSecureBox('conversations_$userId');
    }
    final box = Hive.box('conversations_$userId');
    return box.toMap().entries.map((entry) {
      final key = entry.key.toString();
      final value = Map<String, dynamic>.from(entry.value as Map);
      value['id'] = key;
      return value;
    }).toList();
  }

  Stream<List<Map<String, dynamic>>> watchConversations(String userId) async* {
    print('DEBUG: watchConversations called for userId=$userId');
    if (!Hive.isBoxOpen('conversations_$userId')) {
      await _openSecureBox('conversations_$userId');
    }
    final box = Hive.box('conversations_$userId');

    int getTimestamp(Map<String, dynamic> m) {
      final val = m['lastMessageTime'];
      if (val is int) return val;
      if (val is double) return val.toInt();
      return 0; // Fallback
    }

    List<Map<String, dynamic>> getList() {
      final list = box.toMap().entries.map((entry) {
        final key = entry.key.toString();
        final value = Map<String, dynamic>.from(entry.value as Map);
        value['id'] = key;
        return value;
      }).toList()..sort((a, b) => getTimestamp(b).compareTo(getTimestamp(a)));

      print(
        'DEBUG: watchConversations getList() returned ${list.length} conversations for user $userId',
      );
      if (list.isEmpty) {
        print('WARNING: Conversation list is EMPTY for user $userId!');
        print('DEBUG: Box keys: ${box.keys.toList()}');
      }
      return list;
    }

    // Yield initial values
    yield getList();

    // Yield on changes
    yield* box.watch().map((_) {
      print(
        'DEBUG: watchConversations detected change in box for user $userId',
      );
      return getList();
    });
  }

  Future<void> markMessagesAsReadBy(
    String myId,
    String roomId,
    String readerId,
  ) async {
    // Safety: Don't open box if conversation is deleted
    if (!Hive.box('conversations_$myId').containsKey(roomId)) {
      return;
    }

    final box = await Hive.openBox('messages_${myId}_$roomId');
    final keys = box.keys
        .toList(); // Assuming keys are time-sorted or insert-order

    // We iterate backwards (newest first).
    // If we find a message ALREADY read by this user, we can likely stop?
    // Not necessarily (gaps?), but for typical chat usage yes.
    // However, to be robust, let's just check the last 50 messages.
    // Or just all unread ones?

    for (var i = keys.length - 1; i >= 0; i--) {
      final key = keys[i];
      final msg = Map<String, dynamic>.from(box.get(key) as Map);

      final List<String> readBy = List<String>.from(msg['readBy'] ?? []);
      if (!readBy.contains(readerId)) {
        readBy.add(readerId);
        msg['readBy'] = readBy;
        msg['isRead'] = true; // Fix: Mark as read so checkmarks update
        await box.put(key, msg);
      } else {
        // If we hit a message already read by them, and we assume sequential reading,
        // we could optimize and break.
        // Let's break after 10 consecutive "already read" to be safe.
        // For MVP, just breaking on first is risky if they read out of order (unlikely in chat UI).
        // Let's break immediately.
        break;
      }
    }
  }

  /// Clears all messages for a user by deleting all message boxes
  Future<void> clearAllMessages(String userId) async {
    try {
      // Get all conversations to find all message boxes
      final conversations = await getAllConversations(userId);

      int clearedCount = 0;
      for (final chat in conversations) {
        final chatId = chat['id'];
        final messagesBoxName = '$messagesBoxPrefix${userId}_$chatId';

        try {
          Box? messagesBox;
          if (Hive.isBoxOpen(messagesBoxName)) {
            messagesBox = Hive.box(messagesBoxName);
          } else {
            try {
              messagesBox = await _openSecureBox(messagesBoxName);
            } catch (_) {
              // Box doesn't exist, skip
              continue;
            }
          }

          if (messagesBox.isOpen) {
            await messagesBox.clear();
            clearedCount++;
          }
        } catch (e) {
          print('DEBUG: Error clearing messages box $messagesBoxName: $e');
        }
      }

      print(
        'DEBUG: Cleared all messages. Deleted $clearedCount message boxes.',
      );
    } catch (e) {
      print('DEBUG: Error in clearAllMessages: $e');
      rethrow;
    }
  }
}
