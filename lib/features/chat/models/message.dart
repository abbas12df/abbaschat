import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String senderId;
  final String text;
  final String? imageUrl;
  final String? audioUrl; // Added nullable audioUrl
  final String? fileUrl; // For generic files
  final String? fileName; // User friendly file name
  final int? fileSize; // Total size in bytes
  final double? transferProgress; // 0.0 to 1.0
  final String? fileId; // ID for chunked transfers
  final DateTime timestamp;
  final bool isRead;
  final String type; // 'text', 'image', 'audio', 'file', 'system'
  final String? replyToId;
  final Map<String, dynamic>? replySnapshot; // Snapshot of the replied message
  final Map<String, String>? reactions;
  final bool isEdited;
  final bool isSystemMessage; // For system messages (joins, leaves, etc.)

  final MessageStatus status;

  Message({
    required this.id,
    required this.senderId,
    required this.text,
    this.imageUrl,
    this.audioUrl,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.transferProgress,
    this.fileId,
    required this.timestamp,
    this.isRead = false,
    this.type = 'text',
    this.replyToId,
    this.replySnapshot,
    this.reactions,
    this.isEdited = false,
    this.isSystemMessage = false,
    this.readBy = const [],
    this.status = MessageStatus
        .sent, // Default to sent for backward compatibility, new ones will be sending
  });

  final List<String> readBy;

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'transferProgress': transferProgress,
      'fileId': fileId,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'type': type,
      'replyToId': replyToId,
      'replySnapshot': replySnapshot,
      'reactions': reactions,
      'isEdited': isEdited,
      'isSystemMessage': isSystemMessage,
      'readBy': readBy,
      'status': status.name,
    };
  }

  factory Message.fromMap(String id, Map<String, dynamic> map) {
    dynamic tsData = map['timestamp'];
    DateTime timestamp;

    if (tsData is Timestamp) {
      timestamp = tsData.toDate();
    } else if (tsData is String) {
      timestamp = DateTime.tryParse(tsData) ?? DateTime.now();
    } else if (tsData is int) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(tsData);
    } else {
      timestamp = DateTime.now();
    }

    // Safe reactions parsing
    Map<String, String>? parsedReactions;
    final reactionsData = map['reactions'];
    if (reactionsData != null && reactionsData is Map) {
      parsedReactions = {};
      reactionsData.forEach((key, value) {
        parsedReactions![key.toString()] = value.toString();
      });
    }

    // DEBUG: Log imageUrl for images
    final imageUrlValue = map['imageUrl'];
    if (map['type'] == 'image') {
      print(
        'DEBUG: Message.fromMap - id=$id, type=image, imageUrl=$imageUrlValue',
      );
    }

    return Message(
      id: id,
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      imageUrl: imageUrlValue,
      audioUrl: map['audioUrl'],
      fileUrl: map['fileUrl'],
      fileName: map['fileName'],
      fileSize: map['fileSize'],
      transferProgress: (map['transferProgress'] is num)
          ? (map['transferProgress'] as num).toDouble()
          : null,
      fileId: map['fileId'],
      timestamp: timestamp,
      isRead: map['isRead'] ?? false,
      type: map['type'] ?? 'text',
      replyToId: map['replyToId'],
      replySnapshot: map['replySnapshot'] != null
          ? Map<String, dynamic>.from(map['replySnapshot'])
          : null,
      reactions: parsedReactions,
      isEdited: map['isEdited'] ?? false,
      isSystemMessage: map['isSystemMessage'] ?? false,
      readBy: List<String>.from(map['readBy'] ?? []),
      status: MessageStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'sent'),
        orElse: () => MessageStatus.sent,
      ),
    );
  }
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
  receiving,
  requesting_resync,
  permanently_lost
}
