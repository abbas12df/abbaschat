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
    await _rtdb.ref('relay_messages/$receiverId/$messageId').set(payload);
  }

  /// Listens to my own relay inbox.
  Stream<DatabaseEvent> get myInboxStream {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return const Stream.empty();
    return _rtdb.ref('relay_messages/$myId').onChildAdded;
  }

  /// Sends a Delivery ACK to the sender.
  Future<void> sendAck({
    required String senderId,
    required String messageId,
  }) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    await _rtdb.ref('delivery_receipts/$senderId/$messageId').set({
      'reader_id': myId,
      'timestamp': ServerValue.timestamp,
    });
  }

  /// Deletes a message from MY inbox (after successful decryption & save).
  Future<void> deleteFromRelay(String messageId) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;
    await _rtdb.ref('relay_messages/$myId/$messageId').remove();
  }
}
