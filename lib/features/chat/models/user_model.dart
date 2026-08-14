import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String displayName;
  final String? username; // Unique ID for search
  final String? bio;
  final String? phoneNumber;
  final String? photoURL;
  final bool isOnline;
  final DateTime? lastSeen;
  final List<String> blockedUsers;
  final List<String> contacts;

  UserModel({
    required this.uid,
    required this.displayName,
    this.username,
    this.bio,
    this.phoneNumber,
    this.photoURL,
    this.isOnline = false,
    this.lastSeen,
    this.blockedUsers = const [],
    this.contacts = const [],
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      uid: id,
      displayName: map['displayName'] ?? 'مستخدم',
      username: map['username'],
      bio: map['bio'],
      phoneNumber: map['phoneNumber'],
      photoURL: map['photoURL'] ?? map['profilePick'],
      isOnline: map['isOnline'] ?? false,
      lastSeen: map['lastSeen'] != null
          ? (map['lastSeen'] as Timestamp).toDate()
          : null,
      blockedUsers: List<String>.from(map['blockedUsers'] ?? []),
      contacts: List<String>.from(map['contacts'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'username': username,
      'bio': bio,
      'phoneNumber': phoneNumber,
      'photoURL': photoURL,
      'isOnline': isOnline,
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
      'blockedUsers': blockedUsers,
      'contacts': contacts,
    };
  }

  UserModel copyWith({
    String? uid,
    String? displayName,
    String? username,
    String? bio,
    String? phoneNumber,
    String? photoURL,
    bool? isOnline,
    DateTime? lastSeen,
    List<String>? blockedUsers,
    List<String>? contacts,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoURL: photoURL ?? this.photoURL,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      contacts: contacts ?? this.contacts,
    );
  }
}
