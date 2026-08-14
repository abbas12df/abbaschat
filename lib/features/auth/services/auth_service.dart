import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../../chat/repositories/chat_repository.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(FirebaseAuth.instance, ref);
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

class AuthService {
  final FirebaseAuth _auth;
  final Ref _ref;

  AuthService(this._auth, this._ref);

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Email/Password Sign Up
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Email/Password Sign In
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Send Email Verification
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  // Check if Username is Available
  Future<bool> isUsernameAvailable(String username) async {
    final result = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: username)
        .get();
    return result.docs.isEmpty;
  }

  // Save User Profile to Firestore
  Future<void> saveUserProfile({
    required String uid,
    required String email,
    required String displayName,
    required String username,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'username': username, // Searchable
      'createdAt': FieldValue.serverTimestamp(),
      'photoURL': null,
    }, SetOptions(merge: true));

    // Also update Auth Profile
    await _auth.currentUser?.updateDisplayName(displayName);
  }

  // Get User Profile
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return doc.data();
  }

  // Google Sign In
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print('Google Sign In Error: $e');
      rethrow;
    }
  }

  // Apple Sign In
  Future<UserCredential?> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final OAuthProvider provider = OAuthProvider('apple.com');
      final credential = provider.credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
        rawNonce: rawNonce,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print('Apple Sign In Error: $e');
      rethrow;
    }
  }

  // Helper for Apple Sign In Nonce
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> signOut() async {
    try {
      try {
        await _ref.read(chatRepositoryProvider).setOffline();
      } catch (e) {
        print('DEBUG: Failed to set offline status on logout: $e');
      }

      await FirebaseDatabase.instance.goOffline();
      await GoogleSignIn().signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  // Re-authentication
  Future<void> reauthenticateUser(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw FirebaseAuthException(code: 'no-user', message: 'User not found');
    }

    AuthCredential credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );

    await user.reauthenticateWithCredential(credential);
  }

  // Delete Account
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.delete();
      }
    } catch (e) {
      rethrow;
    }
  }

  // Password Reset
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateEmail(String newEmail) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.verifyBeforeUpdateEmail(newEmail);
    }
  }

  Future<void> linkPassword(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw FirebaseAuthException(
        code: 'no-user',
        message: 'User not found or email is null',
      );
    }

    // Check if user already has password provider
    final hasPassword = user.providerData.any(
      (p) => p.providerId == 'password',
    );

    if (hasPassword) {
      throw FirebaseAuthException(
        code: 'already-linked',
        message: 'Password already linked to this account',
      );
    }

    // Create credential and link
    try {
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.linkWithCredential(credential);
    } catch (e) {
      // If linking fails, try creating a new account and linking
      // This handles cases where email/password account doesn't exist yet
      if (e is FirebaseAuthException && e.code == 'invalid-credential') {
        // Create a new email/password account first, then link
        // Note: This is a workaround - ideally we'd use updatePassword if available
        throw FirebaseAuthException(
          code: 'link-failed',
          message: 'Unable to link password. Please try again or contact support.',
        );
      }
      rethrow;
    }
  }
}
