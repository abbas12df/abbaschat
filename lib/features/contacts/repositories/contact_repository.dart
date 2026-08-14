import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:rxdart/rxdart.dart';
import '../../chat/models/user_model.dart';
// Removed unused local_storage_service import

final contactRepositoryProvider = Provider((ref) => ContactRepository(ref));

class ContactRepository {
  // Removed unused _ref field
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ContactRepository(
    Ref ref,
  ); // Keep constructor signature but ignore ref if not needed yet

  // ---------------------------------------------------------------------------
  // DATA MODELS
  // ---------------------------------------------------------------------------

  // Local metadata structure: { uid: { alias: String?, group: String? } }

  Future<Box> _ensureBoxOpen() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('No user');
    final boxName = 'contacts_meta_$uid';
    if (!Hive.isBoxOpen(boxName)) {
      return await Hive.openBox(boxName);
    }
    return Hive.box(boxName);
  }

  Box? _getMetaBoxSync() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final boxName = 'contacts_meta_$uid';
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box(boxName);
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // ACTIONS
  // ---------------------------------------------------------------------------

  /// Search for users by exact username or phone, or partial display name
  Future<List<UserModel>> searchUsers(String query) async {
    if (query.isEmpty) return [];

    // 1. Try exact username match
    final usernameSnapshot = await _firestore
        .collection('users')
        .where('username', isEqualTo: query)
        .get();

    if (usernameSnapshot.docs.isNotEmpty) {
      return usernameSnapshot.docs
          .map((d) => UserModel.fromMap(d.data(), d.id))
          .toList();
    }

    // 2. Try partial Display Name (Simple prefix match)
    final nameSnapshot = await _firestore
        .collection('users')
        .where('displayName', isGreaterThanOrEqualTo: query)
        .where('displayName', isLessThan: query + 'z')
        .limit(10)
        .get();

    return nameSnapshot.docs
        .map((d) => UserModel.fromMap(d.data(), d.id))
        .toList();
  }

  /// Adds a user to contacts. optional alias/group stored locally.
  Future<void> addContact(
    String contactUid, {
    String? alias,
    String? group,
  }) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) throw Exception('Not authenticated');

    // 1. Update Firestore (Public/Syncd List)
    await _firestore.collection('users').doc(myId).update({
      'contacts': FieldValue.arrayUnion([contactUid]),
    });

    // 2. Update Local Metadata (Private)
    if (alias != null || group != null) {
      final box = await _ensureBoxOpen();
      await box.put(contactUid, {
        'alias': alias,
        'group': group,
        'addedAt': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  Future<void> updateContact(
    String contactUid, {
    String? alias,
    String? group,
  }) async {
    final box = await _ensureBoxOpen();
    final existing = box.get(contactUid) ?? {};
    final newData = Map<String, dynamic>.from(existing);
    if (alias != null) newData['alias'] = alias;
    if (group != null) newData['group'] = group;

    await box.put(contactUid, newData);
  }

  Future<void> removeContact(String contactUid) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    // 1. Remove from Firestore
    await _firestore.collection('users').doc(myId).update({
      'contacts': FieldValue.arrayRemove([contactUid]),
    });

    // 2. Remove Local Metadata
    final box = await _ensureBoxOpen();
    await box.delete(contactUid);
  }

  // ---------------------------------------------------------------------------
  // STREAMS
  // ---------------------------------------------------------------------------

  /// Stream of Full Contact Objects with Metadata merged
  Stream<List<Contact>> watchContacts() {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return Stream.value([]);

    // Watch Firestore 'contacts' array
    return _firestore.collection('users').doc(myId).snapshots().switchMap((
      doc,
    ) {
      if (!doc.exists) return Stream.value([]);

      final data = doc.data() as Map<String, dynamic>;
      final contactIds = List<String>.from(data['contacts'] ?? []);

      if (contactIds.isEmpty) return Stream.value([]);

      // Fetch UserModels for these IDs
      // Note: In a large app, we'd paginate or batch this. For now, whereIn is limited to 10.
      // We'll simplisticly fetch one-by-one or chunk if needed, but for < 100 contacts standard fetch is OK.
      // Better approach: Listen to 'users' collection where documentId IN [....] (firestore limit 10).
      // Workaround: We fetch the details once or rely on a "Users" cache.
      // For Realtime presence, we can listen to collection 'users' but filtering by IDs only in chunks.

      // OPTIMAL: Fetch once, then listen?
      // Let's just fetch Once to display, and maybe Re-fetch on pull refresh.
      // BUT requirement says "Online Status", so we need stream.
      // Let's stream the entire 'users' collection? NO, too expensive.
      // Let's stream only the specific docs. Dart firestore doesn't support "whereId in list" with streaming easily for > 10 items.

      // COMPROMISE: We will fetch UserModels ONCE. Presence is handled separately or we rely on the generic user stream in ChatRepo if recently active.
      // Actually, for "Contacts List", one-time fetch is standard, with maybe a listener for online status on visible items.

      // Ensure box is open before we map
      // Handle > 10 contacts by chunking
      return Stream.fromFuture(_ensureBoxOpen()).switchMap((_) {
        if (contactIds.length <= 10) {
          // Simple case: <= 10 contacts
          return _firestore
              .collection('users')
              .where(FieldPath.documentId, whereIn: contactIds)
              .snapshots()
              .map((snap) {
                final box = _getMetaBoxSync();
                return snap.docs.map((d) {
                  final user = UserModel.fromMap(d.data(), d.id);
                  final meta = box?.get(user.uid);
                  return Contact(
                    user: user,
                    alias: meta?['alias'],
                    group: meta?['group'],
                  );
                }).toList();
              });
        } else {
          // Chunk contacts into groups of 10
          final chunks = <List<String>>[];
          for (int i = 0; i < contactIds.length; i += 10) {
            chunks.add(contactIds.skip(i).take(10).toList());
          }

          // Combine streams from all chunks
          final streams = chunks.map((chunk) {
            return _firestore
                .collection('users')
                .where(FieldPath.documentId, whereIn: chunk)
                .snapshots();
          });

          return Rx.combineLatestList(streams).map((snapshots) {
            final box = _getMetaBoxSync();
            final allContacts = <Contact>[];

            for (final snapshot in snapshots) {
              for (final doc in snapshot.docs) {
                final user = UserModel.fromMap(doc.data(), doc.id);
                final meta = box?.get(user.uid);
                allContacts.add(
                  Contact(
                    user: user,
                    alias: meta?['alias'],
                    group: meta?['group'],
                  ),
                );
              }
            }

            // Sort by display name
            allContacts.sort((a, b) => a.displayName.compareTo(b.displayName));
            return allContacts;
          });
        }
      });

      // Note: To support > 10 contacts, we'd need to chunk the whereIn or use client-side filtering (bad for bandwidth).
      // or simply fetch all users (also bad).
      // CORRECT WAY: Create a 'contacts' subcollection or just don't stream *everything*.
      // For this task, I'll assume < 10 for demo or implement manual combineLatest if crucial.
    });
  }

  /// Get list of contact UIDs (synchronous, from Firestore cache if available)
  Future<List<String>> getContactIds() async {
    final myId = _auth.currentUser?.uid;
    if (myId == null) return [];

    try {
      final doc = await _firestore.collection('users').doc(myId).get();
      if (!doc.exists) return [];
      final data = doc.data();
      return List<String>.from(data?['contacts'] ?? []);
    } catch (e) {
      return [];
    }
  }

  /// Get contacts as UserModel list (for use in group member selection)
  Future<List<UserModel>> getContactsAsUsers() async {
    final contactIds = await getContactIds();
    if (contactIds.isEmpty) return [];

    try {
      // Fetch in chunks of 10 (Firestore limit)
      final List<UserModel> allUsers = [];
      for (int i = 0; i < contactIds.length; i += 10) {
        final chunk = contactIds.skip(i).take(10).toList();
        final snapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        allUsers.addAll(
          snapshot.docs.map((d) => UserModel.fromMap(d.data(), d.id)),
        );
      }
      return allUsers;
    } catch (e) {
      return [];
    }
  }
}

// Wrapper Class for UI
class Contact {
  final UserModel user;
  final String? alias;
  final String? group;

  Contact({required this.user, this.alias, this.group});

  String get displayName => alias ?? user.displayName;
}
