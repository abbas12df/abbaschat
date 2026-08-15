enum UploadStatus {
  queued,
  preparing,
  compressing,
  encrypting,
  uploading,
  sent,
  failed,
  cancelled
}

class CancelToken {
  bool isCancelled = false;

  void cancel() {
    isCancelled = true;
  }
}

class UploadProgress {
  final String fileId;
  final int sentBytes;
  final int totalBytes;
  final UploadStatus status;
  final double speed; // Bytes per second
  final CancelToken cancelToken;
  final String? error;

  UploadProgress({
    required this.fileId,
    required this.sentBytes,
    required this.totalBytes,
    required this.status,
    required this.cancelToken,
    this.speed = 0.0,
    this.error,
  });

  double get progress => totalBytes > 0 ? sentBytes / totalBytes : 0.0;

  UploadProgress copyWith({
    int? sentBytes,
    int? totalBytes,
    UploadStatus? status,
    double? speed,
    String? error,
  }) {
    return UploadProgress(
      fileId: fileId,
      sentBytes: sentBytes ?? this.sentBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      status: status ?? this.status,
      speed: speed ?? this.speed,
      cancelToken: cancelToken, // Keep the same reference
      error: error ?? this.error,
    );
  }
}
