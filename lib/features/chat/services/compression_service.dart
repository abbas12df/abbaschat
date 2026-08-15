import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class CompressionService {
  /// Compresses an image if it exceeds [maxFileSizeMb].
  /// Returns the path to the compressed image, or the original path if no compression was needed.
  static Future<String> compressImageIfNeeded(String imagePath, {double maxFileSizeMb = 5.0}) async {
    final file = File(imagePath);
    if (!await file.exists()) return imagePath;

    final sizeInBytes = await file.length();
    final sizeInMb = sizeInBytes / (1024 * 1024);

    if (sizeInMb <= maxFileSizeMb) {
      return imagePath; // No compression needed
    }

    debugPrint('DEBUG: Compressing image. Original size: ${sizeInMb.toStringAsFixed(2)} MB');

    try {
      final dir = await getTemporaryDirectory();
      final targetPath = '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // We use flutter_image_compress for high performance native compression
      final result = await FlutterImageCompress.compressAndGetFile(
        imagePath,
        targetPath,
        quality: 70, // 70% quality is a good balance for chat images
        minWidth: 1920,
        minHeight: 1080,
      );

      if (result != null) {
        final newSize = await result.length();
        debugPrint('DEBUG: Image compressed. New size: ${(newSize / (1024 * 1024)).toStringAsFixed(2)} MB');
        return result.path;
      }
    } catch (e) {
      debugPrint('DEBUG: Error compressing image: $e');
    }

    return imagePath; // Fallback to original if compression fails
  }
}
