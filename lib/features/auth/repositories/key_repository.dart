import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qqqq/core/security/crypto_service.dart';

final keyRepositoryProvider = Provider<KeyRepository>((ref) {
  return KeyRepository(FirebaseDatabase.instance, FirebaseAuth.instance);
});

class KeyRepository {
  final FirebaseDatabase _rtdb;
  final FirebaseAuth _auth;

  KeyRepository(this._rtdb, this._auth);

  /// Uploads the current user's Public Key to RTDB
  Future<void> uploadMyPublicKey() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final pem = await CryptoService().getPublicKeyPem();
    if (pem != null) {
      await _rtdb.ref('users_public_keys/$uid').set(pem);
    }
  }

  /// Fetches the Public Key for a given User ID
  Future<String?> getUserPublicKey(String userId) async {
    final snapshot = await _rtdb.ref('users_public_keys/$userId').get();
    if (snapshot.exists && snapshot.value is String) {
      return snapshot.value as String;
    }
    return null;
  }
}
