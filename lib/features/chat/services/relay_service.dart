import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final relayServiceProvider = Provider<RelayService>((ref) {
  return RelayService(FirebaseDatabase.instance, FirebaseAuth.instance);
});

class RelayService {
  final FirebaseDatabase _rtdb;
  final FirebaseAuth _auth;

  RelayService(this._rtdb, this._auth);

  /// Pushes an encrypted message bundle to the Receiver's Inbox in Relay.
  /// does NOT delete it.
  Future<void> pushToRelay({
    required String receiverId,
    required String messageId,
    required Map<String, dynamic> encryptedBundle,
  }) async {
    final senderId = _auth.currentUser?.uid;
    if (senderId == null) throw Exception('Not authenticated');

    final payload = {
      'sender_id': senderId,
      'timestamp': ServerValue.timestamp,
      'payload': encryptedBundle,
      // 'signature': ... (Optional for future authenticity check)
    };

    // Pending -> relay_messages/{receiverId}/{messageId}
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _rtdb.ref('relay_messages/$receiverId/$messageId').set(payload);
    } catch (e) {
      // Ignore
    }
  }

  /// Listens to my own relay inbox.
  Stream<DatabaseEvent> get myInboxStream {
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) {
      return const Stream.empty();
    }
    final myId = _auth.currentUser?.uid;
    if (myId == null) return const Stream.empty();
    return _rtdb.ref('relay_messages/$myId').onChildAdded;
  }

  /// Sends a Delivery ACK to the sender.
  Future<void> sendAck({
    required String senderId,
    required String messageId,
  }) async {
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) return;
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;
    try {
      await _rtdb.ref('relay_messages/$senderId/$messageId').update({'status': 'delivered'});
    } catch (_) {}
  }

  /// Removes a specific message from my inbox (after processing).
  Future<void> removeMessage(String messageId) async {
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) return;
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;
    try {
      await _rtdb.ref('relay_messages/$myId/$messageId').remove();
    } catch (_) {}
  }

  Future<void> nukeConversationFromRelay(String otherId) async {
    // Actually we can't easily query by 'sender_id' in RTDB without index.
    // Real app: Cloud Function cleans up, or we fetch all and delete manually.
    debugPrint('Nuking conversation from relay is a no-op on client side without index.');
  }
}
