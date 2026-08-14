import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:basic_utils/basic_utils.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

class CryptoService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _privateKeyKey = 'device_private_key';
  static const String _publicKeyKey = 'device_public_key';
  static const String _archivedKeysKey =
      'device_archived_keys'; // List of old private keys
  static const String _lastRotationKey = 'device_key_last_rotation';
  static const Duration _rotationInterval = Duration(hours: 5);
  static const Duration _archiveGracePeriod = Duration(hours: 2);

  // Singleton
  static final CryptoService _instance = CryptoService._internal();
  factory CryptoService() => _instance;
  CryptoService._internal();

  /// Checks if keys exist, generates them if not.
  Future<void> initializeKeys() async {
    final hasKey = await _storage.containsKey(key: _privateKeyKey);
    if (!hasKey) {
      debugPrint('Generating new RSA Key Pair...');
      await _generateAndSaveNewKeys();
    }
  }

  Future<String?> getPublicKeyPem() async {
    return await _storage.read(key: _publicKeyKey);
  }

  Future<String?> getPrivateKeyPem() async {
    return await _storage.read(key: _privateKeyKey);
  }

  /// Returns valid archived keys (not expired).
  /// Performs lazy cleanup of expired keys to enforce Forward Secrecy.
  Future<List<String>> getArchivedPrivateKeys() async {
    final jsonStr = await _storage.read(key: _archivedKeysKey);
    if (jsonStr == null) return [];
    try {
      final decoded = jsonDecode(jsonStr);
      final List<dynamic> list = decoded is List ? decoded : [];

      final now = DateTime.now().millisecondsSinceEpoch;
      final validKeys = <String>[];
      final keptEntries = <Map<String, dynamic>>[];
      bool needsUpdate = false;

      for (final item in list) {
        // Support migration from old format (List<String>) to new (List<Map>)
        if (item is! Map) continue;

        final entry = Map<String, dynamic>.from(item);
        final expiry = entry['expiry'] as int? ?? 0;

        if (expiry > now) {
          validKeys.add(entry['pem'] as String);
          keptEntries.add(entry);
        } else {
          needsUpdate = true; // Prune expired key (Secure Delete)
        }
      }

      if (needsUpdate) {
        await _storage.write(
          key: _archivedKeysKey,
          value: jsonEncode(keptEntries),
        );
      }

      return validKeys;
    } catch (e) {
      debugPrint('Error reading archived keys: $e');
      return [];
    }
  }

  /// Rotates the Identity Key Pair.
  /// 1. Archives the current Private Key (for decrypting old messages).
  /// 2. Generates a new Key Pair.
  /// 3. Returns the NEW Public Key PEM (to be uploaded).
  Future<String> rotateKeys({bool force = false}) async {
    // Check if rotation is needed (Time-based)
    if (!force && !await _shouldRotate()) {
      final current = await getPublicKeyPem();
      if (current != null) return current;
    }

    debugPrint('Security: Rotating Identity Keys (Forward Secrecy)...');

    // 1. Archive Current Key
    final currentPrivate = await getPrivateKeyPem();
    if (currentPrivate != null) {
      final jsonStr = await _storage.read(key: _archivedKeysKey);
      List<dynamic> list = [];
      if (jsonStr != null) {
        try {
          list = jsonDecode(jsonStr);
        } catch (_) {}
      }

      // Add new entry with Expiry
      final entry = {
        'pem': currentPrivate,
        'expiry': DateTime.now()
            .add(_archiveGracePeriod)
            .millisecondsSinceEpoch,
      };

      // Insert at beginning
      list.insert(0, entry);

      // Safety cap (keep max 5 concurrent keys to prevent storage bloat)
      if (list.length > 5) list = list.sublist(0, 5);

      await _storage.write(key: _archivedKeysKey, value: jsonEncode(list));
      debugPrint('Security: Archived old private key.');
    }

    // 2. Generate & Save New Keys
    return await _generateAndSaveNewKeys();
  }

  Future<String> _generateAndSaveNewKeys() async {
    final keyPair = await compute(_generateKeysInBackground, null);
    final publicPem = keyPair['public']!;
    final privatePem = keyPair['private']!;

    await _storage.write(key: _publicKeyKey, value: publicPem);
    await _storage.write(key: _privateKeyKey, value: privatePem);

    // Save Rotation Timestamp
    await _storage.write(
      key: _lastRotationKey,
      value: DateTime.now().millisecondsSinceEpoch.toString(),
    );

    debugPrint('Security: New Identity Keys generated and saved.');
    return publicPem;
  }

  /// Verifies a [signature] (Base64) against a [payload] using [publicKeyPem].
  bool verifyString(String payload, String signature, String publicKeyPem) {
    try {
      final publicKey = CryptoUtils.rsaPublicKeyFromPem(publicKeyPem);
      final signer = pc.Signer("SHA-256/RSA");

      // Initialize signer with public key (for verification)
      signer.init(false, pc.PublicKeyParameter<pc.RSAPublicKey>(publicKey));

      final processSignature = pc.RSASignature(base64Decode(signature));

      return signer.verifySignature(
        Uint8List.fromList(utf8.encode(payload)),
        processSignature,
      );
    } catch (e) {
      debugPrint('Error verifying signature: $e');
      return false;
    }
  }

  Future<bool> _shouldRotate() async {
    final lastStr = await _storage.read(key: _lastRotationKey);
    if (lastStr == null) return true; // Never rotated (or legacy)

    final lastTs = int.tryParse(lastStr) ?? 0;
    final lastDate = DateTime.fromMillisecondsSinceEpoch(lastTs);
    final diff = DateTime.now().difference(lastDate);

    return diff > _rotationInterval;
  }

  /// Returns the timestamp of the last key rotation
  Future<DateTime?> getLastRotationTime() async {
    final lastStr = await _storage.read(key: _lastRotationKey);
    if (lastStr == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(int.parse(lastStr));
  }

  /// Static helper to generate keys in a background isolate
  static Map<String, String> _generateKeysInBackground(dynamic _) {
    final secureRandom = pc.SecureRandom("Fortuna");
    final random = Random.secure();
    final seed = List<int>.generate(32, (_) => random.nextInt(256));
    secureRandom.seed(pc.KeyParameter(Uint8List.fromList(seed)));

    var rsapars = pc.RSAKeyGeneratorParameters(BigInt.parse("65537"), 2048, 64);
    var params = pc.ParametersWithRandom(rsapars, secureRandom);
    var keyGenerator = pc.RSAKeyGenerator();
    keyGenerator.init(params);
    final pair = keyGenerator.generateKeyPair();

    final publicPem = CryptoUtils.encodeRSAPublicKeyToPem(
      pair.publicKey as pc.RSAPublicKey,
    );
    final privatePem = CryptoUtils.encodeRSAPrivateKeyToPem(
      pair.privateKey as pc.RSAPrivateKey,
    );

    return {'public': publicPem, 'private': privatePem};
  }
}
