import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/export.dart' as pc;

class EncryptionHelper {
  /// Encrypts payload using a fresh AES Key, then encrypts that AES key with Receiver's Public Key.
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
    // Use high-level Encrypter(RSA) which handles padding (PKCS1) and types
    final parser = enc.RSAKeyParser();
    final rsaPublicKey = parser.parse(receiverPublicKeyPem) as pc.RSAPublicKey;
    final rsaEncrypter = enc.Encrypter(
      enc.RSA(publicKey: rsaPublicKey, encoding: enc.RSAEncoding.PKCS1),
    );

    final encryptedSessionKey = rsaEncrypter.encryptBytes(sessionKey.bytes);
    final encryptedSessionKeyBase64 = encryptedSessionKey.base64;

    // Bundle
    return {
      'iv': iv.base64,
      'ciphertext': encryptedData.base64,
      'encrypted_key': encryptedSessionKeyBase64,
    };
  }

  /// Decrypts the message bundle using Device's Private Key.
  static Future<String> decryptMessage(
    Map<String, dynamic> bundle,
    String myPrivateKeyPem,
  ) async {
    final iv = enc.IV.fromBase64(bundle['iv']);
    final ciphertext = enc.Encrypted.fromBase64(bundle['ciphertext']);
    final encryptedSessionKeyBase64 = bundle['encrypted_key'];

    // 1. Decrypt Session Key using My Private Key
    final parser = enc.RSAKeyParser();
    final rsaPrivateKey = parser.parse(myPrivateKeyPem) as pc.RSAPrivateKey;
    final rsaDecrypter = enc.Encrypter(
      enc.RSA(privateKey: rsaPrivateKey, encoding: enc.RSAEncoding.PKCS1),
    );

    final encryptedKeyBytes = enc.Encrypted.fromBase64(
      encryptedSessionKeyBase64,
    );
    final sessionKeyBytes = rsaDecrypter.decryptBytes(encryptedKeyBytes);
    final sessionKey = enc.Key(Uint8List.fromList(sessionKeyBytes));

    // 2. Decrypt Payload (AES-GCM)
    final encrypter = enc.Encrypter(enc.AES(sessionKey, mode: enc.AESMode.gcm));
    final decrypted = encrypter.decrypt(ciphertext, iv: iv);

    return decrypted;
  }
}
