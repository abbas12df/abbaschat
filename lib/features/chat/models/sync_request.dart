class SyncRequest {
  final String id;
  final String requesterId;
  final String requesterPublicKey;
  final int timestamp;
  final String? lastKnownMessageId;

  SyncRequest({
    required this.id,
    required this.requesterId,
    required this.requesterPublicKey,
    required this.timestamp,
    this.lastKnownMessageId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'requesterId': requesterId,
      'requesterPublicKey': requesterPublicKey,
      'timestamp': timestamp,
      'lastKnownMessageId': lastKnownMessageId,
    };
  }

  factory SyncRequest.fromMap(Map<String, dynamic> map) {
    return SyncRequest(
      id: map['id'] ?? '',
      requesterId: map['requesterId'] ?? '',
      requesterPublicKey: map['requesterPublicKey'] ?? '',
      timestamp: map['timestamp'] ?? 0,
      lastKnownMessageId: map['lastKnownMessageId'],
    );
  }
}
