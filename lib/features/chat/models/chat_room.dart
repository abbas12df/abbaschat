import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoom {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final DateTime lastMessageTime;
  final Map<String, int> unreadCounts;
  final bool isGroup;
  final String? groupName;
  final String? groupIcon;
  final String? description; // Added
  final List<String>? admins;
  final List<String> deletedBy;
  final bool isPublic; // New
  final bool onlyAdminsCanPost; // New
  final List<String> pendingRequests; // New
  final String? groupHandle; // New (@handle)
  final String? createdBy; // New: Owner ID
  final Map<String, List<String>>?
  adminPermissions; // New: {adminId: [perm1, perm2]}
  final bool isRemoteProtectionEnforced; // Enforced by peer
  final bool isOutgoingProtectionEnabled; // Requested by me
  final String? category; // Optional channel/category grouping
  final String? source; // Optional source/provider name

  ChatRoom({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCounts,
    this.isGroup = false,
    this.groupName,
    this.groupIcon,
    this.description,
    this.admins,
    this.deletedBy = const [],
    this.isPublic = false,
    this.onlyAdminsCanPost = false,
    this.pendingRequests = const [],
    this.groupHandle,
    this.createdBy,
    this.adminPermissions,
    this.isRemoteProtectionEnforced = false,
    this.isOutgoingProtectionEnabled = false,
    this.category,
    this.source,
  });

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime.millisecondsSinceEpoch,
      'unreadCounts': unreadCounts,
      'isGroup': isGroup,
      'groupName': groupName,
      'groupIcon': groupIcon,
      'description': description,
      'admins': admins,
      'deletedBy': deletedBy,
      'isPublic': isPublic,
      'onlyAdminsCanPost': onlyAdminsCanPost,
      'pendingRequests': pendingRequests,
      'groupHandle': groupHandle,
      'createdBy': createdBy,
      'adminPermissions': adminPermissions,
      'isRemoteProtectionEnforced': isRemoteProtectionEnforced,
      'isOutgoingProtectionEnabled': isOutgoingProtectionEnabled,
      'category': category,
      'source': source,
    };
  }

  factory ChatRoom.fromMap(String id, Map<String, dynamic> map) {
    return ChatRoom(
      id: id,
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTime: map['lastMessageTime'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['lastMessageTime'] as int)
          : (map['lastMessageTime'] is Timestamp
                ? (map['lastMessageTime'] as Timestamp).toDate()
                : DateTime.now()),
      unreadCounts:
          (map['unreadCounts'] as Map?)?.map(
            (key, value) => MapEntry(
              key.toString(),
              value is num ? value.toInt() : int.tryParse(value.toString()) ?? 0,
            ),
          ) ??
          {},
      isGroup: map['isGroup'] ?? id.startsWith('group_'),
      groupName: _pickString(map, const ['groupName', 'name', 'title']),
      groupIcon: _pickString(map, const ['groupIcon', 'icon', 'imageUrl']),
      description: _pickString(map, const ['description', 'desc']),
      admins: map['admins'] != null ? List<String>.from(map['admins']) : null,
      deletedBy: map['deletedBy'] != null
          ? List<String>.from(map['deletedBy'])
          : [],
      // New fields
      isPublic: map['isPublic'] ?? false,
      onlyAdminsCanPost: map['onlyAdminsCanPost'] ?? false,
      pendingRequests: map['pendingRequests'] != null
          ? List<String>.from(map['pendingRequests'])
          : [],
      groupHandle: _pickString(map, const ['groupHandle', 'handle']),
      createdBy: _pickString(map, const ['createdBy', 'ownerId']),
      adminPermissions: (map['adminPermissions'] as Map?)?.map(
        (key, value) =>
            MapEntry(key.toString(), List<String>.from(value ?? [])),
      ),
      isRemoteProtectionEnforced: map['isRemoteProtectionEnforced'] ?? false,
      isOutgoingProtectionEnabled: map['isOutgoingProtectionEnabled'] ?? false,
      category: _pickString(map, const [
        'category',
        'groupCategory',
        'channelCategory',
        'categoryName',
        'category_name',
        'section',
        'sectionName',
        'section_name',
      ]),
      source: _pickString(map, const [
        'source',
        'sourceName',
        'source_name',
        'provider',
        'providerName',
        'provider_name',
        'playlist',
      ]),
    );
  }

  static String? _pickString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = _normalizeString(map[key]);
      if (value != null) return value;
    }
    return null;
  }

  static String? _normalizeString(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is num || value is bool) {
      return value.toString();
    }
    if (value is Map) {
      return _normalizeString(
        value['name'] ?? value['title'] ?? value['label'] ?? value['id'],
      );
    }
    if (value is Iterable) {
      for (final item in value) {
        final normalized = _normalizeString(item);
        if (normalized != null) return normalized;
      }
    }
    return null;
  }
}
