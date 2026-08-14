import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';

class FullScreenImageScreen extends StatelessWidget {
  final String imageUrl;

  const FullScreenImageScreen({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4,
          child: _buildImage(),
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (imageUrl.startsWith('http')) {
      return Image.network(imageUrl);
    } else if (imageUrl.startsWith('/') || imageUrl.startsWith('file://')) {
      return Image.file(File(imageUrl));
    } else {
      return Image.memory(base64Decode(imageUrl));
    }
  }
}
