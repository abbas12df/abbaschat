import 'dart:async';
import 'dart:io';
import 'package:qqqq/features/chat/models/upload_progress.dart';
import 'package:uuid/uuid.dart'; // Added
import 'dart:convert';
import 'package:pointycastle/export.dart' as pc;
import 'package:basic_utils/basic_utils.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart'; // Added
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/local/local_storage_service.dart';
import '../../../core/security/crypto_service.dart';
import '../../../core/security/encryption_helper.dart';
import '../../auth/repositories/key_repository.dart';
import '../../auth/services/auth_service.dart';
import '../services/relay_service.dart';
import '../models/message.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/chat_room.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../core/services/push_notification_service.dart';
import '../models/sync_request.dart';

enum SyncStatus { idle, requesting, downloading, restoring, completed, error }

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  // Watch auth state to force rebuild/dispose on login/logout
  ref.watch(authStateProvider);

  final repo = ChatRepository(
    ref.read(localStorageServiceProvider),
    ref.read(relayServiceProvider),
    ref.read(keyRepositoryProvider),
    FirebaseAuth.instance,
  );

  ref.onDispose(() => repo.dispose());

  return repo;
});

final chatMessagesProvider = StreamProvider.autoDispose
    .family<List<Message>, String>((ref, roomId) {
      return ref.watch(chatRepositoryProvider).getMessages(roomId);
    });

final userChatsProvider = StreamProvider<List<ChatRoom>>((ref) {
  return ref.watch(chatRepositoryProvider).getUserChats();
});

// Caching Provider for User Data (Prevents flickering in list)
final userProfileProvider = StreamProvider.family<UserModel?, String>((
  ref,
  uid,
) {
  // Use stream for real-time updates (name changes, online status, etc.)
  return ref.read(chatRepositoryProvider).getUserStream(uid);
});

// Tracks the currently open chat room ID (if any) to suppress notifications
final activeChatRoomIdProvider = StateProvider<String?>((ref) => null);

// Provider for upload progress UI tracking
final uploadProgressProvider = StreamProvider.family
    .autoDispose<UploadProgress, String>((ref, messageId) {
      final repo = ref.watch(chatRepositoryProvider);
      return repo.uploadProgressStream.where((p) => p.fileId == messageId);
    });

class ChatRepository {
  final Map<String, Map<String, dynamic>> _pendingSegments = {};
  final LocalStorageService _local;
  final RelayService _relay;
  final KeyRepository _keyRepo;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // In-Memory Cache for Users to prevent flickering and Firestore spam
  final Map<String, UserModel> _userCache = {};

  // Sync Cache & Deduplication
  final Map<String, DateTime> _lastGroupSyncTime = {};
  final Map<String, DateTime> _lastSyncRequestHandled = {}; // Sync rate limit
  final Map<String, DateTime> _lastSyncRequestSent = {}; // Pull throttle
  final Map<String, Future<void>> _activeGroupSyncs = {}; // Deduplication

  // File Transfer State (Chunking)
  final Map<String, RandomAccessFile> _activeDownloads = {};
  final Map<String, Set<int>> _downloadReceivedChunks = {};
  final Map<String, int> _downloadTotalChunks = {};
  final Map<String, int> _downloadChunkSizes = {};
  final Map<String, String> _downloadExpectedHashes = {};
  final Map<String, String> _downloadFileNames = {};
  final Map<String, Future<void>> _downloadLocks = {}; // Mutex for concurrency

  // Security Limits
  static const int _maxFileSize = 500 * 1024 * 1024; // 500MB
  static const int _maxChunkSize = 2 * 1024 * 1024; // 2MB
  static const int _maxChunks = 10000;

  // Replay Protection (In-flight messages)
  final Set<String> _processingMessageHashes = {};

  // Upload Tracking
  final Map<String, UploadProgress> _activeUploads = {};
  final StreamController<UploadProgress> _uploadProgressController =
      StreamController<UploadProgress>.broadcast();
  Stream<UploadProgress> get uploadProgressStream =>
      _uploadProgressController.stream;

  void cancelUpload(String fileId) {
    if (_activeUploads.containsKey(fileId)) {
      _activeUploads[fileId]!.cancelToken.cancel();
      _activeUploads[fileId] = _activeUploads[fileId]!.copyWith(
        status: UploadStatus.cancelled,
      );
      _uploadProgressController.add(_activeUploads[fileId]!);
    }
  }

  Future<void> cancelDownload(String fileId) async {
    final raf = _activeDownloads.remove(fileId);
    if (raf != null) {
      try {
        await raf.close();
      } catch (_) {}
    }
    _downloadReceivedChunks.remove(fileId);
    _downloadTotalChunks.remove(fileId);
    _downloadChunkSizes.remove(fileId);
    _downloadExpectedHashes.remove(fileId);
    _downloadFileNames.remove(fileId);
    _downloadLocks.remove(fileId);

    try {
      final dir = await getApplicationDocumentsDirectory();
      final tempFile = File('${dir.path}/${fileId}_temp');
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    } catch (_) {}
  }

  // P2P Sync Status Broadcast
  final StreamController<SyncStatus> _syncStatusController =
      StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatus => _syncStatusController.stream;

  StreamSubscription? _inboxSubscription;
  Set<String> _blockedUsersCache = {};

  Future<void> _fetchBlockedUsersCache() async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(myId).get();
      if (doc.exists) {
        final list = List<String>.from(doc.data()?['blockedUsers'] ?? []);
        _blockedUsersCache = list.toSet();
      }
    } catch (e) {
      debugPrint('DEBUG: Error fetching blocked users cache: $e');
    }
  }

  ChatRepository(this._local, this._relay, this._keyRepo, this._auth) {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      // Initialize the purely local storage for this user
      _local.openUserBox(uid).then((_) {
        _fetchBlockedUsersCache();
        // Only start listening after box is ready
        _initializeInboxListener();
        _initializeSyncListeners(); // Added for P2P Sync
        restoreActiveChats();
      });
      setupPresence();
    }
    _autoUploadPublicKey();
    _initializeConnectivityListener();
  }

  // --- OFFLINE QUEUE ---
  StreamSubscription? _connectivitySubscription;

  void _initializeConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final isOnline = results.any(
        (r) => r == ConnectivityResult.mobile || r == ConnectivityResult.wifi,
      );
      if (isOnline) {
        debugPrint('DEBUG: Connection restored. Processing message queue...');
        _processMessageQueue();
      }
    });
  }

  Future<void> _processMessageQueue() async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    // 1. Get all conversations to scan
    // This is a heavy operation for MVP, but ensures reliability.
    // Optimization: In future, use a dedicated 'pending_queue' box.
    final chats = await _local.getAllConversations(myId);

    for (final chat in chats) {
      final roomId = chat['id'];
      final messages = await _local.getMessages(myId, roomId);

      // Find pending messages
      final pending = messages.where((m) {
        final status = m['status'];
        return status == 'sending' || status == 'failed';
      }).toList();

      if (pending.isNotEmpty) {
        debugPrint(
          'DEBUG: Found ${pending.length} pending messages in $roomId',
        );
        for (final msg in pending) {
          await _retrySendMessage(myId, roomId, msg);
        }
      }
    }
  }

  Future<void> _retrySendMessage(
    String myId,
    String roomId,
    Map<String, dynamic> msg,
  ) async {
    final messageId = msg['id'];
    final type = msg['type'];
    final content = type == 'text'
        ? msg['text']
        : (type == 'image' || type == 'audio'
              ? msg['audioUrl'] ?? msg['imageUrl']
              : ''); // Helper to get path/content

    // Update status to sending (UI feedback)
    if (msg['status'] != 'sending') {
      msg['status'] = 'sending';
      await _local.saveMessage(myId, roomId, msg);
    }

    try {
      // Re-use logic.
      // Problem: sendMessage methods in repo take arguments, not map.
      // We need to call the internal sending logic.
      // I'll extract a helper `_executeSend` or just define logic here.
      // Re-using `_sendEncryptedContent` is best.

      // Recipients
      final room = _local.getConversation(myId, roomId);
      final isGroup = room?['isGroup'] == true;
      List<String> receiverIds = [];
      if (isGroup) {
        final participants = List<String>.from(room?['participants'] ?? []);
        receiverIds = participants.where((id) => id != myId).toList();
      } else {
        receiverIds = [_getReceiverIdFromRoom(roomId, myId)];
      }

      bool allFailed = true;

      for (final receiverId in receiverIds) {
        if (receiverId == 'unknown') continue;
        try {
          final receiverKey = await _keyRepo.getUserPublicKey(receiverId);
          if (receiverKey == null) continue;

          final myPrivateKey = await CryptoService().getPrivateKeyPem();

          // Basic Args
          final encryptionArgs = {
            'type': type,
            'content': content,
            'replyToId': msg['replyToId'],
            'replySnapshot': msg['replySnapshot'],
            'receiverKey': receiverKey,
            'groupId': isGroup ? roomId : null,
            'senderPrivateKey': myPrivateKey,
          };

          final encryptedBundle = await compute(
            _encryptInBackground,
            encryptionArgs,
          );

          await _relay.pushToRelay(
            receiverId: receiverId,
            messageId: messageId,
            encryptedBundle: encryptedBundle,
          );
          allFailed = false;
        } catch (e) {
          debugPrint('DEBUG: Retry failed for $receiverId: $e');
        }
      }

      if (!allFailed) {
        msg['status'] = 'sent';
        await _local.saveMessage(myId, roomId, msg);
        debugPrint('DEBUG: Re-sent message $messageId successfully');
      } else {
        // Keep as failed/sending? If we are confident we are online (triggerd by listener), then 'failed' is appropriate if it keeps failing.
        // But maybe let it stay 'sending' for next retry?
        // Let's set 'failed' so user knows.
        msg['status'] = 'failed';
        await _local.saveMessage(myId, roomId, msg);
      }
    } catch (e) {
      debugPrint('DEBUG: Retry Error: $e');
      msg['status'] = 'failed';
      await _local.saveMessage(myId, roomId, msg);
    }
  }

  StreamSubscription? _presenceSubscription;

  // PRESENCE
  void setupPresence() {
    // 1. Cancel existing subscription to prevent duplicates
    _presenceSubscription?.cancel();

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // Ensure connection is established when we have a user

    FirebaseDatabase.instance.goOnline();

    final database = FirebaseDatabase.instance;
    final myStatusRef = database.ref('status/$uid');
    final connectedRef = database.ref('.info/connected');

    _presenceSubscription = connectedRef.onValue.listen((event) async {
      final connected = event.snapshot.value as bool? ?? false;
      if (connected) {
        // CHECK PRIVACY SETTING FIRST
        final isVisible = await _isSettingEnabled('privacy_online_status');
        if (!isVisible) return;

        // On disconnect: set state to offline, timestamp
        // Added error handling to prevent crash on Permission Denied
        myStatusRef
            .onDisconnect()
            .update({'state': 'offline', 'last_changed': ServerValue.timestamp})
            .then(
              (_) => debugPrint('DEBUG: Presence onDisconnect setup success'),
            )
            .catchError(
              (e) => debugPrint('DEBUG: Presence onDisconnect failed: $e'),
            );

        // On connect: set state to online, timestamp
        myStatusRef
            .update({'state': 'online', 'last_changed': ServerValue.timestamp})
            .then((_) => debugPrint('DEBUG: Set status to online success'))
            .catchError(
              (e) => debugPrint('DEBUG: Set status to online failed: $e'),
            );
      }
    });
  }

  Stream<Map<String, dynamic>> getUserPresence(String uid) {
{
      return const Stream.empty();
    }
    return FirebaseDatabase.instance.ref('status/$uid').onValue.map((event) {
      if (event.snapshot.value == null) return <String, dynamic>{};
      return Map<String, dynamic>.from(event.snapshot.value as Map);
    }).asBroadcastStream();
  }

  // --- PRIVACY CONTROLS ---

  Future<void> updateOnlinePrivacy(bool isVisible) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // 1. Save Setting
    await _local.saveUserSetting(uid, 'privacy_online_status', isVisible);

    // 2. Apply Immediately
    final myStatusRef = FirebaseDatabase.instance.ref('status/$uid');
    if (isVisible) {
      // Go Online
      await myStatusRef.update(<String, dynamic>{
        'state': 'online',
        'last_changed': ServerValue.timestamp,
      });
      await myStatusRef.onDisconnect().update(<String, dynamic>{
        'state': 'offline',
        'last_changed': ServerValue.timestamp,
      });
    } else {
      // Go Offline (Ghost Mode)
      await myStatusRef.onDisconnect().cancel();
      await myStatusRef
          .remove(); // Removes the status node entirely or set offline
    }
  }

  Future<void> setOffline() async {
    // 1. Stop listening to connection changes locally
    // This prevents the 'goOnline' call (for next user) from triggering an 'Online' write for THIS user.
    await _presenceSubscription?.cancel();
    _presenceSubscription = null;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final myStatusRef = FirebaseDatabase.instance.ref('status/$uid');

    // Explicitly set offline with timestamp
    // We DO NOT cancel onDisconnect here; we want it to remain as a failsafe
    await myStatusRef.update({
      'state': 'offline',
      'last_changed': ServerValue.timestamp,
    });

    debugPrint('DEBUG: Explicitly set status to offline for $uid');
  }

  Future<bool> _isSettingEnabled(String key, {bool defaultValue = true}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return defaultValue;
    final val = _local.getUserSetting(uid, key);
    if (val == null) return defaultValue;
    return val as bool;
  }

  Future<void> _autoUploadPublicKey() async {
    // Ensure our public key is on the relay for others to encrypt for us
    await _keyRepo.uploadMyPublicKey();
  }

  void _initializeInboxListener() {
    _inboxSubscription = _relay.myInboxStream.listen((event) async {
      debugPrint('DEBUG: Received Relay Event: key=${event.snapshot.key}');
      if (event.snapshot.value == null) return;

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final String messageId = event.snapshot.key!;
      final String senderId = data['sender_id'];
      debugPrint('DEBUG: Processing message $messageId from $senderId');

      if (_blockedUsersCache.contains(senderId)) {
        debugPrint(
          'SECURITY ALERT: Dropping message $messageId from blocked user $senderId.',
        );
        await _relay.sendAck(senderId: senderId, messageId: messageId);
        await _relay.deleteFromRelay(messageId);
        return;
      }

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('DEBUG: No current user!');
        return;
      }

      final Map<String, dynamic> encryptedBundle = Map<String, dynamic>.from(
        data['payload'],
      );

      String? currentHash;

      try {
        // 1. Decrypt
        final myPrivateKey = await CryptoService().getPrivateKeyPem();
        if (myPrivateKey == null) {
          debugPrint('DEBUG: No private key found!');
          throw Exception('No Private Key found');
        }

        final decryptedText = await _attemptDecryption(
          encryptedBundle,
          myPrivateKey,
        );
        debugPrint('DEBUG: Message decrypted successfully.');

        // --- VERIFY SIGNATURE ---
        final signature = encryptedBundle['signature'] as String?;
        if (signature == null || signature.isEmpty) {
          debugPrint(
            'SECURITY ALERT: Missing Signature for message $messageId from $senderId. Dropping.',
          );
          await _relay.sendAck(senderId: senderId, messageId: messageId);
          await _relay.deleteFromRelay(messageId);
          return;
        }

        final senderKey = await _keyRepo.getUserPublicKey(senderId);
        if (senderKey == null || senderKey.isEmpty) {
          debugPrint(
            'SECURITY ALERT: No trusted public key for sender $senderId. Dropping.',
          );
          await _relay.sendAck(senderId: senderId, messageId: messageId);
          await _relay.deleteFromRelay(messageId);
          return;
        }

        try {
          // The signature MUST be valid for the decryptedText using the exact senderId's public key.
          final isValid = CryptoService().verifyString(
            decryptedText,
            signature,
            senderKey,
          );

          if (!isValid) {
            debugPrint(
              'SECURITY ALERT: Invalid Signature for message $messageId from $senderId. Dropping.',
            );
            await _relay.sendAck(senderId: senderId, messageId: messageId);
            await _relay.deleteFromRelay(messageId);
            return;
          }
          debugPrint('DEBUG: Signature Verified from $senderId');

          // --- SECURITY: REPLAY PROTECTION (DEDUPLICATION) ---
          final ciphertext = encryptedBundle['ciphertext'] as String?;
          if (ciphertext != null) {
            final hashBytes = sha256.convert(utf8.encode(ciphertext));
            currentHash = hashBytes.toString();

            if (_processingMessageHashes.contains(currentHash)) {
              debugPrint(
                'SECURITY ALERT: Message hash is already in flight. Dropping message $messageId.',
              );
              return;
            }

            final isDuplicate = await _local.isMessageHashProcessed(
              currentUser.uid,
              currentHash!,
            );
            if (isDuplicate) {
              debugPrint(
                'SECURITY ALERT: Duplicate message detected (replay protection). Dropping message $messageId from $senderId.',
              );
              await _relay.sendAck(senderId: senderId, messageId: messageId);
              await _relay.deleteFromRelay(messageId);
              return;
            }

            // Mark as in-flight
            _processingMessageHashes.add(currentHash!);
          }
          // ---------------------------------------------------
        } catch (e) {
          debugPrint(
            'SECURITY ALERT: Error verifying signature for message $messageId from $senderId: $e',
          );
          await _relay.sendAck(senderId: senderId, messageId: messageId);
          await _relay.deleteFromRelay(messageId);
          return;
        }
        // ------------------------

        // 2. Hydrate Message
        // We construct the roomId based on participants sorted
        // PARSE JSON PAYLOAD FIRST
        Map<String, dynamic> messagePayload = {};
        try {
          messagePayload = jsonDecode(decryptedText);
        } catch (e) {
          // Fallback for legacy plain text messages
          messagePayload = {'type': 'text', 'content': decryptedText};
        }

        debugPrint(
          'DEBUG: Decrypted payload parsed. type=${messagePayload['type']}',
        );

        // Determine Room ID (Group vs 1-on-1)
        String roomId;
        // CRITICAL FIX: Check for 'id' field first (used by group commands),
        // then 'groupId' (used by some messages), then fallback to 1-on-1
        if (messagePayload.containsKey('id') &&
            messagePayload['id'] != null &&
            messagePayload['id'].toString().startsWith('group_')) {
          roomId = messagePayload['id'];
          debugPrint('DEBUG: Resolved Group Room ID from "id" field: $roomId');
        } else if (messagePayload.containsKey('groupId')) {
          roomId = messagePayload['groupId'];
          debugPrint(
            'DEBUG: Resolved Group Room ID from "groupId" field: $roomId',
          );
        } else {
          roomId = _getRoomId(senderId, currentUser.uid);
          debugPrint(
            'DEBUG: Resolved 1-on-1 Room ID: $roomId (No group ID in payload)',
          );
        }
        debugPrint('DEBUG: Final Resolved Room ID: $roomId');

        String msgType = messagePayload['type'] ?? 'text';
        String msgContent = messagePayload['content'] ?? '';
        final replyToId = messagePayload['replyToId']; // Extract reply ID

        // --- SECURITY: VALIDATE GROUP MEMBERSHIP & EXISTENCE ---
        if (roomId.startsWith('group_')) {
          var groupRoom = _local.getConversation(currentUser.uid, roomId);

          // 1. Check if group exists (Prevents Zombie Groups)
          if (groupRoom == null) {
            // Try to sync if it's a valid group I'm in (e.g. missed invite or new group while offline)
            try {
              await _smartSyncGroup(roomId);
              groupRoom = _local.getConversation(currentUser.uid, roomId);
            } catch (e) {
              // Still null or kicked
            }

            // Allow 'group_create' to pass (invitation)
            if (groupRoom == null && msgType != 'group_create') {
              debugPrint(
                'SECURITY: Ignored message for deleted/unknown group $roomId (Type: $msgType)',
              );
              // Ack to remove from relay so we don't fetch it again
              await _relay.sendAck(senderId: senderId, messageId: messageId);
              await _relay.deleteFromRelay(messageId);
              return;
            }
          }

          if (groupRoom != null) {
            // 2. Check if sender is a participant (Prevents Removed Members from posting)
            var participants = List<String>.from(
              groupRoom['participants'] ?? [],
            );
            if (!participants.contains(senderId)) {
              debugPrint(
                'SECURITY: Sender $senderId not in local participants. Attempting sync...',
              );
              // Attempt sync to fetch latest participants (Fix for "Messages from new members not appearing")
              try {
                await _smartSyncGroup(roomId);
                final updatedRoom = _local.getConversation(
                  currentUser.uid,
                  roomId,
                );
                participants = List<String>.from(
                  updatedRoom?['participants'] ?? [],
                );
              } catch (e) {
                debugPrint('DEBUG: Sync failed during participant check: $e');
              }

              if (!participants.contains(senderId)) {
                debugPrint(
                  'SECURITY: Blocked unauthorized message from $senderId in group $roomId (Not a participant)',
                );
                await _relay.sendAck(senderId: senderId, messageId: messageId);
                await _relay.deleteFromRelay(messageId);
                return;
              }
            }
          }
        }
        // -------------------------------------------------------

        // --- NEW: DELETE CONVERSATION COMMAND ---
        if (msgType == 'delete_conversation') {
          debugPrint(
            'DEBUG: Received DELETE_CONVERSATION command for room $roomId',
          );
          // Verify sender is authorized (should be part of the chat)
          // If we decrypted it, we have their key, so it's likely valid.

          // Clear local messages for this room
          final myId = currentUser.uid;
          // We need to implement deleteConversation in LocalStorage or reuse deleteChat
          // deleteChat(roomId) in ChatRepository calls _local.deleteConversation

          // BUT wait, we are inside ChatRepository.
          // We should just call the local storage method directly to avoid side effects?
          // Actually, let's call existing logic.

          await _local.deleteConversation(myId, roomId);

          // Send ACK so relay deletes the command
          await _relay.sendAck(senderId: senderId, messageId: messageId);
          await _relay.deleteFromRelay(messageId);
          return;
        }
        // ----------------------------------------
        // --- NEW: SCREENSHOT PROTECTION COMMAND ---
        if (msgType == 'cmd_screenshot_protection_request') {
          debugPrint(
            'DEBUG: Received SCREENSHOT_PROTECTION_REQUEST from $senderId for $roomId: $msgContent',
          );
          final enabled = msgContent == '1' || msgContent == 'true';
          final myId = currentUser.uid;

          // Update Local: Enforced Remote Protection
          final room = _local.getConversation(myId, roomId) ??
              <String, dynamic>{
                'id': roomId,
                'unreadCount': 0,
                'lastMessage': '',
                'lastMessageTime': DateTime.now().millisecondsSinceEpoch,
              };
          room['isRemoteProtectionEnforced'] = enabled;
          await _local.updateConversation(myId, roomId, room);

          // ACK and Delete
          await _relay.sendAck(senderId: senderId, messageId: messageId);
          await _relay.deleteFromRelay(messageId);
          return;
        }
        // ----------------------------------------

        // --- NEW: GROUP CREATE COMMAND ---
        if (msgType == 'group_create') {
          debugPrint('DEBUG: Received GROUP_CREATE command for $roomId');

          final groupPayload = messagePayload;
          final existingGroup = _local.getConversation(
            currentUser.uid,
            groupPayload['id'],
          );

          if (existingGroup != null) {
            debugPrint(
              'SECURITY ALERT: GROUP_CREATE received for an existing group. Dropping to prevent hijack/overwrite.',
            );
            await _relay.sendAck(senderId: senderId, messageId: messageId);
            await _relay.deleteFromRelay(messageId);
            return;
          }

          final groupId = groupPayload['id'];
          if (groupId == null) return;

          try {
            final groupDoc = await _firestore
                .collection('group_chats')
                .doc(groupId)
                .get();
            if (!groupDoc.exists) {
              debugPrint(
                'SECURITY ALERT: Received group_create for non-existent Firestore group $groupId. Dropping.',
              );
              return; // Do NOT ACK. Let it retry later if Firestore is lagging.
            }

            final data = groupDoc.data()!;
            final realAdmins = List<String>.from(data['admins'] ?? []);
            final realParticipants = List<String>.from(
              data['participants'] ?? [],
            );

            if (!realAdmins.contains(senderId)) {
              debugPrint(
                'SECURITY ALERT: Sender $senderId is not an admin in Firestore. Forged invite!',
              );
              await _relay.sendAck(senderId: senderId, messageId: messageId);
              await _relay.deleteFromRelay(messageId);
              return;
            }

            if (!realParticipants.contains(currentUser.uid)) {
              debugPrint(
                'SECURITY ALERT: I am not in the real participants list in Firestore. Forged invite!',
              );
              await _relay.sendAck(senderId: senderId, messageId: messageId);
              await _relay.deleteFromRelay(messageId);
              return;
            }

            Map<String, List<String>>? parsedPerms;
            if (data['adminPermissions'] != null) {
              parsedPerms = {};
              final rawPerms = data['adminPermissions'] as Map;
              for (final entry in rawPerms.entries) {
                parsedPerms[entry.key.toString()] = List<String>.from(
                  entry.value,
                );
              }
            }

            // Build local room mixing secure Firestore data and benign Payload metadata
            final groupRoom = ChatRoom(
              id: groupId,
              participants: realParticipants, // FROM FIRESTORE
              lastMessage: 'تمت دعوتك للمجموعة',
              lastMessageTime: DateTime.now(),
              unreadCounts: {
                currentUser.uid: 1,
              }, // Mark as unread so they notice
              isGroup: true,
              groupName:
                  data['groupName'] ??
                  _readFieldText(groupPayload, const [
                    'groupName',
                    'name',
                    'title',
                  ]),
              groupIcon:
                  data['groupIcon'] ??
                  _readFieldText(groupPayload, const [
                    'groupIcon',
                    'icon',
                    'imageUrl',
                  ]),
              description:
                  data['description'] ??
                  _readFieldText(groupPayload, const ['description', 'desc']),
              admins: realAdmins, // FROM FIRESTORE
              deletedBy: [],
              isPublic: data['isPublic'] ?? groupPayload['isPublic'] ?? false,
              onlyAdminsCanPost:
                  data['onlyAdminsCanPost'] ??
                  groupPayload['onlyAdminsCanPost'] ??
                  false,
              groupHandle:
                  data['groupHandle'] ??
                  _readFieldText(groupPayload, const ['groupHandle', 'handle']),
              createdBy:
                  data['createdBy'] ??
                  senderId, // FROM FIRESTORE (or fallback to creator)
              adminPermissions: parsedPerms, // FROM FIRESTORE
              category: _readFieldText(groupPayload, const [
                'category',
                'groupCategory',
                'channelCategory',
                'categoryName',
                'category_name',
                'section',
                'sectionName',
                'section_name',
              ]),
              source: _readFieldText(groupPayload, const [
                'source',
                'sourceName',
                'source_name',
                'provider',
                'providerName',
                'provider_name',
                'playlist',
              ]),
            );

            await _local.updateConversation(
              currentUser.uid,
              groupId,
              groupRoom.toMap(),
            );

            await _relay.sendAck(senderId: senderId, messageId: messageId);
            await _relay.deleteFromRelay(messageId);
            return;
          } catch (e) {
            debugPrint(
              'ERROR: Failed to verify group_create from Firestore: $e',
            );
            // Do NOT ACK. Might be a network issue. Let Relay retry later.
            return;
          }
        }
        // ----------------------------------------

        // --- NEW: GROUP UPDATE COMMAND ---
        if (msgType == 'group_update') {
          debugPrint('DEBUG: Received GROUP_UPDATE for $roomId');
          final room = _local.getConversation(currentUser.uid, roomId);
          if (room != null) {
            if (!_hasGroupPermission(
              senderId,
              room,
              requiredPerm: 'change_info',
            )) {
              debugPrint(
                'SECURITY ALERT: Unauthorized GROUP_UPDATE from $senderId. Dropping.',
              );
              await _relay.sendAck(senderId: senderId, messageId: messageId);
              await _relay.deleteFromRelay(messageId);
              return;
            }
            final newRoom = Map<String, dynamic>.from(room);
            if (messagePayload['name'] != null) {
              newRoom['groupName'] = messagePayload['name'];
            }
            if (messagePayload['description'] != null) {
              newRoom['description'] = messagePayload['description'];
            }
            if (messagePayload['icon'] != null) {
              newRoom['groupIcon'] = messagePayload['icon'];
            }
            if (messagePayload['groupHandle'] != null) {
              newRoom['groupHandle'] = messagePayload['groupHandle'];
            }
            final updatedCategory = _readFieldText(messagePayload, const [
              'category',
              'groupCategory',
              'channelCategory',
              'categoryName',
              'category_name',
              'section',
              'sectionName',
              'section_name',
            ]);
            if (updatedCategory != null) {
              newRoom['category'] = updatedCategory;
            }
            final updatedSource = _readFieldText(messagePayload, const [
              'source',
              'sourceName',
              'source_name',
              'provider',
              'providerName',
              'provider_name',
              'playlist',
            ]);
            if (updatedSource != null) {
              newRoom['source'] = updatedSource;
            }
            if (messagePayload['isPublic'] != null) {
              newRoom['isPublic'] = messagePayload['isPublic'];
            }
            if (messagePayload['onlyAdminsCanPost'] != null) {
              newRoom['onlyAdminsCanPost'] =
                  messagePayload['onlyAdminsCanPost'];
            }
            await _local.updateConversation(currentUser.uid, roomId, newRoom);
          }
          await _relay.sendAck(senderId: senderId, messageId: messageId);
          await _relay.deleteFromRelay(messageId);
          return;
        }

        // --- NEW: GROUP MEMBER ADD ---
        if (msgType == 'group_member_add') {
          debugPrint('DEBUG: Received GROUP_MEMBER_ADD for $roomId');
          final room = _local.getConversation(currentUser.uid, roomId);
          if (room != null) {
            if (!_hasGroupPermission(
              senderId,
              room,
              requiredPerm: 'add_members',
            )) {
              debugPrint(
                'SECURITY ALERT: Unauthorized GROUP_MEMBER_ADD from $senderId. Dropping.',
              );
              await _relay.sendAck(senderId: senderId, messageId: messageId);
              await _relay.deleteFromRelay(messageId);
              return;
            }
            final addedIds = List<String>.from(
              messagePayload['added_ids'] ?? [],
            );
            final participants = List<String>.from(room['participants'] ?? []);

            // Merge unique
            final Set<String> unique = {...participants, ...addedIds};
            room['participants'] = unique.toList();

            await _local.updateConversation(currentUser.uid, roomId, room);
          }

          // إضافة رسالة نظام محلية (System Message)
          final addedIds = List<String>.from(messagePayload['added_ids'] ?? []);
          if (addedIds.isNotEmpty) {
            await _saveLocalSystemMessage(
              roomId,
              'تمت إضافة أعضاء جدد',
            );
          }

          await _relay.sendAck(senderId: senderId, messageId: messageId);
          await _relay.deleteFromRelay(messageId);
          return;
        }

        // --- NEW: GROUP MEMBER REMOVE ---
        if (msgType == 'group_member_remove') {
          debugPrint('DEBUG: Received GROUP_MEMBER_REMOVE for $roomId');
          final targetId = messagePayload['removed_id'];
          debugPrint(
            'DEBUG: Target removed_id=$targetId, currentUser.uid=${currentUser.uid}',
          );

          final room = _local.getConversation(currentUser.uid, roomId);
          if (room != null) {
            // --- SECURITY: SEPARATE SELF-LEAVE FROM ADMIN REMOVE ---
            if (senderId == targetId) {
              // Legitimate self-leave path
              debugPrint('DEBUG: Self-leave requested by $senderId');
            } else {
              // Must be authorized admin
              if (!_hasGroupPermission(
                senderId,
                room,
                requiredPerm: 'remove_members',
              )) {
                debugPrint(
                  'SECURITY ALERT: Unauthorized GROUP_MEMBER_REMOVE from $senderId. Dropping.',
                );
                await _relay.sendAck(senderId: senderId, messageId: messageId);
                await _relay.deleteFromRelay(messageId);
                return;
              }
            }
          }

          if (targetId == currentUser.uid) {
            // I was removed (or I left) -> Delete chat
            if (senderId == targetId) {
              debugPrint(
                'DEBUG: I left group $roomId voluntarily, deleting conversation',
              );
            } else {
              debugPrint(
                'DEBUG: I was removed from group $roomId by admin $senderId, deleting conversation',
              );
            }
            await _local.deleteConversation(currentUser.uid, roomId);
            debugPrint('DEBUG: Conversation $roomId deleted successfully');
          } else {
            // Someone else was removed
            debugPrint(
              'DEBUG: Someone else ($targetId) was removed, updating participants',
            );
            if (room != null) {
              final participants = List<String>.from(
                room['participants'] ?? [],
              );
              participants.remove(targetId);
              room['participants'] = participants;
              // Also remove from admins if they were one
              final admins = List<String>.from(room['admins'] ?? []);
              admins.remove(targetId);
              room['admins'] = admins;

              await _local.updateConversation(currentUser.uid, roomId, room);
              debugPrint('DEBUG: Updated group $roomId participants');
            }

            // إضافة رسالة نظام محلية عند مغادرة شخص آخر
            final user = await getUserData(targetId);
            final name = user?.displayName ?? 'ط¹ط¶ظˆ';
            await _saveLocalSystemMessage(
              roomId,
              '$name غادر المجموعة',
            );
          }
          await _relay.sendAck(senderId: senderId, messageId: messageId);
          await _relay.deleteFromRelay(messageId);
          return;
        }

        // --- NEW: GROUP ADMIN UPDATE ---
        if (msgType == 'group_admin_update') {
          debugPrint('DEBUG: Received GROUP_ADMIN_UPDATE for $roomId');
          final room = _local.getConversation(currentUser.uid, roomId);
          if (room != null) {
            if (!_hasGroupPermission(
              senderId,
              room,
              requiredPerm: 'manage_admins',
            )) {
              debugPrint(
                'SECURITY ALERT: Unauthorized GROUP_ADMIN_UPDATE from $senderId. Dropping.',
              );
              await _relay.sendAck(senderId: senderId, messageId: messageId);
              await _relay.deleteFromRelay(messageId);
              return;
            }
            final targetId = messagePayload['target_id'];
            final isPromote = messagePayload['is_promote'] ?? true;
            final admins = List<String>.from(room['admins'] ?? []);

            if (isPromote) {
              if (!admins.contains(targetId)) admins.add(targetId);

              // FIX: Assign default permissions so the new admin can actually DO things
              final perms =
                  (room['adminPermissions'] as Map?)?.map(
                    (key, value) => MapEntry(
                      key.toString(),
                      List<String>.from(value ?? []),
                    ),
                  ) ??
                  {};
              if (!perms.containsKey(targetId)) {
                perms[targetId] = [
                  'change_info',
                  'add_members',
                  'remove_members',
                  'manage_admins', // Default full access
                ];
                room['adminPermissions'] = perms;
              }
            } else {
              admins.remove(targetId);
              // Remove permissions on demote
              final perms =
                  (room['adminPermissions'] as Map?)?.map(
                    (key, value) => MapEntry(
                      key.toString(),
                      List<String>.from(value ?? []),
                    ),
                  ) ??
                  {};
              perms.remove(targetId);
              room['adminPermissions'] = perms;
            }
            room['admins'] = admins;
            await _local.updateConversation(currentUser.uid, roomId, room);
          }
          await _relay.sendAck(senderId: senderId, messageId: messageId);
          await _relay.deleteFromRelay(messageId);
          return;
        }

        // --- NEW: GROUP ADMIN PERMS UPDATE ---
        if (msgType == 'group_admin_perms_update') {
          debugPrint('DEBUG: Received GROUP_ADMIN_PERMS_UPDATE for $roomId');
          final room = _local.getConversation(currentUser.uid, roomId);
          if (room != null) {
            if (!_hasGroupPermission(
              senderId,
              room,
              requiredPerm: 'manage_admins',
            )) {
              debugPrint(
                'SECURITY ALERT: Unauthorized GROUP_ADMIN_PERMS_UPDATE from $senderId. Dropping.',
              );
              await _relay.sendAck(senderId: senderId, messageId: messageId);
              await _relay.deleteFromRelay(messageId);
              return;
            }
            final targetId = messagePayload['target_id'];
            final permissions = List<String>.from(
              messagePayload['permissions'] ?? [],
            );

            final perms =
                (room['adminPermissions'] as Map?)?.map(
                  (key, value) =>
                      MapEntry(key.toString(), List<String>.from(value ?? [])),
                ) ??
                {};

            perms[targetId] = permissions;
            room['adminPermissions'] = perms;

            await _local.updateConversation(currentUser.uid, roomId, room);
          }
          await _relay.sendAck(senderId: senderId, messageId: messageId);
          await _relay.deleteFromRelay(messageId);
          return;
        }
        // ----------------------------------------

        // CHECK FOR DELETE COMMAND
        if (msgType == 'delete') {
          final idToDelete = messagePayload['id']?.toString() ?? msgContent;

          if (idToDelete != null && idToDelete.isNotEmpty) {
            debugPrint('DEBUG: Processing DELETE command for $idToDelete');
            await _local.deleteMessage(currentUser.uid, roomId, idToDelete);
          }

          // ALWAYS ACK/DELETE/RETURN for delete type to prevent fall-through
          await _relay.sendAck(senderId: senderId, messageId: messageId);
          await _relay.deleteFromRelay(messageId);
          return;
        }

        // CHECK FOR EDIT COMMAND
        if (msgType == 'edit') {
          final targetMessageId =
              replyToId; // We use replyToId as target for edits
          final newText = msgContent;

          if (targetMessageId != null && newText.isNotEmpty) {
            debugPrint('DEBUG: Processing EDIT for message $targetMessageId');
            await _local.updateMessage(
              currentUser.uid,
              roomId,
              targetMessageId,
              {'text': newText, 'isEdited': true},
            );
          }

          // Always ack/delete
          await _relay.sendAck(senderId: senderId, messageId: messageId);
          await _relay.deleteFromRelay(messageId);
          return;
        }

        // CHECK FOR REACTION COMMAND
        if (msgType == 'reaction') {
          final targetMessageId =
              replyToId; // reaction targets a message via replyToId
          final emoji = msgContent;

          // ⚠️ Skip if this is my own reaction (already added locally)
          if (senderId == currentUser.uid) {
            debugPrint(
              'DEBUG: Skipping my own reaction (already applied locally)',
            );
            await _relay.sendAck(senderId: senderId, messageId: messageId);
            await _relay.deleteFromRelay(messageId);
            return;
          }

          if (targetMessageId != null && emoji.isNotEmpty) {
            debugPrint(
              'DEBUG: Processing REACTION $emoji for message $targetMessageId',
            );

            // Get the target message
            final messages = await _local.getMessages(currentUser.uid, roomId);
            final targetMsg = messages.firstWhere(
              (m) => m['id'] == targetMessageId,
              orElse: () => <String, dynamic>{},
            );

            if (targetMsg.isNotEmpty) {
              // Update reactions map - safe casting
              final existingReactions = targetMsg['reactions'];
              final reactions = <String, String>{};

              if (existingReactions != null && existingReactions is Map) {
                existingReactions.forEach((key, value) {
                  reactions[key.toString()] = value.toString();
                });
              }

              reactions[senderId] = emoji;

              // Update message with new reaction
              await _local.updateMessage(
                currentUser.uid,
                roomId,
                targetMessageId,
                {'reactions': reactions},
              );

              debugPrint('DEBUG: Reaction added successfully');
            }
          } else {
            debugPrint(
              'DEBUG: Invalid reaction payload (missing target/emoji)',
            );
          }

          // ALWAYS ACK/DELETE/RETURN for reaction type
          await _relay.sendAck(senderId: senderId, messageId: messageId);
          await _relay.deleteFromRelay(messageId);
          return;
        }

        // --- JOIN REQUEST ---
        if (msgType == 'join_request') {
          final requesterName = messagePayload['requesterName'] ?? 'Unknown';
          debugPrint(
            'DEBUG: Join request from $requesterName for group $roomId',
          );

          // Store in Local ChatRoom pendingRequests (for Admins)
          final room = _local.getConversation(currentUser.uid, roomId);
          if (room != null) {
            final pending = List<String>.from(room['pendingRequests'] ?? []);
            final requesterId = messagePayload['requesterId'];
            if (requesterId != null && !pending.contains(requesterId)) {
              pending.add(requesterId);
              room['pendingRequests'] = pending;
              await _local.updateConversation(currentUser.uid, roomId, room);

              // Show notification/message only if first request?
              // Actually we can just silently add to list, UI badges will update.
            }
          }

          // Don't save system message to avoid clutter.
          // Real-time badge update relies on LocalStorage update above.

          await _relay.sendAck(senderId: senderId, messageId: messageId);
          await _relay.deleteFromRelay(messageId);
          return;
        }

        // CHECK FOR READ RECEIPT
        if (msgType == 'read_receipt') {
          final targetRoomId = msgContent;
          debugPrint(
            'DEBUG: Processing READ RECEIPT from $senderId for room $targetRoomId',
          );

          // Update local messages: Add senderId to 'readBy' for messages in this room
          // We assume this means "User has seen the conversation up to now"
          await _local.markMessagesAsReadByOther(
            currentUser.uid,
            targetRoomId,
          );

          // Force UI update by explicitly updating the last message
          try {
            // Small delay to ensure batch update is committed
            await Future.delayed(const Duration(milliseconds: 50));

            final msgs = await _local.getMessages(
              currentUser.uid,
              targetRoomId,
            );
            if (msgs.isNotEmpty) {
              final lastMsg = Map<String, dynamic>.from(msgs.first);
              // Force status update to ensure a change is detected by the stream
              if (lastMsg['status'] != 'read') {
                lastMsg['status'] = 'read';
              }
              await _local.saveMessage(currentUser.uid, targetRoomId, lastMsg);
            }
          } catch (e) {
            debugPrint('DEBUG: Error forcing read receipt update: $e');
          }

          // Ack/Delete
          await _relay.sendAck(senderId: senderId, messageId: messageId);
          await _relay.deleteFromRelay(messageId);
          return;
        }

        // --- NEW: FILE RESYNC PROTOCOL ---
        if (msgType == 'file_request') {
          final targetMessageId = messagePayload['targetMessageId'];
          final reqRoomId = messagePayload['roomId'];
          debugPrint('DEBUG: Processing FILE_REQUEST for message $targetMessageId in room $reqRoomId');

          if (targetMessageId != null && reqRoomId != null) {
            // Find if I have the message
            final msgs = await _local.getMessages(currentUser.uid, reqRoomId);
            final msg = msgs.firstWhere((m) => m['id'] == targetMessageId, orElse: () => <String, dynamic>{});

            bool fileSent = false;
            if (msg.isNotEmpty) {
              // Extract file URL
              String? localPath = msg['imageUrl'] ?? msg['audioUrl'] ?? msg['fileUrl'];
              if (localPath != null) {
                final cleanPath = localPath.replaceFirst('file://', '');
                final file = File(cleanPath);
                
                if (file.existsSync()) {
                  // Re-send it
                  final fileType = msg['type'] ?? 'file';
                  final fileName = msg['fileName'] ?? cleanPath.split('/').last;
                  final fileSize = await file.length();
                  
                  // Use existing resync approach depending on size/type
                  if (fileSize > 1024 * 1024 || (fileType == 'file' && fileSize > 500 * 1024)) {
                    await _sendFileInChunks(
                      reqRoomId,
                      targetMessageId, // reuse original ID so it overwrites requester's side seamlessly
                      file,
                      fileName,
                      originalType: fileType,
                    );
                  } else {
                    await _sendEncryptedContent(
                      reqRoomId,
                      file.path,
                      fileType,
                      messageId: targetMessageId, // reuse original ID
                      fileName: fileName,
                    );
                  }
                  
                  fileSent = true;
                  debugPrint('DEBUG: File found, initiating resync for $targetMessageId');
                }
              }
            }

            if (!fileSent) {
              // File is permanently lost from my end too! Notify requester.
              debugPrint('DEBUG: File not found locally. Sending file_not_found relay to requester.');
              final notFoundMsgId = DateTime.now().millisecondsSinceEpoch.toString() + "_nf";
              await _sendEncryptedContent(
                reqRoomId,
                '',
                'file_not_found',
                messageId: notFoundMsgId,
                extraPayload: {'targetMessageId': targetMessageId},
              );
            }
          }

          // Ack/Delete the request message itself
          await _relay.sendAck(senderId: senderId, messageId: messageId);
          await _relay.deleteFromRelay(messageId);
          return;
        }

        if (msgType == 'file_not_found') {
          final targetMessageId = messagePayload['targetMessageId'];
          debugPrint('DEBUG: Received FILE_NOT_FOUND for message $targetMessageId');
          if (targetMessageId != null) {
            await _local.updateMessage(currentUser.uid, roomId, targetMessageId, {
              'status': 'permanently_lost',
            });
          }
          await _relay.sendAck(senderId: senderId, messageId: messageId);
          await _relay.deleteFromRelay(messageId);
          return;
        }

        // UNKNOWN/CONTROL TYPE GUARD
        // If it's not text, image, audio, and handled above, ignore it.
        // This prevents future control messages from showing up as ghosts.
        // --- NEW: CHUNKED FILE TRANSFER ---
        if (msgType == 'file_header') {
          debugPrint('DEBUG: Received FILE_HEADER for $messageId');
          final fileId = messagePayload['fileId'];
          final fileName = messagePayload['fileName'];
          final fileSize = messagePayload['fileSize'] is int
              ? messagePayload['fileSize'] as int
              : int.tryParse(messagePayload['fileSize'].toString()) ?? 0;
          final chunks = messagePayload['chunks'] is int
              ? messagePayload['chunks'] as int
              : int.tryParse(messagePayload['chunks'].toString()) ?? 1;
          final chunkSize = messagePayload['chunkSize'] is int
              ? messagePayload['chunkSize'] as int
              : int.tryParse(messagePayload['chunkSize'].toString()) ??
                    (512 * 1024);
          final fileHash = messagePayload['fileHash'] ?? '';

          // --- SECURITY: METADATA VALIDATION ---
          if (fileId == null || fileName == null) {
            debugPrint('SECURITY ALERT: Missing fileId or fileName. Dropping.');
            await _relay.sendAck(senderId: senderId, messageId: messageId);
            await _relay.deleteFromRelay(messageId);
            return;
          }

          if (fileSize <= 0 || fileSize > _maxFileSize) {
            debugPrint(
              'SECURITY ALERT: Invalid file size $fileSize. Max is $_maxFileSize. Dropping.',
            );
            await _relay.sendAck(senderId: senderId, messageId: messageId);
            await _relay.deleteFromRelay(messageId);
            return;
          }

          if (chunks <= 0 || chunks > _maxChunks) {
            debugPrint(
              'SECURITY ALERT: Invalid chunk count $chunks. Max is $_maxChunks. Dropping.',
            );
            await _relay.sendAck(senderId: senderId, messageId: messageId);
            await _relay.deleteFromRelay(messageId);
            return;
          }

          if (chunkSize <= 0 || chunkSize > _maxChunkSize) {
            debugPrint(
              'SECURITY ALERT: Invalid chunk size $chunkSize. Max is $_maxChunkSize. Dropping.',
            );
            await _relay.sendAck(senderId: senderId, messageId: messageId);
            await _relay.deleteFromRelay(messageId);
            return;
          }

          // --- SECURITY: MATHEMATICAL CONSISTENCY (BUG-03) ---
          final expectedChunks = (fileSize / chunkSize).ceil();
          if (chunks != expectedChunks) {
            debugPrint(
              'SECURITY ALERT: Invalid chunks math ($chunks != $expectedChunks). Dropping.',
            );
            await _relay.sendAck(senderId: senderId, messageId: messageId);
            await _relay.deleteFromRelay(messageId);
            return;
          }

          // --- SECURITY: REQUIRED CHECKSUM (BUG-04) ---
          final fileHashStr = fileHash.toString();
          if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(fileHashStr)) {
            debugPrint(
              'SECURITY ALERT: Missing or invalid SHA-256 fileHash. Dropping.',
            );
            await _relay.sendAck(senderId: senderId, messageId: messageId);
            await _relay.deleteFromRelay(messageId);
            return;
          }
          final normalizedFileHash = fileHashStr.toLowerCase();

          // --- SECURITY: DUPLICATE HEADER HANDLING ---
          if (_activeDownloads.containsKey(fileId)) {
            // If already downloading, check if metadata perfectly matches
            if (_downloadTotalChunks[fileId] == chunks &&
                _downloadChunkSizes[fileId] == chunkSize &&
                _downloadExpectedHashes[fileId] == normalizedFileHash &&
                _downloadFileNames[fileId] == fileName) {
              debugPrint(
                'DEBUG: Benign duplicate FILE_HEADER for $fileId. Ignoring.',
              );
            } else {
              debugPrint(
                'SECURITY ALERT: Conflicting duplicate FILE_HEADER for $fileId. Dropping.',
              );
            }
            await _relay.sendAck(senderId: senderId, messageId: messageId);
            await _relay.deleteFromRelay(messageId);
            return;
          }

          // Create Placeholder Message
          final dir = await getApplicationDocumentsDirectory();
          final tempPath = '${dir.path}/${fileId}_temp';

          // Initialize Download State
          final file = await File(tempPath).open(mode: FileMode.write);
          _activeDownloads[fileId] = file;
          _downloadReceivedChunks[fileId] = <int>{};
          _downloadTotalChunks[fileId] = chunks;
          _downloadChunkSizes[fileId] = chunkSize;
          _downloadExpectedHashes[fileId] = normalizedFileHash;
          _downloadFileNames[fileId] = fileName;

          final message = {
            'id': messageId, // Use the header's ID as the main message ID
            'senderId': senderId,
            'text': '',
            'fileUrl': null,
            'fileName': fileName,
            'fileSize': fileSize,
            'transferProgress': 0.0,
            'fileId': fileId,
            'timestamp':
                data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
            'isRead': false,
            'type': 'file', // Show as file type in UI immediately
            'replyToId': replyToId,
            'replySnapshot': messagePayload['replySnapshot'],
            'status': 'receiving',
          };

          await _local.saveMessage(currentUser.uid, roomId, message);

          await _relay.sendAck(senderId: senderId, messageId: messageId);
          await _relay.deleteFromRelay(messageId);
          return;
        }

        if (msgType == 'file_chunk') {
          final fileId = messagePayload['fileId'];
          final chunkData = messagePayload['chunkData']; // Base64
          final chunkIndex = messagePayload['chunkIndex'];

          if (fileId != null &&
              chunkData != null &&
              chunkIndex != null &&
              _activeDownloads.containsKey(fileId)) {
            // --- SECURITY: PREVENT RACE CONDITIONS (P1-8) ---
            final previousLock = _downloadLocks[fileId];
            final completer = Completer<void>();
            _downloadLocks[fileId] = completer.future;

            try {
              if (previousLock != null) {
                await previousLock;
              }

              // Check if download was cancelled/cleaned up while waiting for lock
              if (!_activeDownloads.containsKey(fileId)) {
                return;
              }

              final totalChunks = _downloadTotalChunks[fileId] ?? 1;

              // NEW: Strict bounds validation against Disk DoS
              if (chunkIndex < 0 ||
                  chunkIndex >= totalChunks ||
                  totalChunks > 100000) {
                debugPrint(
                  'SECURITY ALERT: Invalid chunk index ($chunkIndex) or totalChunks ($totalChunks). Dropping.',
                );
                return;
              }

              if (chunkIndex >= 0 && chunkIndex < totalChunks) {
                final bytes = base64Decode(chunkData);
                final raf = _activeDownloads[fileId]!;
                final chunkSize = _downloadChunkSizes[fileId] ?? (512 * 1024);
                final offset = chunkIndex * chunkSize;

                // Validate chunk size (last chunk can be smaller)
                if (bytes.length > chunkSize) {
                  debugPrint(
                    'SECURITY ALERT: Chunk payload larger than chunkSize. Dropping.',
                  );
                  return;
                }

                await raf.setPosition(offset);
                await raf.writeFrom(bytes);

                // Track chunk
                final receivedSet = _downloadReceivedChunks[fileId];
                if (receivedSet != null) {
                  receivedSet.add(chunkIndex);
                }

                // Update Progress
                final received = receivedSet?.length ?? 0;
                final progress = received / totalChunks;

                final updatedFields = {
                  'transferProgress': progress,
                  'status': 'receiving',
                };

                await _local.updateMessage(
                  currentUser.uid,
                  roomId,
                  fileId,
                  updatedFields,
                );

                // --- SECURITY: CHUNK COMPLETION VERIFICATION (P1-1) ---
                bool isComplete = received == totalChunks;
                if (isComplete && receivedSet != null) {
                  for (int i = 0; i < totalChunks; i++) {
                    if (!receivedSet.contains(i)) {
                      isComplete = false;
                      break;
                    }
                  }
                }

                if (isComplete) {
                  debugPrint(
                    'DEBUG: File download chunks complete and verified for $fileId',
                  );
                  await raf.flush();
                  await raf.close();
                  _activeDownloads.remove(fileId);

                  // Hash Verification
                  final dir = await getApplicationDocumentsDirectory();
                  final tempFile = File('${dir.path}/${fileId}_temp');

                  final expectedHash = _downloadExpectedHashes[fileId] ?? '';
                  String actualHash = '';
                  if (expectedHash.isNotEmpty) {
                    final digest = await sha256.bind(tempFile.openRead()).first;
                    actualHash = digest.toString();
                  }

                  if (expectedHash.isNotEmpty && actualHash != expectedHash) {
                    debugPrint(
                      'SECURITY ALERT: Checksum mismatch for $fileId. Expected: $expectedHash, Actual: $actualHash. Dropping.',
                    );
                    await tempFile.delete();
                    await _local.updateMessage(
                      currentUser.uid,
                      roomId,
                      fileId,
                      {'status': 'failed_checksum'},
                    );
                  } else {
                    debugPrint(
                      'DEBUG: File checksum verified successfully for $fileId',
                    );
                    // Rename to final
                    final finalName =
                        '${DateTime.now().millisecondsSinceEpoch}_${_downloadFileNames[fileId]}';
                    final finalPath = '${dir.path}/$finalName';

                    await tempFile.rename(finalPath);

                    // Finalize Message
                    await _local.updateMessage(
                      currentUser.uid,
                      roomId,
                      fileId,
                      {
                        'transferProgress': 1.0,
                        'status': 'sent',
                        'fileUrl': finalPath, // Local path
                      },
                    );
                  }

                  // Clean up state
                  _downloadReceivedChunks.remove(fileId);
                  _downloadTotalChunks.remove(fileId);
                  _downloadChunkSizes.remove(fileId);
                  _downloadExpectedHashes.remove(fileId);
                  _downloadFileNames.remove(fileId);
                  _downloadLocks.remove(fileId);
                }
              } else {
                debugPrint(
                  'DEBUG: Out of bounds chunkIndex $chunkIndex for $fileId',
                );
              }
            } catch (e) {
              debugPrint('Error writing chunk: $e');
            } finally {
              completer.complete();
            }
          } else {
            debugPrint(
              'DEBUG: Orphaned chunk for $fileId (or download cancelled/not started)',
            );
          }

          // Always Ack Chunk
          await _relay.sendAck(senderId: senderId, messageId: messageId);
          await _relay.deleteFromRelay(messageId);
          return;
        }

        // UNKNOWN/CONTROL TYPE GUARD
        // If it's not text, image, audio, and handled above, ignore it.
        // This prevents future control messages from showing up as ghosts.
        if (!['text', 'image', 'audio', 'file'].contains(msgType)) {
          debugPrint(
            'DEBUG: Unknown message type caught: $msgType. Skipping save.',
          );
          await _relay.sendAck(senderId: senderId, messageId: messageId);
          await _relay.deleteFromRelay(messageId);
          return;
        }

        String text = '';
        String? imageUrl;
        String? audioUrl;

        if (msgType == 'text') text = msgContent;
        if (msgType == 'image') {
          // Save Base64 to File
          imageUrl = await _saveBase64ToFile(msgContent, 'image');
        }
        if (msgType == 'audio') {
          audioUrl = await _saveBase64ToFile(msgContent, 'audio');
        }

        String? fileUrl;
        String? fileName;
        if (msgType == 'file') {
          fileName = messagePayload['fileName'];
          fileUrl = await _saveBase64ToFile(
            msgContent,
            'file',
            fileName: fileName,
          );
        }

        final message = {
          'id': messageId,
          'senderId': senderId,
          'text': text,
          'imageUrl': imageUrl,
          'audioUrl': audioUrl,
          'fileUrl': fileUrl,
          'fileName': fileName,
          'timestamp':
              data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
          'isRead': false,
          'type': msgType,
          'replyToId': replyToId,
          'replySnapshot': messagePayload['replySnapshot'],
        };

        // 3. Save Local
        debugPrint(
          'DEBUG: Saving message locally to ${currentUser.uid}/$roomId',
        );

        // P2P Sync Persistence: Mark as active conversation (1-on-1 only)
        if (!roomId.startsWith('group_')) {
          _markConversationActive(senderId);
        }

        await _local.saveMessage(currentUser.uid, roomId, message);

        String previewText = text;
        if (msgType == 'image') previewText = '📷 صورة';
        if (msgType == 'audio') previewText = '🎤 رسالة صوتية';
        if (msgType == 'file')
          previewText = '📁 ملف: ${fileName ?? "مستند"}';

        // Update Conversation List (Unread + Last Message)
        await _updateLocalConversation(
          roomId,
          previewText,
          DateTime.fromMillisecondsSinceEpoch(
            data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
          ),
          incrementUnread: true,
        );

        // 4. Send ACK
        await _relay.sendAck(senderId: senderId, messageId: messageId);

        // 5. Delete from Relay (Self-Cleanup)
        await _relay.deleteFromRelay(messageId);

        // --- SECURITY: REPLAY PROTECTION ---
        // Only mark processed after full success
        if (currentHash != null) {
          await _local.markMessageHashProcessed(currentUser.uid, currentHash!);
        }
      } catch (e) {
        debugPrint('DEBUG: Error processing relay message: $e');
        // If the error is fatal (like Block truncated/Decryption failure), we should delete the message
        // to prevent it from blocking the queue or causing repeat failures.
        // For now, we delete ALL failed messages to keep the inbox clean.
        // Ideally we would move to a Dead Letter Queue.
        try {
          debugPrint(
            'DEBUG: Deleting corrupted message $messageId from relay.',
          );
          await _relay.deleteFromRelay(messageId);
        } catch (delError) {
          debugPrint('DEBUG: Failed to delete corrupted message: $delError');
        }
      } finally {
        // --- SECURITY: REPLAY PROTECTION ---
        // Always clean up in-flight state to prevent memory leaks on returns
        if (currentHash != null) {
          _processingMessageHashes.remove(currentHash);
        }
      }
    });
  }

  // ---------------------------------------------------------------------------
  // HELPER: Save Base64 to Local File
  // ---------------------------------------------------------------------------
  Future<String> _saveBase64ToFile(
    String base64String,
    String type, {
    String? fileName,
  }) async {
    try {
      final bytes = base64Decode(base64String);
      final dir = await getApplicationDocumentsDirectory();
      String ext;
      if (fileName != null && fileName.contains('.')) {
        ext = fileName.split('.').last;
      } else {
        ext = type == 'audio' ? 'm4a' : (type == 'file' ? 'dat' : 'jpg');
      }

      final finalName = fileName != null
          ? '${DateTime.now().millisecondsSinceEpoch}_$fileName'
          : '${DateTime.now().millisecondsSinceEpoch}.$ext';

      final file = File('${dir.path}/$finalName');
      await file.writeAsBytes(bytes);
      debugPrint('DEBUG: Saved $type to ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('DEBUG: Failed to save Base64 to file: $e');
      return ''; // Fallback, though UI will show error
    }
  }

  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // UNIFIED SENDING LOGIC (Text & Media)
  // ---------------------------------------------------------------------------
  Future<void> _sendEncryptedContent(
    String roomId,
    String content, // Text or URL
    String type, { // 'text', 'image', 'audio', 'file'
    String? replyToId,
    Map<String, dynamic>? replySnapshot, // Snapshot of the replied message
    String? messageId, // Optional, enables optimistic updates
    String? fileName, // Added for files
    Map<String, dynamic>? extraPayload, // Added for flexibility (chunks)
  }) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final finalMessageId = messageId ?? timestamp.toString();

    // 1. Determine Receivers (1-on-1 or Group Fan-out)
    List<String> receiverIds = [];

    // Check if it's a group
    // Check if it's a group
    final chatData = _local.getConversation(myId, roomId);
    // FIX: Fallback to checking ID format if metadata is missing/false
    final isGroup = chatData?['isGroup'] == true || roomId.startsWith('group_');

    if (isGroup) {
      final participants = List<String>.from(chatData?['participants'] ?? []);

      // CRITICAL CHECK: Am I still a member?
      if (!participants.contains(myId)) {
        debugPrint(
          'SECURITY BLOCK: User $myId is not in participants list of group $roomId. Sending blocked.',
        );
        // We could also show a UI error if we could return one, but this returns void.
        // The UI should ideally react to this state, but blocking here protects the system.
        // throw Exception('You are not a member of this group');
        // Throwing might crash UI if not caught. Safest is to return early.
        return;
      }

      receiverIds = participants.where((id) => id != myId).toList();
    } else {
      // 1-on-1 fallback
      receiverIds = [_getReceiverIdFromRoom(roomId, myId)];

      // P2P Sync Persistence: Mark as active conversation (sending side)
      if (receiverIds.isNotEmpty && receiverIds.first != 'unknown') {
        _markConversationActive(receiverIds.first);
      }
    }

    if (receiverIds.isEmpty && isGroup) {
      debugPrint('DEBUG: Group has no other participants. Sending aborted.');
      return;
    }

    debugPrint(
      'DEBUG: Sending to ${receiverIds.length} receivers: $receiverIds',
    );
    debugPrint('DEBUG: GroupId Payload Flag: ${isGroup ? roomId : "NULL"}');

    // 2. Save Local (Pending/Sent) - SKIPPED FOR COMMANDS
    final isCommand = [
      'reaction',
      'delete',
      'edit',
      'delete_conversation',
      'cmd_screenshot_protection_request', // Added
      'file_header',
      'file_chunk',
    ].contains(type);

    Map<String, dynamic>? localMsg;

    if (!isCommand) {
      // Map content to correct field
      String text = '';
      String? imageUrl;
      String? audioUrl;
      String? fileUrl;

      if (type == 'text') text = content;
      if (type == 'image') imageUrl = content;
      if (type == 'audio') audioUrl = content;
      if (type == 'file') fileUrl = content;

      localMsg = {
        'id': finalMessageId,
        'senderId': myId,
        'text': text,
        'imageUrl': imageUrl,
        'audioUrl': audioUrl,
        'fileUrl': fileUrl,
        'fileName': fileName,
        'timestamp': timestamp,
        'isRead': false,
        'type': type,
        'replyToId': replyToId,
        'replySnapshot': replySnapshot, // Store snapshot locally
        'status': 'pending',
      };

      if (type == 'text') {
        await _local.saveMessage(myId, roomId, localMsg);
        await _updateLocalConversation(roomId, content, DateTime.now());
      }
      // Image/Audio callers save their own initial state, we update later.
    }

    // 3. OFFLINE CHECK
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOnline = connectivityResult.any(
      (r) => r == ConnectivityResult.mobile || r == ConnectivityResult.wifi,
    );

    if (!isOnline && !isCommand) {
      debugPrint('DEBUG: Offline. Message $finalMessageId queued as sending.');
      return;
    }

    // 4. Send Loop
    bool allFailed = true;

    for (final receiverId in receiverIds) {
      try {
        if (receiverId == 'unknown') continue;

        // Get Key
        final receiverKey = await _keyRepo.getUserPublicKey(receiverId);
        if (receiverKey == null) {
          debugPrint('DEBUG: No public key for user $receiverId. Skipping.');
          continue;
        }

        // Encrypt JSON Payload (OFFLOADED TO ISOLATE)
        final myPrivateKey = await CryptoService().getPrivateKeyPem();

        final encryptionArgs = {
          'type': type,
          'content': content,
          'replyToId': replyToId,
          'replySnapshot': replySnapshot, // Include in encrypted payload
          'receiverKey': receiverKey,
          'groupId': isGroup ? roomId : null, // Pass groupId if it's a group
          'senderPrivateKey': myPrivateKey,
          'fileName': fileName,
          'extraPayload': extraPayload,
        };

        final encryptedBundle = await compute(
          _encryptInBackground,
          encryptionArgs,
        );

        // Push to Relay
        // For groups, we use the SAME messageId so ACK handling is simpler?
        // Or unique command ID?
        // We use finalMessageId (the message ID).
        // NOTE: If multiple users ACK the same messageId, we need to handle that.
        // Currently ACKs delete from Relay.
        // If I push messageID 'msg1' to userA and userB...
        // Relay stores at relay_messages/userA/msg1 and relay_messages/userB/msg1
        // So they are independent paths! Safe to use same messageId.

        await _relay.pushToRelay(
          receiverId: receiverId,
          messageId: finalMessageId,
          encryptedBundle: encryptedBundle,
        );
        allFailed = false;
        
        // Send Push Notification via client-side FCM
        if (!isCommand) {
          try {
            final userDoc = await FirebaseFirestore.instance.collection('users').doc(receiverId).get();
            final fcmToken = userDoc.data()?['fcmToken'];
            if (fcmToken != null && fcmToken.toString().isNotEmpty) {
              String senderName = _auth.currentUser?.displayName ?? 'مستخدم';
              String pushTitle = isGroup ? 'رسالة جديدة في المجموعة' : senderName;
              String pushBody = 'لديك رسالة جديدة';
              
              if (type == 'text') {
                pushBody = content;
              } else if (type == 'image') {
                pushBody = '📷 صورة جديدة';
              } else if (type == 'audio') {
                pushBody = '🎵 مقطع صوتي';
              } else if (type == 'file') {
                pushBody = '📁 ملف جديد';
              }
              
              if (isGroup) {
                pushBody = '$senderName: $pushBody';
              }
              
              await PushNotificationService().sendPushMessage(
                targetToken: fcmToken,
                title: pushTitle,
                body: pushBody,
                data: {'roomId': roomId},
              );
            }
          } catch (pushErr) {
            debugPrint('DEBUG: Failed to send push notification to $receiverId: $pushErr');
          }
        }
      } catch (e) {
        debugPrint('DEBUG: Send failed to $receiverId: $e');
      }
    }

    // 4. Update Status (Local)
    if (localMsg != null) {
      localMsg['status'] = allFailed ? 'failed' : 'sent';
      await _local.saveMessage(myId, roomId, localMsg);
    }
  }

  // --- Get Read Receipts ---
  Future<List<String>> getMessageReadBy(String roomId, String messageId) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return [];
    final msgs = await _local.getMessages(myId, roomId);
    final msg = msgs.firstWhere((m) => m['id'] == messageId, orElse: () => {});
    return List<String>.from(msg['readBy'] ?? []);
  }

  // ---------------------------------------------------------------------------
  // PUBLIC ACCESSORS
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getMessagesOnce(String roomId) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return [];
    final msgs = await _local.getMessages(myId, roomId);
    // Sort by timestamp descending (newest first)
    msgs.sort((a, b) {
      final tA = a['timestamp'] ?? 0;
      final tB = b['timestamp'] ?? 0;
      return tB.compareTo(tA);
    });

    return msgs;
  }

  Future<List<Map<String, dynamic>>> getMessagesPaginated(
    String roomId, {
    int offset = 0,
    int limit = 20,
  }) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return [];
    return await _local.getMessagesPaginated(
      myId,
      roomId,
      offset: offset,
      limit: limit,
    );
  }

  bool amIAdmin(String roomId) {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return false;

    final room = _local.getConversation(myId, roomId);
    if (room == null) return false;

    return _hasGroupPermission(myId, room);
  }

  bool _hasGroupPermission(
    String userId,
    Map<String, dynamic> room, {
    String? requiredPerm,
  }) {
    // Check if creator (legacy or current)
    final bool isCreator = room['createdBy'] == userId;
    final bool isLegacyCreator =
        room['id'] != null &&
        room['id'].toString().endsWith('_$userId') &&
        room['createdBy'] == null;
    final bool isOwner = isCreator || isLegacyCreator;

    if (isOwner) return true;

    // Check admin list
    final admins = List<String>.from(room['admins'] ?? []);
    if (!admins.contains(userId)) return false;

    // If no specific permission requested, being an admin is enough
    if (requiredPerm == null) return true;

    // Check specific permission
    final permissionsMap =
        (room['adminPermissions'] as Map?)?.map(
          (key, value) =>
              MapEntry(key.toString(), List<String>.from(value ?? [])),
        ) ??
        {};
    final userPerms = permissionsMap[userId] ?? [];
    return userPerms.contains(requiredPerm);
  }

  // ---------------------------------------------------------------------------
  // HELPER FOR BACKGROUND ENCRYPTION
  // ---------------------------------------------------------------------------
  static Future<Map<String, dynamic>> _encryptInBackground(
    Map<String, dynamic> args,
  ) async {
    final type = args['type'] as String;
    String content = args['content'] as String;
    final replyToId = args['replyToId'] as String?;
    final replySnapshot = args['replySnapshot'] as Map<String, dynamic>?;
    final receiverKey = args['receiverKey'] as String;
    final groupId = args['groupId'] as String?; // Receive groupId

    // If content is a file path (for image/audio/file), read and encode it here
    if (type == 'image' || type == 'audio' || type == 'file') {
      final file = File(content);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        content = base64Encode(bytes);
      }
    }

    final payloadMap = {
      'type': type,
      'content': content,
      if (replyToId != null) 'replyToId': replyToId,
      if (replySnapshot != null) 'replySnapshot': replySnapshot,
      if (groupId != null) 'groupId': groupId,
      if (args['fileName'] != null) 'fileName': args['fileName'],
    };

    // Merge extra payload
    if (args['extraPayload'] != null) {
      payloadMap.addAll(args['extraPayload'] as Map<String, dynamic>);
    }

    final payloadJson = jsonEncode(payloadMap);
    final senderPrivateKey = args['senderPrivateKey'] as String?;

    final bundle = await EncryptionHelper.encryptMessage(
      payloadJson,
      receiverKey,
    );

    if (senderPrivateKey != null) {
      final signature = _signPayload(payloadJson, senderPrivateKey);
      if (signature != null) {
        bundle['signature'] = signature;
      }
    }

    return bundle;
  }

  Future<void> sendReaction(
    String roomId,
    String messageId,
    String emoji,
  ) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    // 1. Update local message first (optimistic update)
    try {
      final messages = await _local.getMessages(myId, roomId);
      final targetMsg = messages.firstWhere(
        (m) => m['id'] == messageId,
        orElse: () => <String, dynamic>{},
      );

      if (targetMsg.isNotEmpty) {
        // Update reactions map - safe casting
        final existingReactions = targetMsg['reactions'];
        final reactions = <String, String>{};

        if (existingReactions != null && existingReactions is Map) {
          existingReactions.forEach((key, value) {
            reactions[key.toString()] = value.toString();
          });
        }

        // Add or update my reaction
        reactions[myId] = emoji;

        // Update message locally
        await _local.updateMessage(myId, roomId, messageId, {
          'reactions': reactions,
        });

        debugPrint(
          'DEBUG: Reaction $emoji added locally to message $messageId',
        );
      }
    } catch (e) {
      debugPrint('DEBUG: Failed to add reaction locally: $e');
    }

    // 2. Send reaction command to other user via relay
    await _sendEncryptedContent(
      roomId,
      emoji,
      'reaction',
      replyToId: messageId,
    );
  }

  // Edit Message
  Future<void> editMessage(
    String roomId,
    String messageId,
    String newText,
  ) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    // 1. Optimistic Update Local
    await _local.updateMessage(myId, roomId, messageId, {
      'text': newText,
      'isEdited': true,
    });

    // 2. Send Command
    await _sendEncryptedContent(
      roomId,
      newText,
      'edit',
      replyToId: messageId, // Target message ID
    );
  }

  // Send Message (Text)
  Future<void> sendMessage(
    String roomId,
    String text, {
    String? replyToId,
    Map<String, dynamic>? replySnapshot, // Added
  }) async {
    await _sendEncryptedContent(
      roomId,
      text,
      'text',
      replyToId: replyToId,
      replySnapshot: replySnapshot,
    );
  }

  // Send Image
  Future<void> sendImageMessage(
    String roomId,
    dynamic file, {
    String? replyToId,
    Map<String, dynamic>? replySnapshot, // Added
  }) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    // Generate ID for optimistic update
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();

    // Optimistic Save (Pending with Local Path)
    final String localPath = (file is File)
        ? file.path
        : (file as dynamic).path;

    // Create temporary pending message
    final pendingMsg = {
      'id': messageId,
      'senderId': myId,
      'text': '',
      'imageUrl': localPath,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'isRead': false,
      'type': 'image',
      'replyToId': replyToId, // Added replyToId
      'status': 'uploading',
    };
    await _local.saveMessage(myId, roomId, pendingMsg);

    // 2. Send (Encrypted Content with Base64) or Chunked
    try {
      File imageFile;
      if (file is File) {
        imageFile = file;
      } else {
        imageFile = File((file as dynamic).path);
      }

      final fileSize = await imageFile.length();
      if (fileSize > 1024 * 1024) {
        // > 1 MB -> Chunk it
        debugPrint('DEBUG: Image size $fileSize > 1MB. Using Chunked Upload.');
        await _sendFileInChunks(
          roomId,
          messageId,
          imageFile,
          imageFile.path.split('/').last,
          replyToId: replyToId,
          replySnapshot: replySnapshot,
          originalType: 'image',
        );
      } else {
        // 1. Pass PATH to _sendEncryptedContent directly.
        // Do NOT read bytes here on main thread.
        debugPrint(
          'DEBUG: Sending encrypted image content (background processing)...',
        );

        await _sendEncryptedContent(
          roomId,
          imageFile.path, // Pass PATH, not content
          'image',
          messageId: messageId,
          replyToId: replyToId,
          replySnapshot: replySnapshot, // Pass snapshot
        );
        debugPrint('DEBUG: Encrypted image sent.');
      }
    } catch (e) {
      debugPrint('Image send failed: $e');
      pendingMsg['status'] = 'failed';
      await _local.saveMessage(myId, roomId, pendingMsg);
    }
  }

  Future<void> sendFileMessage(
    String roomId,
    File file,
    String fileName, {
    String? replyToId,
    Map<String, dynamic>? replySnapshot,
  }) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    final messageId = DateTime.now().millisecondsSinceEpoch.toString();

    // Optimistic Save
    final pendingMsg = {
      'id': messageId,
      'senderId': myId,
      'text': '',
      'fileUrl': file.path, // Local path
      'fileName': fileName,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'isRead': false,
      'type': 'file',
      'replyToId': replyToId,
      'replySnapshot': replySnapshot,
      'status': 'uploading',
    };
    await _local.saveMessage(myId, roomId, pendingMsg);

    try {
      final fileSize = await file.length();
      if (fileSize > 500 * 1024) {
        // > 500KB -> Chunk it
        await _sendFileInChunks(
          roomId,
          messageId,
          file,
          fileName,
          replyToId: replyToId,
          replySnapshot: replySnapshot,
        );
      } else {
        await _sendEncryptedContent(
          roomId,
          file.path,
          'file',
          messageId: messageId,
          replyToId: replyToId,
          replySnapshot: replySnapshot,
          fileName: fileName,
        );
        // Mark sent
        await _local.updateMessage(myId, roomId, messageId, {'status': 'sent'});
      }
    } catch (e) {
      debugPrint('File send failed: $e');
      pendingMsg['status'] = 'failed';
      await _local.saveMessage(myId, roomId, pendingMsg);
    }
  }

  Future<void> _sendFileInChunks(
    String roomId,
    String messageId,
    File file,
    String fileName, {
    String? replyToId,
    Map<String, dynamic>? replySnapshot,
    String originalType = 'file',
  }) async {
    final fileSize = await file.length();
    final chunkSize = 512 * 1024; // 512KB chunks (Faster)
    final totalChunks = (fileSize / chunkSize).ceil();

    debugPrint(
      'DEBUG: Sending $originalType $fileName in $totalChunks chunks (Size: $fileSize)',
    );

    // Compute SHA-256 of the whole file before chunking
    final digest = await sha256.bind(file.openRead()).first;
    final fileHash = digest.toString();

    // 1. Send Header
    await _sendEncryptedContent(
      roomId,
      '', // No content in header, just metadata
      'file_header',
      messageId: messageId,
      replyToId: replyToId,
      replySnapshot: replySnapshot,
      fileName: fileName,
      extraPayload: {
        'fileId': messageId,
        'fileName': fileName,
        'fileSize': fileSize,
        'chunks': totalChunks,
        'chunkSize': chunkSize,
        'fileHash': fileHash,
        'fileType': originalType,
      },
    );

    // 2. Send Chunks
    final raf = await file.open();

    try {
      for (int i = 0; i < totalChunks; i++) {
        final bytes = await raf.read(chunkSize);
        final chunkBase64 = base64Encode(bytes);
        final chunkMsgId = '${messageId}_chunk_$i';

        // Wait a small bit to avoid flooding
        if (i % 3 == 0) await Future.delayed(const Duration(milliseconds: 50));

        await _sendEncryptedContent(
          roomId,
          '', // Content is in extraPayload
          'file_chunk',
          messageId: chunkMsgId,
          extraPayload: {
            'fileId': messageId,
            'chunkIndex': i,
            'chunkData': chunkBase64,
          },
        );

        // Update Progress Locally match UI expectations
        final progress = (i + 1) / totalChunks;
        await _local.updateMessage(_auth.currentUser!.uid, roomId, messageId, {
          'transferProgress': progress,
        });
      }
    } catch (e) {
      debugPrint('Chunk send failed: $e');
      await _local.updateMessage(_auth.currentUser!.uid, roomId, messageId, {
        'status': 'failed',
      });
      rethrow;
    } finally {
      await raf.close();
    }

    // Final Update
    await _local.updateMessage(_auth.currentUser!.uid, roomId, messageId, {
      'transferProgress': 1.0,
      'status': 'sent',
      'fileUrl': file.path,
    });
    debugPrint('DEBUG: Chunked send complete');
  }

  // Send Audio
  Future<void> sendAudioMessage(
    String roomId,
    dynamic file, {
    String? replyToId,
    Map<String, dynamic>? replySnapshot, // Added
  }) async {
    debugPrint('DEBUG: sendAudioMessage called for room $roomId');
    final myId = _auth.currentUser?.uid;
    if (myId == null) {
      debugPrint('DEBUG: sendAudioMessage aborted. User not logged in.');
      return;
    }

    final messageId = DateTime.now().millisecondsSinceEpoch.toString();

    // Optimistic Save
    final String localPath = (file is File)
        ? file.path
        : (file as dynamic).path;
    debugPrint('DEBUG: Local audio path: $localPath');

    final pendingMsg = {
      'id': messageId,
      'senderId': myId,
      'text': '',
      'audioUrl': localPath,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'isRead': false,
      'type': 'audio',
      'replyToId': replyToId, // Added replyToId
      'status': 'uploading',
    };
    debugPrint('DEBUG: Saving pending audio message locally...');
    await _local.saveMessage(myId, roomId, pendingMsg);

    try {
      File audioFile;
      if (file is File) {
        audioFile = file;
      } else {
        audioFile = File((file as dynamic).path);
      }

      final fileSize = await audioFile.length();
      if (fileSize > 1024 * 1024) {
        // > 1 MB -> Chunk it
        debugPrint('DEBUG: Audio size $fileSize > 1MB. Using Chunked Upload.');
        await _sendFileInChunks(
          roomId,
          messageId,
          audioFile,
          audioFile.path.split('/').last,
          replyToId: replyToId,
          replySnapshot: replySnapshot,
          originalType: 'audio',
        );
      } else {
        // 1. Pass PATH to _sendEncryptedContent directly.
        debugPrint(
          'DEBUG: Sending encrypted audio content (background processing)...',
        );

        await _sendEncryptedContent(
          roomId,
          audioFile.path, // Pass PATH
          'audio',
          messageId: messageId,
          replyToId: replyToId,
          replySnapshot: replySnapshot,
        );
        debugPrint('DEBUG: Encrypted audio sent.');
      }
    } catch (e) {
      debugPrint('DEBUG: Audio send failed: $e');
      pendingMsg['status'] = 'failed';
      await _local.saveMessage(myId, roomId, pendingMsg);
    }
  }

  /// Request a file resync from the peer if the local file is missing.
  Future<void> requestFileResync(String roomId, String messageId) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    // 1. Update local status to requesting_resync
    await _local.updateMessage(myId, roomId, messageId, {
      'status': 'requesting_resync',
    });

    // 2. Fetch the room to get the peer ID
    final room = _local.getConversation(myId, roomId);
    if (room == null) return;
    
    // Determine receiver
    String receiverId = '';
    if (room['isGroup'] == true) {
      // In groups, ideally we'd ask the sender, but for simplicity we can ask the sender of this specific message
      final msgs = await _local.getMessages(myId, roomId);
      final msg = msgs.firstWhere((m) => m['id'] == messageId, orElse: () => <String, dynamic>{});
      if (msg.isNotEmpty && msg['senderId'] != null) {
        receiverId = msg['senderId'];
      }
    } else {
      // In 1on1, the receiver is the other participant
      final participants = List<String>.from(room['participants'] ?? []);
      receiverId = participants.firstWhere((id) => id != myId, orElse: () => '');
    }

    if (receiverId.isEmpty) return;

    // 3. Send file_request via relay
    final relayMsgId = DateTime.now().millisecondsSinceEpoch.toString() + "_req";
    final payload = {
      'targetMessageId': messageId,
      'roomId': roomId,
    };

    try {
      // Wait, we need to send the payload. We can use _sendEncryptedContent's logic, but let's just use it directly.
      await _sendEncryptedContent(
        roomId,
        '',
        'file_request',
        messageId: relayMsgId,
        extraPayload: payload,
      );
      debugPrint('DEBUG: File resync request sent for message $messageId');
    } catch (e) {
      debugPrint('DEBUG: Failed to send file_request: $e');
      // Revert status
      await _local.updateMessage(myId, roomId, messageId, {
        'status': 'sent',
      });
    }
  }

  String? _readFieldText(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = _extractFirstText(data[key]);
      if (value != null) return value;
    }
    return null;
  }

  String? _extractFirstText(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is num || value is bool) {
      return value.toString();
    }
    if (value is Map) {
      return _extractFirstText(
        value['name'] ?? value['title'] ?? value['label'] ?? value['id'],
      );
    }
    if (value is Iterable) {
      for (final item in value) {
        final text = _extractFirstText(item);
        if (text != null) return text;
      }
    }
    return null;
  }

  Future<void> _updateLocalConversation(
    String roomId,
    String lastMessage,
    DateTime timestamp, {
    bool incrementUnread = false,
  }) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    final currentData = _local.getConversation(myId, roomId);
    final updatedData = currentData != null
        ? Map<String, dynamic>.from(currentData)
        : <String, dynamic>{};

    final unreadCounts = Map<String, int>.from(
      (updatedData['unreadCounts'] as Map?)?.map(
            (key, value) => MapEntry(
              key.toString(),
              value is num
                  ? value.toInt()
                  : int.tryParse(value.toString()) ?? 0,
            ),
          ) ??
          {},
    );

    final participants = List<String>.from(
      updatedData['participants'] ??
          (roomId.startsWith('group_') ? const <String>[] : roomId.split('_')),
    );
    final isGroup =
        updatedData['isGroup'] == true || roomId.startsWith('group_');

    if (incrementUnread) {
      unreadCounts[myId] = (unreadCounts[myId] ?? 0) + 1;
    } else {
      // If I sent checking/updating, I've read it.
      unreadCounts[myId] = 0;
    }

    updatedData['id'] = roomId;
    updatedData['participants'] = participants;
    updatedData['isGroup'] = isGroup;
    updatedData['lastMessage'] = lastMessage;
    updatedData['lastMessageTime'] = timestamp.millisecondsSinceEpoch;
    updatedData['unreadCounts'] = unreadCounts;

    await _local.updateConversation(myId, roomId, updatedData);
  }

  Future<void> deleteMessage(String roomId, String messageId) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    // 1. Delete Locally
    await deleteMessageLocally(roomId, messageId);

    // 2. Determine Receivers (Group vs 1-on-1)
    List<String> receiverIds = [];
    final room = _local.getConversation(myId, roomId);
    final isGroup = room?['isGroup'] == true || roomId.startsWith('group_');

    if (isGroup) {
      final participants = List<String>.from(room?['participants'] ?? []);
      receiverIds = participants.where((id) => id != myId).toList();
    } else {
      receiverIds = [_getReceiverIdFromRoom(roomId, myId)];
    }

    // 3. Send "Delete Command" to all receivers
    final Map<String, dynamic> payloadMap = {'type': 'delete', 'id': messageId};
    if (isGroup) {
      payloadMap['groupId'] = roomId;
    }
    final payloadJson = jsonEncode(payloadMap);
    final myPrivateKey = await CryptoService().getPrivateKeyPem();

    for (final receiverId in receiverIds) {
      if (receiverId == 'unknown' || receiverId.isEmpty) continue;

      try {
        final receiverKey = await _keyRepo.getUserPublicKey(receiverId);
        if (receiverKey == null) continue;

        final encryptedBundle = await EncryptionHelper.encryptMessage(
          payloadJson,
          receiverKey,
        );

        if (myPrivateKey != null) {
          final signature = _signPayload(payloadJson, myPrivateKey);
          if (signature != null) {
            encryptedBundle['signature'] = signature;
          }
        }

        final commandId =
            'del_${DateTime.now().millisecondsSinceEpoch}_$receiverId';

        await _relay.pushToRelay(
          receiverId: receiverId,
          messageId: commandId,
          encryptedBundle: encryptedBundle,
        );
      } catch (e) {
        debugPrint('Failed to send delete command to $receiverId: $e');
      }
    }
  }

  Future<void> deleteMessageLocally(String roomId, String messageId) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;
    await _local.deleteMessage(myId, roomId, messageId);
  }

  // ---------------------------------------------------------------------------
  // HELPER METHODS
  // ---------------------------------------------------------------------------

  String _getRoomId(String userId1, String userId2) {
    return userId1.compareTo(userId2) < 0
        ? '${userId1}_$userId2'
        : '${userId2}_$userId1';
  }

  String _getReceiverIdFromRoom(String roomId, String myId) {
    if (!roomId.contains('_')) return 'unknown'; // Group?
    final parts = roomId.split('_');
    return parts[0] == myId ? parts[1] : parts[0];
  }

  Future<String> createOrGetChatRoom(
    String otherUserId, {
    bool persist = true,
  }) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) throw Exception('Not authenticated');

    final roomId = _getRoomId(myId, otherUserId);

    // Check if exists locally
    final room = _local.getConversation(myId, roomId);
    if (room == null && persist) {
      // Create locally ONLY if persist is true
      final newRoom = ChatRoom(
        id: roomId,
        participants: [myId, otherUserId],
        lastMessage: '',
        lastMessageTime: DateTime.now(),
        unreadCounts: {},
        isGroup: false,
        admins: [],
      );
      await _local.updateConversation(myId, roomId, newRoom.toMap());
    }
    return roomId;
  }

  // markMessagesAsRead removed (duplicate)

  // ---------------------------------------------------------------------------
  // USER & PROFILE METHODS (Firestore)
  // ---------------------------------------------------------------------------

  Future<UserModel?> getUserData(String uid) async {
    // 1. Check Cache
    if (_userCache.containsKey(uid)) {
      return _userCache[uid];
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists) {
        final user = UserModel.fromMap(doc.data()!, doc.id);
        _userCache[uid] = user; // Cache it
        return user;
      }
    } catch (e) {
      debugPrint('Error getting user data: $e');
    }
    return null;
  }

  /// Helper: Get user data stream
  Stream<UserModel?> getUserStream(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
          if (doc.exists && doc.data() != null) {
            return UserModel.fromMap(doc.data()!, doc.id);
          }
          return null;
        });
  }

  Future<bool> checkUsernameAvailability(String username) async {
    final result = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: username)
        .get();
    return result.docs.isEmpty;
  }

  Future<void> updateUserProfile({
    required String uid,
    String? displayName,
    String? username,
    String? bio,
    String? phoneNumber,
  }) async {
    final updates = <String, dynamic>{};
    if (displayName != null) updates['displayName'] = displayName;
    if (username != null) updates['username'] = username;
    if (bio != null) updates['bio'] = bio;
    if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;

    if (updates.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(updates);
    }
  }

  Future<String> updateProfilePicture(String uid, File imageFile) async {
    // 1. Read File & Encode Base64 (Bypass Storage)
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    // 2. Update Firestore
    // Update BOTH fields to ensure backward compatibility and preference logic in UserModel works.
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'profilePick': base64Image,
      'photoURL': base64Image,
    });
    return base64Image;
  }

  // ---------------------------------------------------------------------------
  // CONTACTS & BLOCKING
  // ---------------------------------------------------------------------------

  Future<void> addContact(String contactUid) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    // Add to 'contacts' subcollection or array
    await FirebaseFirestore.instance.collection('users').doc(myId).update({
      'contacts': FieldValue.arrayUnion([contactUid]),
    });
  }

  Future<void> removeContact(String contactUid) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    await FirebaseFirestore.instance.collection('users').doc(myId).update({
      'contacts': FieldValue.arrayRemove([contactUid]),
    });
  }

  Future<void> blockUser(String uidToBlock) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    await FirebaseFirestore.instance.collection('users').doc(myId).update({
      'blockedUsers': FieldValue.arrayUnion([uidToBlock]),
    });
    _blockedUsersCache.add(uidToBlock);
  }

  Future<void> unblockUser(String uidToUnblock) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    await FirebaseFirestore.instance.collection('users').doc(myId).update({
      'blockedUsers': FieldValue.arrayRemove([uidToUnblock]),
    });
    _blockedUsersCache.remove(uidToUnblock);
  }

  // ---------------------------------------------------------------------------
  // TYPING STATUS (Realtime Database)
  // ---------------------------------------------------------------------------

  Future<void> setTypingStatus(String roomId, bool isTyping) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // CHECK PRIVACY
    if (isTyping) {
      final allowed = await _isSettingEnabled('privacy_typing');
      if (!allowed) return;
    }

    try {

      final ref = FirebaseDatabase.instance.ref('typing/$roomId/$uid');
      if (isTyping) {
        // Set to true, auto-remove on disconnect to prevent stuck "typing"
        await ref.set(true);
        await ref.onDisconnect().remove();
      } else {
        await ref.remove();
        await ref.onDisconnect().cancel();
      }
    } catch (e) {
      // Silently fail if permission denied (rules not set yet)
      debugPrint('INFO: Typing status update failed (likely permission): $e');
    }
  }

  Stream<List<String>> getTypingUsers(String roomId) {
{
      return const Stream.empty();
    }
    return FirebaseDatabase.instance.ref('typing/$roomId').onValue.map((event) {
      if (event.snapshot.value == null) return <String>[];
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return data.keys.cast<String>().toList();
    }).asBroadcastStream();
  }

  // ---------------------------------------------------------------------------
  // READ RECEIPTS
  // ---------------------------------------------------------------------------

  Future<void> markMessagesAsRead(String roomId) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    // 0. Safety Check: Ensure conversation exists locally before proceeding
    final exists = _local.getConversation(myId, roomId);
    if (exists == null) return;

    // 0. Check if there are actually unread messages to avoid network spam
    final chatData = _local.getConversation(myId, roomId);
    if (chatData != null) {
      final Map<String, int> unreadCounts = Map<String, int>.from(
        chatData['unreadCounts'] ?? {},
      );
      final myUnread = unreadCounts[myId] ?? 0;

      if (myUnread == 0) {
        // Already read, do nothing
        return;
      }

      // RESET unread count
      unreadCounts[myId] = 0;

      final updatedChat = Map<String, dynamic>.from(chatData);
      updatedChat['unreadCounts'] = unreadCounts;
      await _local.updateConversation(myId, roomId, updatedChat);
    }

    // 1. Update Local Messages (Optimistic)
    await _local.markRoomMessagesAsRead(myId, roomId);

    // 2. Broadcast Read Receipt to ALL Participants
    try {
      final room = _local.getConversation(myId, roomId);
      if (room == null) return;

      final participants = List<String>.from(room['participants'] ?? []);

      // If it's a 1-on-1 chat and participants list is empty/malformed, fallback
      if (participants.isEmpty && !room['isGroup']) {
        participants.add(_getReceiverIdFromRoom(roomId, myId));
      }

      // CHECK PRIVACY once
      final allowed = await _isSettingEnabled('privacy_read_receipts');
      if (!allowed) {
        debugPrint('DEBUG: Read receipt suppressed by privacy setting.');
        return;
      }

      final payload = jsonEncode({
        'type': 'read_receipt',
        'content': roomId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      final myPrivateKey = await CryptoService().getPrivateKeyPem();

      // Fan-out
      for (final receiverId in participants) {
        if (receiverId == myId) continue;

        try {
          final receiverKey = await _keyRepo.getUserPublicKey(receiverId);
          if (receiverKey == null) continue;

          final encryptedBundle = await EncryptionHelper.encryptMessage(
            payload,
            receiverKey,
          );

          if (myPrivateKey != null) {
            final signature = _signPayload(payload, myPrivateKey);
            if (signature != null) {
              encryptedBundle['signature'] = signature;
            }
          }

          final cmdId = DateTime.now().millisecondsSinceEpoch.toString();
          await _relay.pushToRelay(
            receiverId: receiverId,
            messageId: cmdId,
            encryptedBundle: encryptedBundle,
          );
        } catch (e) {
          debugPrint('DEBUG: Failed to send read receipt to $receiverId: $e');
        }
      }
    } catch (e) {
      debugPrint('DEBUG: Failed to initiate read receipt broadcast: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // GROUPS (Stubbed/Basic)
  // ---------------------------------------------------------------------------

  Future<String> createGroup(
    String groupName,
    List<String> userIds,
    File? image, {
    String? description,
    bool isPublic = false,
    bool onlyAdminsCanPost = false,
  }) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) throw Exception('Not authenticated');

    // 1. Generate Group ID
    final groupId = 'group_${DateTime.now().millisecondsSinceEpoch}_$myId';

    // 2. Process Image (Base64)
    String? imageUrl;
    if (image != null && await image.exists()) {
      final bytes = await image.readAsBytes();
      imageUrl = base64Encode(bytes);
    }

    // 3. Create Local ChatRoom (Group)
    final allParticipants = [...userIds, myId];
    final groupRoom = ChatRoom(
      id: groupId,
      participants: allParticipants,
      lastMessage: 'تم إنشاء المجموعة',
      lastMessageTime: DateTime.now(),
      unreadCounts: {myId: 0},
      isGroup: true,
      groupName: groupName,
      groupIcon: imageUrl,
      description: description,
      admins: [myId],
      deletedBy: [],
      isPublic: isPublic,
      onlyAdminsCanPost: onlyAdminsCanPost,
      createdBy: myId,
      adminPermissions: {
        myId: ['change_info', 'add_members', 'remove_members', 'manage_admins'],
      },
    );

    // Save locally
    await _local.updateConversation(myId, groupId, groupRoom.toMap());

    // 3.5 WRITE TO FIRESTORE (Source of Truth)
    // This is required for validateGroupState to pass.
    try {
      await FirebaseFirestore.instance
          .collection('group_chats')
          .doc(groupId)
          .set({
            'id': groupId,
            'participants': allParticipants,
            'admins': [myId],
            'groupName': groupName,
            'groupIcon': imageUrl,
            'description': description,
            'isPublic': isPublic,
            'onlyAdminsCanPost': onlyAdminsCanPost,
            'createdBy': myId,
            'adminPermissions': {
              myId: [
                'change_info',
                'add_members',
                'remove_members',
                'manage_admins',
              ],
            },
            'createdAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('CRITICAL: Failed to create group in Firestore: $e');
      // Should we revert? Or let offline queue handle it (if enabled)?
      // For now, allow proceeding locally, but validateGroupState might fail if still offline.
      // Ideally, validateGroupState should handle "offline and I created it recently" logic,
      // but syncing is safer.
    }

    // 3.6 If Public, save to Public Registry
    if (isPublic) {
      try {
        await FirebaseFirestore.instance
            .collection('public_groups')
            .doc(groupId)
            .set({
              'id': groupId,
              'name': groupName,
              'description': description,
              'icon': imageUrl,
              'createdAt': FieldValue.serverTimestamp(),
              'membersCount': allParticipants.length,
              'createdBy': myId,
            });
      } catch (e) {
        debugPrint('Warning: Failed to publish group to registry: $e');
      }
    }

    // 4. Broadcast 'group_create' Command to ALL Participants
    final payload = jsonEncode({
      'type': 'group_create',
      'id': groupId,
      'name': groupName,
      'icon': imageUrl,
      'description': description,
      'participants': allParticipants,
      'admins': [myId],
      'isPublic': isPublic,
      'onlyAdminsCanPost': onlyAdminsCanPost,
      'createdBy': myId,
      'adminPermissions': {
        myId: ['change_info', 'add_members', 'remove_members', 'manage_admins'],
      },
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    for (final userId in userIds) {
      if (userId == myId) continue;
      try {
        await _sendToUser(userId, payload);
      } catch (e) {
        debugPrint('DEBUG: Failed to invite $userId: $e');
      }
    }

    return groupId;
  }

  // ---------------------------------------------------------------------------
  // DELETE CONVERSATION (LOCAL ONLY)
  // ---------------------------------------------------------------------------
  Future<void> deleteChat(String roomId) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) {
      debugPrint('ERROR: deleteChat called but user is not logged in!');
      return;
    }
    debugPrint('DEBUG: deleteChat called by user $myId for roomId=$roomId');

    // 1. Delete Local Conversation & Messages
    await _local.deleteConversation(myId, roomId);

    // 2. Remove from Firestore "Active Chats" (Prevent Resurrection at startup)
    try {
      final isGroup = roomId.startsWith('group_');
      if (!isGroup) {
        // Determine peerId from roomId
        final peerId = _getReceiverIdFromRoom(roomId, myId);
        if (peerId != 'unknown' && peerId.isNotEmpty) {
          await _firestore
              .collection('users')
              .doc(myId)
              .collection('active_chats')
              .doc(peerId)
              .delete();
          debugPrint('DEBUG: Removed $peerId from active_chats');
        }
      } else {
        // For groups, we might want to ensure we don't auto-sync it back immediately
        // if we just left it. But usually deleteChat for groups means "Clear History" or "Leave".
        // If "Leave", we already handle it in leaveGroup.
      }
    } catch (e) {
      debugPrint('Failed to remove from active_chats: $e');
    }

    debugPrint('DEBUG: deleteChat completed for roomId=$roomId');
  }

  // ---------------------------------------------------------------------------
  // DELETE CONVERSATION FOR EVERYONE
  // ---------------------------------------------------------------------------
  Future<void> deleteConversationForEveryone(String roomId) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    // 1. Fetch participants BEFORE deleting locally
    final roomData = _local.getConversation(myId, roomId);
    if (roomData == null) return; // Already deleted or invalid

    List<String> receiverIds = [];
    final isGroup = roomData['isGroup'] == true;

    if (isGroup) {
      // CRITICAL SAFEGUARD: Never treat group deletion like 1-on-1 deletion.
      // Groups use 'deleteGroupForEveryone' (Owner only) or 'leaveGroup'.
      // This method is for Private Chats only.
      debugPrint(
        'ERROR: deleteConversationForEveryone called on a GROUP. Ignored.',
      );
      return;
    }

    receiverIds = [_getReceiverIdFromRoom(roomId, myId)];

    // 2. Loop & Send "Delete Command"
    final payload = '{"type": "delete_conversation", "content": "$roomId"}';

    for (final receiverId in receiverIds) {
      if (receiverId == 'unknown' || receiverId.isEmpty) continue;
      try {
        final receiverKey = await _keyRepo.getUserPublicKey(receiverId);
        if (receiverKey != null) {
          final encryptedBundle = await EncryptionHelper.encryptMessage(
            payload,
            receiverKey,
          );

          final myPrivateKey = await CryptoService().getPrivateKeyPem();
          if (myPrivateKey != null) {
            final signature = _signPayload(payload, myPrivateKey);
            if (signature != null) {
              encryptedBundle['signature'] = signature;
            }
          }

          final cmdId =
              'del_conv_${DateTime.now().millisecondsSinceEpoch}_$receiverId';
          await _relay.pushToRelay(
            receiverId: receiverId,
            messageId: cmdId,
            encryptedBundle: encryptedBundle,
          );
        }
      } catch (e) {
        debugPrint(
          'DEBUG: Failed to send delete_conversation to $receiverId: $e',
        );
      }
    }

    // 3. Finally Delete Locally
    await deleteChat(roomId);
  }

  // ---------------------------------------------------------------------------
  // STREAM MESSAGE WRAPPER
  // ---------------------------------------------------------------------------

  Stream<List<Message>> getMessages(String roomId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);
    return _local.watchMessages(uid, roomId).map((list) {
      // Convert Maps to Message Objects
      return list.map((m) => Message.fromMap(m['id'], m)).toList();
    });
  }

  Stream<List<ChatRoom>> getUserChats() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);
    return _local.watchConversations(uid).map((list) {
      return list.map((data) => ChatRoom.fromMap(data['id'], data)).toList();
    });
  }

  Stream<ChatRoom?> watchChatData(String roomId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _local.watchConversation(uid, roomId).map((data) {
      if (data == null || data.isEmpty) return null;
      return ChatRoom.fromMap(data['id'] ?? roomId, data);
    });
  }

  void dispose() {
    _inboxSubscription?.cancel();
    _presenceSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _syncRequestSubscription?.cancel();
    _syncInboxSubscription?.cancel();
  }

  // ---------------------------------------------------------------------------
  // GROUP MANAGEMENT (NEW)
  // ---------------------------------------------------------------------------

  Future<void> updateGroupInfo(
    String groupId, {
    String? name,
    String? description,
    File? image,
    bool? isPublic,
    bool? onlyAdminsCanPost,
  }) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    // 1. Process Image if any
    String? imageUrl;
    if (image != null) {
      final bytes = await image.readAsBytes();
      imageUrl = base64Encode(bytes);
    }

    // 2. Local Update
    final room = _local.getConversation(myId, groupId);
    if (room != null) {
      final newRoom = Map<String, dynamic>.from(room);
      if (name != null) newRoom['groupName'] = name;
      if (description != null) newRoom['description'] = description;
      if (imageUrl != null) newRoom['groupIcon'] = imageUrl;
      if (isPublic != null) newRoom['isPublic'] = isPublic;
      if (onlyAdminsCanPost != null) {
        newRoom['onlyAdminsCanPost'] = onlyAdminsCanPost;
      }

      await _local.updateConversation(myId, groupId, newRoom);
    }

    // 3. Update Firestore (Source of Truth)
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['groupName'] = name;
      if (description != null) updates['description'] = description;
      if (imageUrl != null) updates['groupIcon'] = imageUrl;
      if (isPublic != null) updates['isPublic'] = isPublic;
      if (onlyAdminsCanPost != null) {
        updates['onlyAdminsCanPost'] = onlyAdminsCanPost;
      }

      if (updates.isNotEmpty) {
        await _firestore.collection('group_chats').doc(groupId).update(updates);
      }
    } catch (e) {
      debugPrint('Error syncing group info to Firestore: $e');
      // If permission denied or offline, we might want to warn user, but let's proceed for now
    }

    // Firestore Public Registry Sync
    if (isPublic != null) {
      try {
        // We need the current room data to get existing name/desc/icon if not provided in update
        final currentRoom = room ?? _local.getConversation(myId, groupId);
        if (currentRoom != null) {
          if (isPublic) {
            // Update/Create in registry
            final cName =
                name ?? currentRoom['groupName']; // Use new or existing
            final cDesc = description ?? currentRoom['description'];
            final cIcon = imageUrl ?? currentRoom['groupIcon'];

            await FirebaseFirestore.instance
                .collection('public_groups')
                .doc(groupId)
                .set({
                  'id': groupId,
                  'name': cName,
                  'description': cDesc,
                  'icon': cIcon,
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
          } else {
            // Remove from registry if turned off
            await FirebaseFirestore.instance
                .collection('public_groups')
                .doc(groupId)
                .delete();
          }
        }
      } catch (e) {
        debugPrint('WARNING: Failed to sync public registry: $e');
        // We don't throw here to allow local/group update to succeed
      }
    }

    // 4. Broadcast 'group_update'
    final payload = jsonEncode({
      'type': 'group_update',
      'id': groupId,
      'name': name,
      'description': description,
      'icon': imageUrl,
      if (isPublic != null) 'isPublic': isPublic,
      if (onlyAdminsCanPost != null) 'onlyAdminsCanPost': onlyAdminsCanPost,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    await _broadcastToGroup(groupId, payload, myId);
  }

  Future<void> addGroupMembers(String groupId, List<String> newUserIds) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    // 1. Update Local
    final room = _local.getConversation(myId, groupId);
    if (room != null) {
      final participants = List<String>.from(room['participants'] ?? []);
      participants.addAll(newUserIds);
      room['participants'] = participants.toSet().toList(); // Unique
      await _local.updateConversation(myId, groupId, room);
    }

    // 2. Update Firestore (Source of Truth)
    try {
      await _firestore.collection('group_chats').doc(groupId).update({
        'participants': FieldValue.arrayUnion(newUserIds),
      });
    } catch (e) {
      debugPrint('Error syncing members to Firestore: $e');
    }

    // 3. Broadcast 'group_member_add'
    final payload = jsonEncode({
      'type': 'group_member_add',
      'id': groupId,
      'added_ids': newUserIds,
    });

    await _broadcastToGroup(groupId, payload, myId);

    // Send full INVITE to new members (Sync)
    // Reuse existing room variable or fetch if needed (it is already fetched above)
    if (room != null) {
      final syncPayload = jsonEncode({
        'type': 'group_create',
        'id': groupId,
        'name': room['groupName'],
        'icon': room['groupIcon'],
        'description': room['description'],
        'participants': room['participants'],
        'admins': room['admins'],
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      for (final uid in newUserIds) {
        await _sendToUser(uid, syncPayload);
      }
    }
  }

  Future<void> acceptJoinRequest(String groupId, String userId) async {
    // 1. Remove from pendingRequests locally
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    final room = _local.getConversation(myId, groupId);
    if (room != null) {
      final pending = List<String>.from(room['pendingRequests'] ?? []);
      pending.remove(userId);
      room['pendingRequests'] = pending;
      await _local.updateConversation(myId, groupId, room);
    }

    // 2. Add as member
    await addGroupMembers(groupId, [userId]);
  }

  Future<void> rejectJoinRequest(String groupId, String userId) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    final room = _local.getConversation(myId, groupId);
    if (room != null) {
      final pending = List<String>.from(room['pendingRequests'] ?? []);
      pending.remove(userId);
      room['pendingRequests'] = pending;
      await _local.updateConversation(myId, groupId, room);
    }
  }

  Future<void> demoteAdmin(String groupId, String adminId) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    // 0. Update Firestore (Source of Truth)
    try {
      await _firestore.collection('group_chats').doc(groupId).update({
        'admins': FieldValue.arrayRemove([adminId]),
        'adminPermissions.$adminId': FieldValue.delete(),
      });
    } catch (e) {
      debugPrint('Error syncing demote to Firestore: $e');
    }

    // 1. Local Update
    final room = _local.getConversation(myId, groupId);
    if (room != null) {
      final admins = List<String>.from(room['admins'] ?? []);
      admins.remove(adminId);
      room['admins'] = admins;

      // Remove permissions
      final perms =
          (room['adminPermissions'] as Map?)?.map(
            (key, value) =>
                MapEntry(key.toString(), List<String>.from(value ?? [])),
          ) ??
          {};
      perms.remove(adminId);
      room['adminPermissions'] = perms;

      await _local.updateConversation(myId, groupId, room);
    }

    // 2. Broadcast Update
    final payload = jsonEncode({
      'type': 'group_admin_update',
      'id': groupId,
      'target_id': adminId,
      'is_promote': false, // Demote
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    await _broadcastToGroup(groupId, payload, myId);
  }

  // --- Toggle Mute ---
  Future<void> toggleMute(String groupId, bool isMuted) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;
    await _local.setMuteStatus(myId, groupId, isMuted);
  }

  // --- Group Handles ---

  Future<void> setGroupHandle(String roomId, String handle) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) throw Exception('Not authenticated');

    // 1. Validate format
    final cleanHandle = handle.toLowerCase().trim();
    if (cleanHandle.isEmpty)
      throw Exception('المعرف لا يمكن أن يكون فارغاً');
    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(cleanHandle)) {
      throw Exception(
        'المعرف يجب أن يكون أحرف إنجليزية وأرقام وبطول 3-20',
      );
    }

    // 2. Check Uniqueness (Firestore Transaction)
    final handleRef = _firestore.collection('group_handles').doc(cleanHandle);
    final roomRef = _firestore.collection('group_chats').doc(roomId);

    // Prepare local data for "Healing" if remote doc is missing
    final localRoom = _local.getConversation(myId, roomId);

    try {
      await _firestore.runTransaction((transaction) async {
        final handleDoc = await transaction.get(handleRef);
        if (handleDoc.exists && handleDoc.data()?['roomId'] != roomId) {
          throw Exception(
            'هذا المعرف مستخدم بالفعل لمجموعة أخرى',
          );
        }

        // Check current handle to cleanup old one if changing
        final roomDoc = await transaction.get(roomRef);

        // SELF-HEALING: If doc missing but we have local data, create it!
        if (!roomDoc.exists) {
          if (localRoom != null) {
            transaction.set(roomRef, {
              'id': roomId,
              'participants': localRoom['participants'],
              'admins': localRoom['admins'],
              'groupName': localRoom['groupName'],
              'isPublic': localRoom['isPublic'] ?? false,
              'groupHandle': cleanHandle, // Set directly
              'createdAt': FieldValue.serverTimestamp(),
            });
          } else {
            throw Exception(
              'بيانات المجموعة غير موجودة (Meta-data missing)',
            );
          }
        } else {
          final oldHandle = roomDoc.data()?['groupHandle'];
          if (oldHandle != null && oldHandle != cleanHandle) {
            transaction.delete(
              _firestore.collection('group_handles').doc(oldHandle),
            );
          }
          // Update room metadata
          transaction.update(roomRef, {'groupHandle': cleanHandle});
        }

        // Set new handle mapping
        transaction.set(handleRef, {
          'roomId': roomId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      debugPrint('Handle Error: $e');
      if (e.toString().contains('permission-denied')) {
        throw Exception(
          'لا تملك صلاحية لتعديل المعرف (Permission Denied)',
        );
      }
      rethrow;
    }

    // 3. Local Update
    final room = _local.getConversation(myId, roomId);
    if (room != null) {
      final newRoom = Map<String, dynamic>.from(room);
      newRoom['groupHandle'] = cleanHandle;
      await _local.updateConversation(myId, roomId, newRoom);
    }

    // 4. Broadcast Update
    final payload = jsonEncode({
      'type': 'group_update',
      'id': roomId,
      'groupHandle': cleanHandle,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    await _broadcastToGroup(roomId, payload, myId);
  }

  Future<ChatRoom?> _fetchRoomFromFirestore(String roomId) async {
    try {
      final doc = await _firestore.collection('group_chats').doc(roomId).get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      return ChatRoom(
        id: roomId,
        participants: List<String>.from(data['participants'] ?? []),
        lastMessage: '',
        lastMessageTime: DateTime.now(),
        unreadCounts: {},
        isGroup: true,
        groupName: data['groupName'],
        groupIcon: data['groupIcon'],
        description: data['description'],
        admins: data['admins'] != null
            ? List<String>.from(data['admins'])
            : null,
        isPublic: data['isPublic'] ?? false,
        onlyAdminsCanPost: data['onlyAdminsCanPost'] ?? false,
        groupHandle: data['groupHandle'],
        category: _readFieldText(data, const [
          'category',
          'groupCategory',
          'channelCategory',
          'categoryName',
          'category_name',
          'section',
          'sectionName',
          'section_name',
        ]),
        source: _readFieldText(data, const [
          'source',
          'sourceName',
          'source_name',
          'provider',
          'providerName',
          'provider_name',
          'playlist',
        ]),
      );
    } catch (e) {
      debugPrint('Error fetching room: $e');
      return null;
    }
  }

  /// **SMART SYNC:**
  /// Wraps validateGroupState with Caching & Deduplication to prevent server spam.
  Future<void> _smartSyncGroup(String roomId) async {
    // 1. Check if sync is already in progress (Deduplication)
    if (_activeGroupSyncs.containsKey(roomId)) {
      return _activeGroupSyncs[roomId];
    }

    // 2. Check cooldown (Cache) - e.g., 1 minute
    final lastSync = _lastGroupSyncTime[roomId];
    if (lastSync != null &&
        DateTime.now().difference(lastSync) < const Duration(minutes: 1)) {
      return; // Skip sync, use local data
    }

    // 3. Start Sync
    final future = validateGroupState(roomId)
        .then((_) {
          _lastGroupSyncTime[roomId] = DateTime.now();
        })
        .whenComplete(() {
          _activeGroupSyncs.remove(roomId);
        });

    _activeGroupSyncs[roomId] = future;
    return future;
  }

  /// **SECURITY: STRICT STATE VALIDATION**
  /// Fetches latest data from Firestore.
  /// 1. If user is NOT in participants -> Deletes local chat & throws SecurityException.
  /// 2. If user IS in participants -> Updates local cache (Admins, Permissions, etc).
  Future<void> validateGroupState(String roomId) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    debugPrint('SECURITY: Validating group state for $roomId...');

    try {
      final doc = await _firestore.collection('group_chats').doc(roomId).get();

      if (!doc.exists) {
        // Group deleted remotely
        debugPrint(
          'SECURITY ALERT: Group $roomId no longer exists. Deleting local.',
        );
        await deleteChat(roomId);
        throw Exception('المجموعة لم تعد موجودة');
      }

      final data = doc.data()!;
      final participants = List<String>.from(data['participants'] ?? []);

      // 1. STRICT MEMBERSHIP CHECK
      if (!participants.contains(myId)) {
        debugPrint(
          'SECURITY ALERT: User $myId is NO LONGER a member of $roomId.',
        );
        // IMMEDIATE REVOCATION
        await deleteChat(roomId);
        throw Exception('security_kicked');
      }

      // 2. STATE SYNC (Admins, Permissions, Roles, Group Info)
      final room = _local.getConversation(myId, roomId);
      if (room != null) {
        final newRoom = Map<String, dynamic>.from(room);

        // Sync critical fields
        newRoom['participants'] = participants;
        newRoom['admins'] = List<String>.from(data['admins'] ?? []);
        newRoom['adminPermissions'] = data['adminPermissions']; // Map
        newRoom['onlyAdminsCanPost'] = data['onlyAdminsCanPost'] ?? false;
        newRoom['isPublic'] = data['isPublic'] ?? false;

        // CRITICAL FIX: Sync group info fields to prevent deletion
        if (data.containsKey('groupHandle')) {
          newRoom['groupHandle'] = data['groupHandle'];
        }
        if (data.containsKey('groupName')) {
          newRoom['groupName'] = data['groupName'];
        }
        if (data.containsKey('groupIcon')) {
          newRoom['groupIcon'] = data['groupIcon'];
        }
        if (data.containsKey('description')) {
          newRoom['description'] = data['description'];
        }
        final syncedCategory = _readFieldText(data, const [
          'category',
          'groupCategory',
          'channelCategory',
          'categoryName',
          'category_name',
          'section',
          'sectionName',
          'section_name',
        ]);
        if (syncedCategory != null) {
          newRoom['category'] = syncedCategory;
        }
        final syncedSource = _readFieldText(data, const [
          'source',
          'sourceName',
          'source_name',
          'provider',
          'providerName',
          'provider_name',
          'playlist',
        ]);
        if (syncedSource != null) {
          newRoom['source'] = syncedSource;
        }

        // Check if I am now Owner (rare but possible via transfer)
        // newRoom['createdBy'] = data['createdBy']; // If we stored this locally

        await _local.updateConversation(myId, roomId, newRoom);
        debugPrint('SECURITY: Local state synchronized with Firestore.');
      } else {
        // NEW: Create if missing locally but valid remotely (Self-Healing)
        debugPrint(
          'SECURITY: Group $roomId found remotely but missing locally. Syncing...',
        );
        await _createLocalGroupConversation(roomId, data);
      }
    } catch (e) {
      if (e.toString().contains('security_kicked')) rethrow;
      debugPrint('Warning: Failed to validate group state (Offline?): $e');
      // If offline, we trust local state for now, but we tried.
    }
  }

  Future<void> removeGroupMember(String groupId, String memberId) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    debugPrint('DEBUG: removing member $memberId from group $groupId');

    final payload = jsonEncode({
      'type': 'group_member_remove',
      'id': groupId,
      'removed_id': memberId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    // 0. Force send to the removed member
    await _sendToUser(memberId, payload);

    // 0.5 Update Firestore (Source of Truth)
    try {
      await _firestore.collection('group_chats').doc(groupId).update({
        'participants': FieldValue.arrayRemove([memberId]),
        'admins': FieldValue.arrayRemove([memberId]), // Also remove from admins
      });
    } catch (e) {
      debugPrint('Error syncing removal to Firestore: $e');
    }

    // 1. Broadcast to everyone currently in the group
    await _broadcastToGroup(groupId, payload, myId);

    // 2. Local Update (Optimistic removal from participant list)
    final room = _local.getConversation(myId, groupId);
    if (room != null) {
      final participants = List<String>.from(room['participants'] ?? []);
      participants.remove(memberId);
      final newRoom = Map<String, dynamic>.from(room);
      newRoom['participants'] = participants;
      await _local.updateConversation(myId, groupId, newRoom);
    }
  }

  Future<void> leaveGroup(String roomId) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    // 1. Notify others
    try {
      final payload = jsonEncode({
        'type': 'group_member_remove',
        'id': roomId,
        'removed_id': myId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      await _broadcastToGroup(roomId, payload, myId);
    } catch (e) {
      debugPrint('Warning: Failed to broadcast leave group: $e');
    }

    // 1.5 Update Firestore (CRITICAL FIX: Remove self from remote list)
    try {
      await _firestore.collection('group_chats').doc(roomId).update({
        'participants': FieldValue.arrayRemove([myId]),
        'admins': FieldValue.arrayRemove([myId]),
      });
    } catch (e) {
      debugPrint('Error removing self from Firestore group: $e');
    }

    // 2. Delete Local Copy
    try {
      await deleteChat(roomId);
    } catch (e) {
      debugPrint('Error deleting local chat after leave: $e');
    }
  }

  Future<void> promoteAdmin(String groupId, String memberId) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    final payload = jsonEncode({
      'type': 'group_admin_update',
      'id': groupId,
      'target_id': memberId,
      'is_promote': true,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    await _broadcastToGroup(groupId, payload, myId);

    // Update Firestore
    try {
      final defaultPerms = [
        'change_info',
        'add_members',
        'remove_members',
        'manage_admins',
      ];
      await _firestore.collection('group_chats').doc(groupId).update({
        'admins': FieldValue.arrayUnion([memberId]),
        'adminPermissions.$memberId': defaultPerms,
      });
    } catch (e) {
      debugPrint('Error syncing promo to Firestore: $e');
    }

    // Local Update
    final room = _local.getConversation(myId, groupId);
    if (room != null) {
      final admins = List<String>.from(room['admins'] ?? []);
      if (!admins.contains(memberId)) {
        admins.add(memberId);

        // Initialize default permissions for new admin
        final perms =
            (room['adminPermissions'] as Map?)?.map(
              (key, value) =>
                  MapEntry(key.toString(), List<String>.from(value ?? [])),
            ) ??
            {};
        perms[memberId] = [
          'change_info',
          'add_members',
          'remove_members',
          'manage_admins',
        ];

        final newRoom = Map<String, dynamic>.from(room);
        newRoom['admins'] = admins;
        newRoom['adminPermissions'] = perms;

        await _local.updateConversation(myId, groupId, newRoom);
      }
    }
  }

  // Helper to send to all room participants
  Future<void> _broadcastToGroup(
    String groupId,
    String payload,
    String senderId,
  ) async {
    final room = _local.getConversation(senderId, groupId);
    if (room == null) {
      debugPrint('DEBUG: _broadcastToGroup failed - room not found locally');
      return;
    }

    final participants = List<String>.from(room['participants'] ?? []);
    debugPrint(
      'DEBUG: Broadcasting to ${participants.length} participants: $participants',
    );

    for (final uid in participants) {
      if (uid == senderId) continue; // Skip self
      await _sendToUser(uid, payload);
    }
  }

  Future<void> _sendToUser(String userId, String payload) async {
    try {
      final key = await _keyRepo.getUserPublicKey(userId);
      if (key == null) return;

      final encryptedBundle = await EncryptionHelper.encryptMessage(
        payload,
        key,
      );

      final myPrivateKey = await CryptoService().getPrivateKeyPem();
      if (myPrivateKey != null) {
        final signature = _signPayload(payload, myPrivateKey);
        if (signature != null) {
          encryptedBundle['signature'] = signature;
        }
      }
      
      final cmdId = 'cmd_${DateTime.now().millisecondsSinceEpoch}_$userId';

      await _relay.pushToRelay(
        receiverId: userId,
        messageId: cmdId,
        encryptedBundle: encryptedBundle,
      );
    } catch (e) {
      debugPrint('DEBUG: Failed to send command to $userId: $e');
    }
  }

  // --- JOIN REQUESTS ---
  Future<void> requestToJoinGroup(String groupId, String adminId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final payload = jsonEncode({
      'type': 'join_request',
      'groupId': groupId,
      'requesterId': currentUser.uid,
      'requesterName': currentUser.displayName ?? 'Unknown',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    await _sendToUser(adminId, payload);
  }

  // ---------------------------------------------------------------------------
  // HELPER FOR ROBUST DECRYPTION (PFS-Lite)
  // ---------------------------------------------------------------------------
  Future<String> _attemptDecryption(
    Map<String, dynamic> bundle,
    String primaryKey,
  ) async {
    try {
      // 1. Try Primary Key
      return await EncryptionHelper.decryptMessage(bundle, primaryKey);
    } catch (e) {
      debugPrint(
        'DEBUG: Decryption with primary key failed. Trying archives...',
      );

      // 2. Try Archived Keys
      final archivedKeys = await CryptoService().getArchivedPrivateKeys();
      for (final key in archivedKeys) {
        try {
          final result = await EncryptionHelper.decryptMessage(bundle, key);
          debugPrint('DEBUG: Recovered message using archived key.');
          return result;
        } catch (_) {
          // Continue to next key
        }
      }

      // 3. All Failed
      debugPrint('ERROR: All decryption attempts failed.');
      throw Exception('Decryption Failed: Invalid Key');
    }
  }

  Future<void> updateAdminPermissions(
    String groupId,
    String targetAdminId,
    List<String> permissions,
  ) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    // 1. Update Firestore (Source of Truth)
    try {
      await _firestore.collection('group_chats').doc(groupId).update({
        'adminPermissions.$targetAdminId': permissions,
      });
    } catch (e) {
      debugPrint('Error syncing permissions to Firestore: $e');
    }

    // 2. Local Update
    final room = _local.getConversation(myId, groupId);
    if (room != null) {
      final perms =
          (room['adminPermissions'] as Map?)?.map(
            (key, value) =>
                MapEntry(key.toString(), List<String>.from(value ?? [])),
          ) ??
          {};
      perms[targetAdminId] = permissions;
      room['adminPermissions'] = perms;
      await _local.updateConversation(myId, groupId, room);
    }

    // 3. Broadcast
    final payload = jsonEncode({
      'type': 'group_admin_perms_update',
      'id': groupId,
      'target_id': targetAdminId,
      'permissions': permissions,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    await _broadcastToGroup(groupId, payload, myId);
  }

  bool hasPermission(String groupId, String permission) {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return false;

    final room = _local.getConversation(myId, groupId);
    if (room == null) return false;

    // Owner has all permissions
    if (room['createdBy'] == myId) return true;
    if (room['createdBy'] == null &&
        (room['id'] as String).endsWith('_$myId')) {
      return true;
    }

    // Check specific permission
    final permsMap = room['adminPermissions'] as Map?;
    if (permsMap == null) return false;

    final myPerms = List<String>.from(permsMap[myId] ?? []);
    return myPerms.contains(permission);
  }

  Future<void> deleteGroupForEveryone(String groupId) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;
    // 1 Clean up 'group_handles' if exists
    final room = _local.getConversation(myId, groupId);
    if (room != null) {
      final handle = room['groupHandle'];
      if (handle != null) {
        try {
          await _firestore.collection('group_handles').doc(handle).delete();
        } catch (e) {
          debugPrint('Handle delete warning: $e');
        }
      }
    }

    // 2. Broadcast 'delete_conversation' to all participants
    // We send this BEFORE deleting Firestore doc, so participants can receive it via Relay logic.
    // (Relay logic relies on P2P, so Firestore doc not strictly required for key exchange if cached,
    // but better to keep doc alive until message sent).
    final payload = jsonEncode({
      'type': 'delete_conversation',
      'id': groupId,
      'groupId': groupId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    await _broadcastToGroup(groupId, payload, myId);

    // Delete Locally
    await _local.deleteConversation(myId, groupId);

    try {
      await _firestore.collection('group_chats').doc(groupId).delete();
    } catch (e) {
      debugPrint('Firestore group delete warning: $e');
    }
  }

  // --- SELF HEALING: SYNC DELETED GROUPS ---
  // Call this on app startup or periodically
  Future<void> syncDeletedGroups() async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    // 1. Get all local groups
    final allChats = await _local.watchConversations(myId).first;
    final groups = allChats.where((c) => c['isGroup'] == true).toList();

    for (final group in groups) {
      final roomId = group['id'];
      if (roomId == null) continue;

      try {
        // 2. Check Firestore existence
        final doc = await _firestore
            .collection('group_chats')
            .doc(roomId)
            .get();
        if (!doc.exists) {
          debugPrint(
            'SYNC: Found deleted group locally ($roomId). Cleaning up...',
          );
          await _local.deleteConversation(myId, roomId);
        }
      } catch (e) {
        // Ignore errors (offline, etc) - we only delete if we are SURE it doesn't exist
      }
    }
  }

  // =========================================================================
  // DEEP LINKING: Join Group by Handle
  // =========================================================================

  /// Get current user ID (helper for widgets)
  String? get currentUserId => _auth.currentUser?.uid;

  /// Get group info by handle (for link preview/handling)
  Future<Map<String, dynamic>?> getGroupInfoByHandle(String handle) async {
    try {
      // 1. Look up group ID from handle
      final handleDoc = await _firestore
          .collection('group_handles')
          .doc(handle.toLowerCase())
          .get();

      if (!handleDoc.exists) {
        return null;
      }

      final groupId = handleDoc.data()?['roomId'] as String?;
      if (groupId == null) {
        return null;
      }

      // 2. Get group info
      final groupDoc = await _firestore
          .collection('group_chats')
          .doc(groupId)
          .get();

      if (!groupDoc.exists) {
        return null;
      }

      final data = groupDoc.data()!;
      return {
        'id': groupId,
        'groupName': data['groupName'],
        'groupIcon': data['groupIcon'],
        'description': data['description'],
        'groupHandle': data['groupHandle'],
        'isPublic': data['isPublic'] ?? false,
        'participants': data['participants'] ?? [],
        'admins': data['admins'] ?? [],
      };
    } catch (e) {
      debugPrint('ERROR: Failed to get group info by handle: $e');
      return null;
    }
  }

  /// Join a group by its handle (@handle)
  /// This is used by deep linking to join groups from shared links
  /// SAFE: Uses existing Firestore logic, doesn't touch encryption
  Future<void> joinGroupByHandle(String handle) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) {
      throw Exception('يجب تسجيل الدخول أولاً');
    }

    debugPrint('DEBUG: Looking up group with handle: @$handle');

    try {
      // 1. Look up group ID from handle
      final handleDoc = await _firestore
          .collection('group_handles')
          .doc(handle.toLowerCase())
          .get();

      if (!handleDoc.exists) {
        throw Exception('المجموعة غير موجودة');
      }

      final groupId = handleDoc.data()?['roomId'] as String?;
      if (groupId == null) {
        throw Exception('بيانات المجموعة غير صحيحة');
      }

      debugPrint('DEBUG: Found group ID: $groupId');

      // 2. Get group info from Firestore
      final groupDoc = await _firestore
          .collection('group_chats')
          .doc(groupId)
          .get();

      if (!groupDoc.exists) {
        throw Exception('المجموعة غير موجودة');
      }

      final groupData = groupDoc.data()!;
      final participants = List<String>.from(groupData['participants'] ?? []);
      final isPublic = groupData['isPublic'] ?? false;

      // 3. Check if already a member
      if (participants.contains(myId)) {
        debugPrint('DEBUG: User is already a member of this group');
        // Just create/update local conversation
        await _createLocalGroupConversation(groupId, groupData);
        return;
      }

      // 4. Join based on group type
      if (isPublic) {
        debugPrint('DEBUG: Joining public group directly');
        await _joinPublicGroupDirect(groupId, groupData);
      } else {
        debugPrint('DEBUG: Group is private, would need to send join request');
        // For now, just throw an error
        // In the future, implement join request system
        throw Exception(
          'المجموعة خاصة - يجب إرسال طلب انضمام',
        );
      }

      debugPrint('DEBUG: Successfully joined group @$handle');
    } catch (e) {
      debugPrint('ERROR: Failed to join group by handle: $e');
      rethrow;
    }
  }

  /// Helper: Join a public group directly
  Future<void> _joinPublicGroupDirect(
    String groupId,
    Map<String, dynamic> groupData,
  ) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    // Add user to participants in Firestore
    await _firestore.collection('group_chats').doc(groupId).update({
      'participants': FieldValue.arrayUnion([myId]),
    });

    // Create local conversation
    await _createLocalGroupConversation(groupId, groupData);

    // Send system message about join
    await _sendSystemMessage(
      groupId: groupId,
      userId: myId,
      messageText: 'انضممت إلى المجموعة',
    );

    // Broadcast join to existing members
    final payload = jsonEncode({
      'type': 'group_member_add',
      'id': groupId,
      'added_id': myId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    await _broadcastToGroup(groupId, payload, myId);
  }

  /// Helper: Create local group conversation
  Future<void> _createLocalGroupConversation(
    String groupId,
    Map<String, dynamic> groupData,
  ) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    final groupName = _readFieldText(groupData, const [
      'groupName',
      'name',
      'title',
    ]);
    final groupIcon = _readFieldText(groupData, const [
      'groupIcon',
      'icon',
      'imageUrl',
    ]);
    final groupDescription = _readFieldText(groupData, const [
      'description',
      'desc',
    ]);
    final groupHandle = _readFieldText(groupData, const [
      'groupHandle',
      'handle',
    ]);
    final category = _readFieldText(groupData, const [
      'category',
      'groupCategory',
      'channelCategory',
      'categoryName',
      'category_name',
      'section',
      'sectionName',
      'section_name',
    ]);
    final source = _readFieldText(groupData, const [
      'source',
      'sourceName',
      'source_name',
      'provider',
      'providerName',
      'provider_name',
      'playlist',
    ]);

    final conversation = {
      'id': groupId,
      'isGroup': true,
      'groupName': groupName ?? 'Group',
      'groupIcon': groupIcon,
      'description': groupDescription,
      'groupHandle': groupHandle,
      'participants': groupData['participants'] ?? [],
      'admins': groupData['admins'] ?? [],
      'isPublic': groupData['isPublic'] ?? false,
      'onlyAdminsCanPost': groupData['onlyAdminsCanPost'] ?? false,
      'adminPermissions': groupData['adminPermissions'],
      'lastMessageTime': DateTime.now().millisecondsSinceEpoch,
      'lastMessage': 'You joined the group',
      'unreadCounts': <String, int>{myId: 0},
      if (category != null) 'category': category,
      if (source != null) 'source': source,
      if (groupData['createdBy'] != null) 'createdBy': groupData['createdBy'],
    };

    await _local.updateConversation(myId, groupId, conversation);
  }

  /// Helper: Send a system message to a group
  Future<void> _sendSystemMessage({
    required String groupId,
    required String userId,
    required String messageText,
  }) async {
    try {
      final messageId = const Uuid().v4();
      final now = DateTime.now();

      final message = Message(
        id: messageId,
        senderId: userId,
        text: messageText,
        timestamp: now,
        isRead: true,
        type: 'system', // Special type for system messages
        isSystemMessage: true,
        status: MessageStatus.sent,
      );

      // Save to Firestore
      await _firestore
          .collection('group_chats')
          .doc(groupId)
          .collection('messages')
          .doc(messageId)
          .set(message.toMap());

      // Save locally for self
      await _local.saveMessage(userId, groupId, message.toMap());

      // Update last message in conversation
      await _local.updateConversationLastMessage(
        userId,
        groupId,
        messageText,
        now,
      );
    } catch (e) {
      debugPrint('ERROR: Failed to send system message: $e');
    }
  }

  /// Helper: Save a system message locally only (for incoming events)
  Future<void> _saveLocalSystemMessage(String groupId, String text) async {
    try {
      final messageId = const Uuid().v4();
      final message = Message(
        id: messageId,
        senderId: 'system',
        text: text,
        timestamp: DateTime.now(),
        isRead: true,
        type: 'system',
        isSystemMessage: true,
        status: MessageStatus.read,
      );
      await _local.saveMessage(
        _auth.currentUser!.uid,
        groupId,
        message.toMap(),
      );
    } catch (e) {
      debugPrint('Failed to save local system message: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // P2P HISTORY SYNC (Peer-to-Peer Recovery)
  // ---------------------------------------------------------------------------

  StreamSubscription? _syncRequestSubscription;
  StreamSubscription? _syncInboxSubscription;

  void _initializeSyncListeners() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // 1. Listen for requests FROM others
    _syncRequestSubscription = _firestore
        .collection('users')
        .doc(uid)
        .collection('sync_requests')
        .snapshots()
        .listen(
          (snapshot) {
            for (final change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                final data = change.doc.data();
                if (data != null) {
                  _processSyncRequest(SyncRequest.fromMap(data), change.doc.id);
                }
              }
            }
          },
          onError: (e) {
            debugPrint('Error listening to sync_requests: $e');
          },
        );

    // 2. Listen for synced data FOR me
    // 2. Listen for synced data FOR me
    _syncInboxSubscription = _firestore
        .collection('users')
        .doc(uid)
        .collection('sync_inbox')
        .snapshots()
        .listen(
          (snapshot) {
            for (final change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                final data = change.doc.data();
                if (data != null) {
                  _processSyncIncomingBundle(data, uid, change.doc.id);
                }
              }
            }
          },
          onError: (e) {
            debugPrint('DEBUG: Error listening to sync_inbox: $e');
          },
          cancelOnError: false,
        );
  }

  /// Step 1: I request sync from a peer
  Future<void> requestHistorySync(String peerId) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    // Throttle: one sync request per peer per minute (prevents pull-spam).
    final lastSent = _lastSyncRequestSent[peerId];
    if (lastSent != null &&
        DateTime.now().difference(lastSent) < const Duration(minutes: 1)) {
      debugPrint('P2P Sync: Request to $peerId throttled (sent < 1 min ago)');
      return;
    }
    _lastSyncRequestSent[peerId] = DateTime.now();

    _syncStatusController.add(SyncStatus.requesting);

    try {
      final myPublicKey = await CryptoService().getPublicKeyPem();
      if (myPublicKey == null) throw Exception('No public key found');

      final request = SyncRequest(
        id: const Uuid().v4(),
        requesterId: myId,
        requesterPublicKey: myPublicKey,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      // Send to Peer's request queue
      await _firestore
          .collection('users')
          .doc(peerId)
          .collection('sync_requests')
          .doc(request.id)
          .set(request.toMap());

      debugPrint('P2P Sync: Request sent to $peerId');
    } catch (e) {
      debugPrint('P2P Sync Error: Failed to send request: $e');
      rethrow;
    }
  }

  /// Step 2: specialized processing of SyncRequest
  Future<void> _processSyncRequest(SyncRequest request, String docId) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    // Ignore requests older than 5 minutes
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - request.timestamp > 5 * 60 * 1000) {
      // Cleanup old request
      _firestore
          .collection('users')
          .doc(myId)
          .collection('sync_requests')
          .doc(docId)
          .delete();
      return;
    }

    try {
      debugPrint('P2P Sync: Processing request from ${request.requesterId}');

      // SECURITY: Rate-limit repeated sync requests from the same requester
      // (max 1 per minute) to prevent history-harvesting abuse.
      final lastHandled = _lastSyncRequestHandled[request.requesterId];
      if (lastHandled != null &&
          DateTime.now().difference(lastHandled) < const Duration(minutes: 1)) {
        debugPrint('P2P Sync: Ignoring repeated request from ${request.requesterId}');
        await _firestore
            .collection('users')
            .doc(myId)
            .collection('sync_requests')
            .doc(docId)
            .delete();
        return;
      }

      // 1. Get Conversation ID
      final roomId = _getRoomId(myId, request.requesterId);

      // SECURITY: Only respond if a real local conversation exists with the
      // requester. Strangers can create sync_requests (Firestore rules allow
      // any signed-in user), and must not receive even an empty bundle.
      final localRoom = _local.getConversation(myId, roomId);
      if (localRoom == null) {
        debugPrint(
          'P2P Sync: No local conversation with ${request.requesterId}. Ignoring request.',
        );
        await _firestore
            .collection('users')
            .doc(myId)
            .collection('sync_requests')
            .doc(docId)
            .delete();
        return;
      }

      _lastSyncRequestHandled[request.requesterId] = DateTime.now();

      // 2. Get local messages
      final messages = await _local.getMessages(myId, roomId);

      final validMessages = messages.where((m) {
        // Don't sync deleted-for-everyone messages
        if (m['isDeletedEverywhere'] == true) return false;
        // Don't sync messages I deleted locally (tombstones) —
        // the requester must not receive what its owner erased.
        if (m['isDeleted'] == true) return false;
        return true;
      }).toList();

      if (validMessages.isEmpty) {
        debugPrint('P2P Sync: No messages to sync. Sending empty response.');
        // Don't return, proceed to send empty bundle
      }

      // 3. Re-Encrypt and Bundle
      List<Map<String, dynamic>> reEncryptedBundle = [];

      for (final msg in validMessages) {
        // FIXED: Properly handle all message types including audio/voice
        String? decryptedContent;
        String type = msg['type'] ?? 'text';

        // Extract content based on message type
        try {
          if (type == 'text') {
            decryptedContent = msg['text']?.toString();
          } else if (type == 'image') {
            decryptedContent = msg['imageUrl']?.toString();
          } else if (type == 'audio' || type == 'voice') {
            // CRITICAL FIX: Handle audio messages
            decryptedContent = msg['audioUrl']?.toString();
          } else if (type == 'file') {
            // FIX: files were never synced because 'fileUrl' was never read
            decryptedContent = msg['fileUrl']?.toString();
          } else {
            // Unknown type - try text as fallback
            decryptedContent = msg['text']?.toString();
          }

          // Validate content exists
          if (decryptedContent == null || decryptedContent.isEmpty) {
            debugPrint(
              'DEBUG: Skipping message ${msg['id']} - type=$type has no content (text/imageUrl/audioUrl is null/empty)',
            );
            continue;
          }
        } catch (e) {
          debugPrint(
            'DEBUG: Error extracting content for sync message ${msg['id']}: $e',
          );
          continue;
        }

        // Handling Media (Image/Audio/File): Convert file to Base64
        // IMPROVED: Better file handling with proper validation
        if (type == 'image' || type == 'audio' || type == 'voice' || type == 'file') {
          try {
            final file = File(decryptedContent);

            // Validate file exists and is readable
            if (!await file.exists()) {
              debugPrint(
                'DEBUG: Media file not found: $decryptedContent (type=$type, msgId=${msg['id']})',
              );
              continue;
            }

            final length = await file.length();

            // FIX: raised from 700KB to 5MB — voice recordings at the default
            // bitrate easily exceed 700KB and were silently skipped before.
            // Large messages are handled by the segmentation phase below.
            const maxFileSize = 5 * 1024 * 1024; // 5MB raw file

            if (length == 0) {
              debugPrint(
                'DEBUG: Media file is empty: $decryptedContent (type=$type, msgId=${msg['id']})',
              );
              continue;
            }

            if (length > maxFileSize) {
              debugPrint(
                'DEBUG: Media too large for P2P Sync: ${(length / 1024).toStringAsFixed(1)} KB > ${(maxFileSize / 1024).toStringAsFixed(1)} KB (type=$type, msgId=${msg['id']})',
              );
              continue;
            }

            // Read file and convert to Base64
            try {
              final bytes = await file.readAsBytes();
              final base64String = base64Encode(bytes);
              decryptedContent =
                  base64String; // Replace path with actual content
              debugPrint(
                'DEBUG: ✓ Converted $type file to Base64: ${(length / 1024).toStringAsFixed(1)} KB -> ${(base64String.length / 1024).toStringAsFixed(1)} KB chars (msgId=${msg['id']})',
              );
            } catch (e) {
              debugPrint(
                'DEBUG: Error reading media file bytes: $e (path=$decryptedContent, type=$type, msgId=${msg['id']})',
              );
              continue;
            }
          } catch (e) {
            debugPrint(
              'DEBUG: Error processing media file: $e (type=$type, msgId=${msg['id']}, content=$decryptedContent)',
            );
            continue;
          }
        }

        // Encrypt for Peer
        final encrypted = await EncryptionHelper.encryptMessage(
          decryptedContent,
          request.requesterPublicKey,
        );

        // Create a sync-specific message payload
        // Create a sync-specific message payload (STRICT SANITIZATION)
        final Map<String, dynamic> syncMsg = {};

        // 1. Strings & IDs
        syncMsg['id'] = msg['id']?.toString() ?? const Uuid().v4();
        syncMsg['senderId'] = msg['senderId']?.toString() ?? myId;
        syncMsg['type'] = msg['type']?.toString() ?? 'text';

        // 2. CRITICAL FIX: Add encrypted payload (required for decryption on restore)
        syncMsg['payload'] = jsonEncode(encrypted);

        // 2b. SECURITY: Sign the encrypted payload so the receiver can verify
        // the sync data truly comes from the claimed peer (not a Firestore intruder).
        final myPrivKey = await CryptoService().getPrivateKeyPem();
        if (myPrivKey != null) {
          final sig = _signPayload(syncMsg['payload'] as String, myPrivKey);
          if (sig != null) syncMsg['syncSignature'] = sig;
        }

        // 2c. Preserve file metadata so files keep their name/extension after sync
        if (msg['fileName'] != null) {
          syncMsg['fileName'] = msg['fileName']?.toString();
        }
        if (msg['audioDuration'] != null) {
          syncMsg['audioDuration'] = msg['audioDuration'];
        }

        // 3. Add other important fields for proper message reconstruction
        if (msg['timestamp'] != null) {
          syncMsg['timestamp'] = msg['timestamp'];
        }
        if (msg['replyToId'] != null) {
          syncMsg['replyToId'] = msg['replyToId']?.toString();
        }
        // IMPROVED: Optimize replySnapshot size (limit nested data if too large)
        if (msg['replySnapshot'] != null) {
          final replySnap = msg['replySnapshot'];
          if (replySnap is Map) {
            // Keep only essential fields to reduce size
            final textValue = replySnap['text']?.toString() ?? '';
            final textLength = textValue.length;
            final optimizedReply = <String, dynamic>{
              'id': replySnap['id'],
              'text': textLength > 100
                  ? textValue.substring(0, 100)
                  : textValue,
              'senderId': replySnap['senderId'],
              'type': replySnap['type'],
            };
            // Only include if size is reasonable (rough check)
            final snapJson = jsonEncode(optimizedReply);
            if (snapJson.length < 500) {
              // Limit reply snapshot to 500 chars
              syncMsg['replySnapshot'] = optimizedReply;
            } else {
              // If still too large, just keep essential info
              syncMsg['replySnapshot'] = {
                'id': replySnap['id'],
                'text': replySnap['text']?.toString().substring(0, 50) ?? '',
                'type': replySnap['type'] ?? 'text',
              };
            }
          } else {
            syncMsg['replySnapshot'] = replySnap;
          }
        }
        if (msg['isRead'] != null) {
          syncMsg['isRead'] = msg['isRead'];
        }
        if (msg['status'] != null) {
          syncMsg['status'] = msg['status']?.toString();
        }

        reEncryptedBundle.add(syncMsg);
      } // End of validMessages loop

      // PHASE 1: SEGMENTATION (Break down large single messages)
      // IMPROVED: Better segmentation with proper size limits
      final List<Map<String, dynamic>> segmentedBundle = [];
      // Increased to 400KB to handle encrypted Base64 media better
      // After encryption, this will be ~450-500KB, still safe for Firestore
      const int maxMsgSize = 400 * 1024; // 400 KB per segment

      for (final msg in reEncryptedBundle) {
        try {
          final String msgJson = jsonEncode(msg);
          final int msgSize = utf8.encode(msgJson).length;

          if (msgSize <= maxMsgSize) {
            segmentedBundle.add(msg);
          } else {
            // Split this message!
            debugPrint(
              'DEBUG: Segmenting large message ${msg['id']} (Size: $msgSize bytes, ${(msgSize / 1024).toStringAsFixed(1)} KB)',
            );
            final encodedBytes = utf8.encode(msgJson);
            final totalLen = encodedBytes.length;
            int offset = 0;
            int partIndex = 0;
            // Calculate total parts
            final totalParts = (totalLen / maxMsgSize).ceil();
            final String originalId = msg['id'].toString();

            while (offset < totalLen) {
              final int end = (offset + maxMsgSize < totalLen)
                  ? offset + maxMsgSize
                  : totalLen;
              final subBytes = encodedBytes.sublist(offset, end);
              final String chunkStr = base64Encode(subBytes); // Safe transport

              segmentedBundle.add({
                'isSegment': true,
                'originalId': originalId,
                'partIndex': partIndex,
                'totalParts': totalParts,
                'data': chunkStr,
                'senderId': myId, // Required for receiver routing
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              });

              offset += maxMsgSize;
              partIndex++;
            }
            debugPrint('DEBUG: Split into $totalParts segments');
          }
        } catch (e) {
          debugPrint('DEBUG: Error segmenting message ${msg['id']}: $e');
          // Skip this message but continue with others
          continue;
        }
      }

      // PHASE 2: BATCHING (Group items into upload batches)
      // IMPROVED: Better batching with async processing to avoid blocking
      // Increased to 750KB to handle encrypted content better
      const int maxBatchSize = 750 * 1024; // 750 KB per batch
      List<Map<String, dynamic>> currentBatch = [];
      int currentBatchSize = 0;
      int chunksSent = 0;

      final totalItems = segmentedBundle.length;
      debugPrint(
        'DEBUG: Starting p2p sync upload. Total items (after segmentation): $totalItems',
      );

      // Helper function to send a batch (async for better performance)
      Future<void> sendBatch(List<Map<String, dynamic>> batch) async {
        try {
          final batchId = const Uuid().v4();
          final String bundleJson = jsonEncode(batch);
          final batchSize = utf8.encode(bundleJson).length;

          await _firestore
              .collection('users')
              .doc(request.requesterId)
              .collection('sync_inbox')
              .doc(batchId)
              .set({
                'timestamp': DateTime.now().millisecondsSinceEpoch,
                'senderId': myId,
                'sync_bundle_json': bundleJson,
              });
          debugPrint(
            'DEBUG: Sent sync batch $batchId with ${batch.length} items (${(batchSize / 1024).toStringAsFixed(1)} KB)',
          );
        } catch (e) {
          debugPrint('DEBUG: Error sending batch: $e');
          rethrow;
        }
      }

      // Process items in batches
      for (var i = 0; i < segmentedBundle.length; i++) {
        final item = segmentedBundle[i];

        try {
          final String itemJson = jsonEncode(item);
          final int itemSize = utf8.encode(itemJson).length;

          // If adding this message would exceed limit, send current batch
          if (currentBatch.isNotEmpty &&
              (currentBatchSize + itemSize + 2048) > maxBatchSize) {
            // Add safety margin of 2KB for JSON overhead
            await sendBatch(currentBatch);
            chunksSent++;
            currentBatch = [];
            currentBatchSize = 0;
          }

          currentBatch.add(item);
          currentBatchSize += itemSize;
        } catch (e) {
          debugPrint('DEBUG: Error processing item $i for batching: $e');
          // Skip this item but continue
          continue;
        }
      }

      // Send final batch
      if (currentBatch.isNotEmpty) {
        await sendBatch(currentBatch);
        chunksSent++;
      }

      debugPrint(
        'DEBUG: Sync upload completed. Sent $chunksSent batches with $totalItems total items.',
      );

      // 5. Cleanup Request
      await _firestore
          .collection('users')
          .doc(myId)
          .collection('sync_requests')
          .doc(docId)
          .delete();

      debugPrint(
        'P2P Sync: Completed. Sent $chunksSent batches to ${request.requesterId}',
      );
    } catch (e) {
      debugPrint('P2P Sync Error: $e');
    }
  }

  /// Step 3: Receive and Apply Sync Bundle
  Future<void> _processSyncIncomingBundle(
    Map<String, dynamic> data,
    String myId,
    String docId,
  ) async {
    try {
      _syncStatusController.add(SyncStatus.downloading);

      List<Map<String, dynamic>> rawItems = [];

      // Handle JSON String Bundle (New format)
      if (data['sync_bundle_json'] != null) {
        try {
          final List<dynamic> decoded = jsonDecode(data['sync_bundle_json']);
          rawItems = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        } catch (e) {
          debugPrint('Error decoding sync_bundle_json: $e');
        }
      }
      // Handle Legacy Array (Fallback)
      else if (data['messages'] != null) {
        rawItems = List<Map<String, dynamic>>.from(data['messages']);
      }

      final senderId = data['senderId'];
      final roomId = _getRoomId(myId, senderId);
      final myPrivateKey = await CryptoService().getPrivateKeyPem();

      int restoredCount = 0;
      if (rawItems.isNotEmpty) {
        _syncStatusController.add(SyncStatus.restoring);
      }

      // RECONSTRUCTION LOGIC
      final List<Map<String, dynamic>> finalMessagesToProcess = [];

      for (final item in rawItems) {
        try {
          if (item['isSegment'] == true) {
            final String originalId = item['originalId'];
            final int partIndex = item['partIndex'];
            final int totalParts = item['totalParts'];
            final String chunkData = item['data'];

            if (!_pendingSegments.containsKey(originalId)) {
              // Prune stale partial messages (older than 10 min) to avoid leaks
              final cutoff = DateTime.now()
                  .subtract(const Duration(minutes: 10))
                  .millisecondsSinceEpoch;
              _pendingSegments.removeWhere(
                (_, v) => (v['timestamp'] as int? ?? 0) < cutoff,
              );
              _pendingSegments[originalId] = {
                'parts': <int, String>{}, // Map index -> data
                'total': totalParts,
                'received': 0,
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              };
            }

            final buffer = _pendingSegments[originalId]!;
            final Map<int, String> parts = buffer['parts'];

            if (!parts.containsKey(partIndex)) {
              parts[partIndex] = chunkData;
              buffer['received'] = (buffer['received'] as int) + 1;
            }

            // Check if complete
            if ((buffer['received'] as int) == totalParts) {
              // Reassemble!
              try {
                debugPrint(
                  'DEBUG: Reassembling message $originalId from $totalParts parts...',
                );
                final StringBuffer fullPayloadBase64 = StringBuffer();
                for (int i = 0; i < totalParts; i++) {
                  fullPayloadBase64.write(parts[i]);
                }

                final List<int> decodedBytes = base64Decode(
                  fullPayloadBase64.toString(),
                );
                final String decodedJson = utf8.decode(decodedBytes);
                final Map<String, dynamic> reconstructedMsg = jsonDecode(
                  decodedJson,
                );

                finalMessagesToProcess.add(reconstructedMsg);
                debugPrint(
                  'DEBUG: Successfully reassembled message $originalId',
                );
              } catch (e) {
                debugPrint('ERROR reassembling message $originalId: $e');
              }
              // Cleanup
              _pendingSegments.remove(originalId);
            }
          } else {
            // Normal message
            finalMessagesToProcess.add(item);
          }
        } catch (e) {
          debugPrint('Error processing sync item: $e');
        }
      }

      // Sort messages by timestamp (oldest first) to ensure correct order
      finalMessagesToProcess.sort((a, b) {
        final tsA = a['timestamp'] ?? 0;
        final tsB = b['timestamp'] ?? 0;
        return tsA.compareTo(tsB);
      });

      debugPrint(
        'DEBUG: Processing ${finalMessagesToProcess.length} messages for restoration',
      );

      // IMPROVED: Process messages with better error handling and batch saving
      final List<Map<String, dynamic>> messagesToSave = [];

      // Fetch the sender's public key ONCE per bundle for signature checks.
      final syncSenderKey = senderId != null
          ? await _keyRepo.getUserPublicKey(senderId.toString())
          : null;

      for (final syncMsg in finalMessagesToProcess) {
        // Validate message ID is present
        if (syncMsg['id'] == null || syncMsg['senderId'] == null) {
          debugPrint(
            'DEBUG: Skipping sync message with missing id or senderId',
          );
          continue;
        }

        // TOMBSTONE GUARD (all types): never resurrect a message I deleted locally.
        // Previously only media was protected, so deleted texts came back after sync.
        try {
          final existingMsg = await _local.getMessageRaw(
            myId,
            roomId,
            syncMsg['id'].toString(),
          );
          if (existingMsg != null && existingMsg['isDeleted'] == true) {
            debugPrint(
              'DEBUG: Skipping sync for locally deleted message ${syncMsg['id']}',
            );
            continue;
          }
        } catch (_) {
          // If the check fails, continue processing (fail-open for availability)
        }

        // SECURITY: Verify the sync signature when present.
        // Older peers don't sign — accepted transitionaly for compatibility.
        final syncSig = syncMsg['syncSignature'] as String?;
        if (syncSig != null && syncSenderKey != null) {
          final isValid = CryptoService().verifyString(
            syncMsg['payload'].toString(),
            syncSig,
            syncSenderKey,
          );
          if (!isValid) {
            debugPrint(
              'SECURITY ALERT: Invalid sync signature for message ${syncMsg['id']} from $senderId. Skipping.',
            );
            continue;
          }
        }

        // Decrypt the payload
        final payloadRaw = syncMsg['payload'];
        if (payloadRaw == null || payloadRaw.toString().isEmpty) {
          debugPrint(
            'DEBUG: Skipping sync message ${syncMsg['id']} - missing payload',
          );
          continue;
        }

        try {
          final encryptedMap = jsonDecode(payloadRaw);
          final decryptedContent = await EncryptionHelper.decryptMessage(
            encryptedMap,
            myPrivateKey!,
          );

          // Restore content fields based on type
          if (syncMsg['type'] == 'text') {
            syncMsg['text'] = decryptedContent;
          } else if (syncMsg['type'] == 'image' ||
              syncMsg['type'] == 'audio' ||
              syncMsg['type'] == 'voice' ||
              syncMsg['type'] == 'file') {
            // Check if decryptedContent is Base64 (starts with valid chars, no invalid path chars)
            // Simple heuristic: if it doesn't contain '/', it's likely Base64 (or a very weird filename).
            // A file path usually has separators. Base64 doesn't.
            final isBase64 =
                !decryptedContent.contains('/') &&
                !decryptedContent.contains('\\');

            if (isBase64 && decryptedContent.length > 50) {
              // --- Prevent Resurrecting Locally Deleted Files ---
              final existingMsg = await _local.getMessageRaw(myId, roomId, syncMsg['id']);
              bool skipFileWrite = false;
              
              if (existingMsg != null) {
                if (existingMsg['isDeleted'] == true) {
                  debugPrint('DEBUG: Skipping media restore for locally deleted message ${syncMsg['id']}');
                  continue; // Do not process or save this message at all
                }
                
                // If it exists but we didn't explicitly request a resync, don't overwrite the file
                // This prevents re-downloading files the user deliberately deleted from local storage
                if (existingMsg['status'] != 'requesting_resync') {
                  debugPrint('DEBUG: Skipping media write for ${syncMsg['id']} (not requesting resync)');
                  syncMsg['imageUrl'] = existingMsg['imageUrl'];
                  syncMsg['audioUrl'] = existingMsg['audioUrl'];
                  syncMsg['fileUrl'] = existingMsg['fileUrl'];
                  skipFileWrite = true;
                }
              }
              
              if (skipFileWrite) {
                // Since we skipped writing the file, we still want to save the metadata (e.g. read status)
                // but we don't execute the try-catch block below
              } else {
                try {
                final bytes = base64Decode(decryptedContent);
                final appDir = await getApplicationDocumentsDirectory();
                // Create a unique filename
                String extension = 'bin';
                if (syncMsg['type'] == 'image') extension = 'jpg';
                else if (syncMsg['type'] == 'audio' || syncMsg['type'] == 'voice') extension = 'm4a';
                else if (syncMsg['type'] == 'file') extension = syncMsg['fileName']?.split('.').last ?? 'file';
                
                final filename =
                    'synced_${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4()}.$extension';
                final localFile = File('${appDir.path}/$filename');

                await localFile.writeAsBytes(bytes);

                // Verify file was written successfully
                if (await localFile.exists()) {
                  final fileSize = await localFile.length();
                  debugPrint(
                    'DEBUG: ✓ Restored ${syncMsg['type']} file to ${localFile.path} (${(fileSize / 1024).toStringAsFixed(1)} KB)',
                  );

                  // Update the message with the NEW local path (use absolute path)
                  if (syncMsg['type'] == 'image') {
                    syncMsg['imageUrl'] = localFile.absolute.path;
                  } else if (syncMsg['type'] == 'file') {
                    syncMsg['fileUrl'] = localFile.absolute.path;
                  } else {
                    syncMsg['audioUrl'] = localFile.absolute.path;
                  }
                } else {
                  debugPrint(
                    'DEBUG: ✗ Failed to restore ${syncMsg['type']} - file not created',
                  );
                  // Fallback: try to use Base64 directly
                  if (syncMsg['type'] == 'image') {
                    syncMsg['imageUrl'] = decryptedContent;
                  } else if (syncMsg['type'] == 'file') {
                    syncMsg['fileUrl'] = decryptedContent;
                  } else {
                    syncMsg['audioUrl'] = decryptedContent;
                  }
                }
              } catch (e) {
                debugPrint('DEBUG: ✗ Error decoding Base64 media: $e');
                // Fallback: keep original string (might be broken)
                if (syncMsg['type'] == 'image') {
                  syncMsg['imageUrl'] = decryptedContent;
                } else if (syncMsg['type'] == 'file') {
                  syncMsg['fileUrl'] = decryptedContent;
                } else {
                  syncMsg['audioUrl'] = decryptedContent;
                }
              }
              } // Close the else block
            } else {
              // Should be a path, but likely invalid on this device.
              debugPrint(
                'DEBUG: Media content is not Base64 (length=${decryptedContent.length}, contains path chars=${decryptedContent.contains('/') || decryptedContent.contains('\\')})',
              );
              if (syncMsg['type'] == 'image') {
                syncMsg['imageUrl'] = decryptedContent;
              } else if (syncMsg['type'] == 'file') {
                syncMsg['fileUrl'] = decryptedContent;
              } else {
                syncMsg['audioUrl'] = decryptedContent;
              }
            }
          }

          // Ensure timestamp exists (required for sorting)
          if (syncMsg['timestamp'] == null) {
            syncMsg['timestamp'] = DateTime.now().millisecondsSinceEpoch;
          }

          // Remove payload after decryption to save space (content is now in text/imageUrl/audioUrl)
          syncMsg.remove('payload');

          // DEBUG: Log imageUrl for images to verify it's set correctly
          if (syncMsg['type'] == 'image' && syncMsg['imageUrl'] != null) {
            debugPrint(
              'DEBUG: ✓ Message ${syncMsg['id']} - imageUrl set to: ${syncMsg['imageUrl']}',
            );
            // Verify file exists
            try {
              final imgFile = File(syncMsg['imageUrl']);
              if (await imgFile.exists()) {
                final size = await imgFile.length();
                debugPrint(
                  'DEBUG: ✓ Image file exists: ${(size / 1024).toStringAsFixed(1)} KB',
                );
              } else {
                debugPrint(
                  'DEBUG: ✗ Image file does NOT exist at path: ${syncMsg['imageUrl']}',
                );
              }
            } catch (e) {
              debugPrint('DEBUG: ✗ Error checking image file: $e');
            }
          }

          // Add to batch for saving (more efficient than saving one by one)
          messagesToSave.add(syncMsg);
          restoredCount++;
        } catch (e) {
          debugPrint(
            'DEBUG: Error decrypting/processing sync message ${syncMsg['id']}: $e',
          );
          // Skip this message but continue with others
          continue;
        }
      }

      // IMPROVED: Batch save messages for better performance
      if (messagesToSave.isNotEmpty) {
        debugPrint(
          'DEBUG: Saving ${messagesToSave.length} restored messages...',
        );
        try {
          // Save messages in batches to avoid overwhelming the system
          const batchSize = 10; // Save 10 messages at a time
          for (int i = 0; i < messagesToSave.length; i += batchSize) {
            final batch = messagesToSave.sublist(
              i,
              (i + batchSize < messagesToSave.length)
                  ? i + batchSize
                  : messagesToSave.length,
            );

            // Save batch in parallel (non-blocking)
            await Future.wait(
              batch.map((msg) => _local.saveMessage(myId, roomId, msg)),
            );

            // Small delay between batches to prevent overwhelming the system
            if (i + batchSize < messagesToSave.length) {
              await Future.delayed(const Duration(milliseconds: 10));
            }
          }
          debugPrint('DEBUG: Successfully saved all restored messages');
        } catch (e) {
          debugPrint('DEBUG: Error batch saving messages: $e');
          // Fallback: try saving individually
          for (final msg in messagesToSave) {
            try {
              await _local.saveMessage(myId, roomId, msg);
            } catch (e2) {
              debugPrint(
                'DEBUG: Error saving individual message ${msg['id']}: $e2',
              );
            }
          }
        }
      }

      // FIX: Ensure conversation exists in the list (in case it was deleted locally)
      if (restoredCount > 0 && finalMessagesToProcess.isNotEmpty) {
        // Get the last message (newest) for preview (messages are already sorted)
        final lastMsg = finalMessagesToProcess.last;
        final preview = (lastMsg['type'] == 'image')
            ? '📷 صورة'
            : (lastMsg['type'] == 'audio' || lastMsg['type'] == 'voice')
            ? '🎤 رسالة صوتية'
            : (lastMsg['text'] ?? '');
        final ts = DateTime.fromMillisecondsSinceEpoch(
          lastMsg['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
        );

        await createOrGetChatRoom(senderId); // Ensures entry exists
        await _updateLocalConversation(
          roomId,
          preview,
          ts,
          incrementUnread: false,
        );
      }

      // Cleanup Inbox Item
      await _firestore
          .collection('users')
          .doc(myId)
          .collection('sync_inbox')
          .doc(docId)
          .delete();

      debugPrint('P2P Sync: Restored $restoredCount messages.');
      _syncStatusController.add(SyncStatus.completed);

      // Reset to idle after a delay
      Future.delayed(const Duration(seconds: 3), () {
        _syncStatusController.add(SyncStatus.idle);
      });
    } catch (e) {
      debugPrint('P2P Sync Error (Incoming): $e');
      _syncStatusController.add(SyncStatus.error);
    }
  }

  // ---------------------------------------------------------------------------
  // SMART SYNC PERSISTENCE (Active Chats)
  // ---------------------------------------------------------------------------

  /// Records that I have an active history with [peerId]
  /// Called when I send a message or receive one.
  Future<void> _markConversationActive(String peerId) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(myId)
          .collection('active_chats')
          .doc(peerId)
          .set({
            'last_updated': DateTime.now().millisecondsSinceEpoch,
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to mark conversation active: $e');
    }
  }

  /// Checks if I have a remote record of chat with [peerId].
  /// Used by UI to determine if "Pull to Sync" should be shown.
  Future<bool> hasRemoteChatHistory(String peerId) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return false;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(myId)
          .collection('active_chats')
          .doc(peerId)
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('Failed to check remote history: $e');
      return false;
    }
  }

  /// Restore Active Chats (for Home Screen)
  /// Checks remote active_chats list and ensures local placeholders exist.
  Future<void> restoreActiveChats() async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(myId)
          .collection('active_chats')
          .get();

      for (final doc in snapshot.docs) {
        final peerId = doc.id;

        // Skip if peerId is myself (sanity check, shouldn't happen)
        if (peerId == myId) continue;

        final roomId = _getRoomId(myId, peerId);

        // Check if exists locally
        final localRoom = _local.getConversation(myId, roomId);
        if (localRoom == null) {
          // Create placeholder
          debugPrint('DEBUG: Restoring active chat placeholder for $peerId');
          // This creates a blank conversation so it appears in the list
          await createOrGetChatRoom(peerId);
        }
      }
    } catch (e) {
      debugPrint('Failed to restore active chats: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // SCREENSHOT PROTECTION
  // ---------------------------------------------------------------------------
  Future<void> requestPeerProtection(
    String roomId,
    bool enabled, {
    bool isSync = false,
  }) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    // 1. Update Local: Outgoing Protection
    // This tracks my desire to block them (and me).
    final room = _local.getConversation(myId, roomId);
    if (room != null) {
      room['isOutgoingProtectionEnabled'] = enabled;
      await _local.updateConversation(myId, roomId, room);
    }

    if (isSync) return; // Propagated from remote

    // 2. Propagate
    if (roomId.startsWith('group_')) {
      // Group: Update Firestore
      final newSafety = enabled;
      await _firestore.collection('group_chats').doc(roomId).update({
        'isRemoteProtectionEnforced': newSafety,
      });
    } else {
      // 1-on-1: Send Command to Peer using standard encrypted/signed channel
      await _sendEncryptedContent(
        roomId,
        enabled.toString(),
        'cmd_screenshot_protection_request',
      );
      debugPrint('DEBUG: Sent screenshot protection request to $_getReceiverIdFromRoom(roomId, myId)');
    }
  }
}

// ---------------------------------------------------------------------------
// ISOLATE HELPERS
// ---------------------------------------------------------------------------

String? _signPayload(String payload, String privateKeyPem) {
  try {
    final privateKey = CryptoUtils.rsaPrivateKeyFromPem(privateKeyPem);
    final signer = pc.Signer("SHA-256/RSA");
    signer.init(true, pc.PrivateKeyParameter<pc.RSAPrivateKey>(privateKey));
    final signature = signer.generateSignature(
      Uint8List.fromList(utf8.encode(payload)),
    );
    if (signature is pc.RSASignature) {
      return base64Encode(signature.bytes);
    }
  } catch (e) {
    debugPrint('Signing failed: $e');
  }
  return null;
}
