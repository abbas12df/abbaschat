import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/export.dart' as pc;

class EncryptionHelper {
  /// Encrypts payload using a fresh AES Key, then encrypts that AES key with Receiver's Public Key.
  ///
  /// Security note: the session key is wrapped TWICE:
  /// - `encrypted_key_oaep`: RSA-OAEP with SHA-256 (modern, padding-oracle resistant).
  /// - `encrypted_key`: legacy RSA PKCS#1 v1.5, kept ONLY so older app versions
  ///   (which can only unwrap PKCS1) can still decrypt the message.
  /// New versions always prefer OAEP when unwrapping.
  static Future<Map<String, dynamic>> encryptMessage(
    String plaintext,
    String receiverPublicKeyPem,
  ) async {
    // 1. Generate Ephemeral Session Key (AES-256)
    final sessionKey = enc.Key.fromSecureRandom(32);
    final iv = enc.IV.fromSecureRandom(12);

    // 2. Encrypt Payload (AES-GCM)
    final encrypter = enc.Encrypter(enc.AES(sessionKey, mode: enc.AESMode.gcm));
    final encryptedData = encrypter.encrypt(plaintext, iv: iv);

    // 3. Encrypt Session Key with Receiver's RSA Public Key
    final parser = enc.RSAKeyParser();
    final rsaPublicKey = parser.parse(receiverPublicKeyPem) as pc.RSAPublicKey;

    // 3a. Modern: RSA-OAEP with SHA-256
    final oaepEncrypter = enc.Encrypter(
      enc.RSA(
        publicKey: rsaPublicKey,
        encoding: enc.RSAEncoding.OAEP,
        digest: enc.RSADigest.SHA256,
      ),
    );
    final encryptedSessionKeyOaep =
        oaepEncrypter.encryptBytes(sessionKey.bytes).base64;

    // 3b. Legacy: PKCS#1 v1.5 (backward compatibility with older clients)
    final pkcs1Encrypter = enc.Encrypter(
      enc.RSA(publicKey: rsaPublicKey, encoding: enc.RSAEncoding.PKCS1),
    );
    final encryptedSessionKeyPkcs1 =
        pkcs1Encrypter.encryptBytes(sessionKey.bytes).base64;

    // Bundle
    return {
      'iv': iv.base64,
      'ciphertext': encryptedData.base64,
      'encrypted_key': encryptedSessionKeyPkcs1,
      'encrypted_key_oaep': encryptedSessionKeyOaep,
    };
  }

  /// Decrypts the message bundle using Device's Private Key.
  ///
  /// Prefers the OAEP-wrapped session key; falls back to legacy PKCS#1 v1.5
  /// for messages sent by older app versions. Never fails just because one of
  /// the two wrapped keys is missing or malformed.
  static Future<String> decryptMessage(
    Map<String, dynamic> bundle,
    String myPrivateKeyPem,
  ) async {
    final iv = enc.IV.fromBase64(bundle['iv']);
    final ciphertext = enc.Encrypted.fromBase64(bundle['ciphertext']);

    // 1. Decrypt Session Key using My Private Key
    final parser = enc.RSAKeyParser();
    final rsaPrivateKey = parser.parse(myPrivateKeyPem) as pc.RSAPrivateKey;

    Uint8List? sessionKeyBytes;

    // 1a. Preferred: RSA-OAEP with SHA-256
    final oaepKeyBase64 = bundle['encrypted_key_oaep'];
    if (oaepKeyBase64 is String && oaepKeyBase64.isNotEmpty) {
      try {
        final oaepDecrypter = enc.Encrypter(
          enc.RSA(
            privateKey: rsaPrivateKey,
            encoding: enc.RSAEncoding.OAEP,
            digest: enc.RSADigest.SHA256,
          ),
        );
        sessionKeyBytes = Uint8List.fromList(
          oaepDecrypter.decryptBytes(enc.Encrypted.fromBase64(oaepKeyBase64)),
        );
      } catch (_) {
        // Fall through to legacy key below.
      }
    }

    // 1b. Legacy fallback: PKCS#1 v1.5 (messages from older clients)
    if (sessionKeyBytes == null) {
      final pkcs1KeyBase64 = bundle['encrypted_key'];
      if (pkcs1KeyBase64 is! String || pkcs1KeyBase64.isEmpty) {
        throw Exception('Decryption Failed: no usable encrypted session key');
      }
      final pkcs1Decrypter = enc.Encrypter(
        enc.RSA(privateKey: rsaPrivateKey, encoding: enc.RSAEncoding.PKCS1),
      );
      sessionKeyBytes = Uint8List.fromList(
        pkcs1Decrypter.decryptBytes(enc.Encrypted.fromBase64(pkcs1KeyBase64)),
      );
    }

    final sessionKey = enc.Key(sessionKeyBytes);

    // 2. Decrypt Payload (AES-GCM)
    final encrypter = enc.Encrypter(enc.AES(sessionKey, mode: enc.AESMode.gcm));
    final decrypted = encrypter.decrypt(ciphertext, iv: iv);

    return decrypted;
  }
}
