import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EnhancedImageViewer extends StatelessWidget {
  final String imageUrl;
  final String heroTag;
  final VoidCallback? onSave;

  const EnhancedImageViewer({
    super.key,
    required this.imageUrl,
    required this.heroTag,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          if (onSave != null)
            IconButton(
              icon: const Icon(Icons.download_rounded),
              onPressed: onSave,
              tooltip: 'حفظ الصورة',
            ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: Hero(tag: heroTag, child: _buildImage()),
        ),
      ),
    );
  }

  Widget _buildImage() {
    // Handle different image source types
    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;

          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!
                      : null,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                Text(
                  'جاري التحميل...',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(),
      );
    } else if (imageUrl.startsWith('/') || imageUrl.startsWith('file://')) {
      // Local file path
      final path = imageUrl.startsWith('file://')
          ? imageUrl.substring(7)
          : imageUrl;

      return Image.file(
        File(path),
        errorBuilder: (_, __, ___) => _buildErrorPlaceholder(),
      );
    } else {
      // Base64 encoded image
      try {
        return Image.memory(
          base64Decode(imageUrl),
          errorBuilder: (_, __, ___) => _buildErrorPlaceholder(),
        );
      } catch (e) {
        return _buildErrorPlaceholder();
      }
    }
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_rounded, size: 64, color: Colors.white30),
          SizedBox(height: 8),
          Text('فشل تحميل الصورة', style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }
}
