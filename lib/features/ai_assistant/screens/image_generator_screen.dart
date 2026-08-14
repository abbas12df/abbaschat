import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/image_generation_service.dart';

final imageGenerationServiceProvider = Provider(
  (ref) => ImageGenerationService(),
);

class ImageGeneratorScreen extends ConsumerStatefulWidget {
  const ImageGeneratorScreen({super.key});

  @override
  ConsumerState<ImageGeneratorScreen> createState() =>
      _ImageGeneratorScreenState();
}

class _ImageGeneratorScreenState extends ConsumerState<ImageGeneratorScreen> {
  final TextEditingController _promptController = TextEditingController();
  bool _isLoading = false;
  String? _generatedContent;
  String? _error;

  void _generate() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _generatedContent = null;
    });

    try {
      final result = await ref
          .read(imageGenerationServiceProvider)
          .generateImage(prompt);
      setState(() {
        _generatedContent = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // Helper to extract image URL from markdown if present
  String? _extractImageUrl(String content) {
    // Regex for markdown image: ![alt](url)
    final RegExp exp = RegExp(r'!\[.*?\]\((.*?)\)');
    final match = exp.firstMatch(content);
    if (match != null) {
      return match.group(1);
    }
    // If raw URL
    if (content.startsWith('http')) return content;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _generatedContent != null
        ? _extractImageUrl(_generatedContent!)
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('مولد الصور (AI)')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _promptController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'وصف الصورة التي تريد إنشائها...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _generate,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.brush),
                label: Text(_isLoading ? 'جاري التوليد...' : 'تـوليـد صـورة'),
              ),
            ),
            const SizedBox(height: 24),

            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),

            if (_generatedContent != null) ...[
              if (imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    imageUrl,
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        height: 300,
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (ctx, err, stack) => Container(
                      height: 200,
                      color: Colors.grey[200],
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.broken_image,
                        size: 50,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ).animate().fadeIn().scale()
              else
                // If raw text returned without image pattern
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_generatedContent!),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
