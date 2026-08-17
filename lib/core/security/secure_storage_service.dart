import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final secureStorageServiceProvider = Provider((ref) => SecureStorageService());

class SecureStorageService {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    wOptions: WindowsOptions(),
  );
  static const _hiveKeyAlias = 'hive_encryption_key_v1';

  /// Returns the 32-byte AES key for Hive encryption.
  /// Generates and persists one if it doesn't exist.
  Future<Uint8List> getHiveEncryptionKey() async {
    // 1. Try to read existing key
    final base64Key = await _storage.read(key: _hiveKeyAlias);

    if (base64Key != null) {
      return base64Decode(base64Key);
    }

    // 2. Generate new 32-byte key
    final validationKey = _generateSecureKey();
    final encodedKey = base64Encode(validationKey);

    // 3. Save to Secure Storage
    await _storage.write(key: _hiveKeyAlias, value: encodedKey);

    return validationKey;
  }

  Uint8List _generateSecureKey() {
    final random = Random.secure();
    final bytes = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }
}
