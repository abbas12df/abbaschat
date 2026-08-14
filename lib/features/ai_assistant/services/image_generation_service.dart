import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config/ai_config.dart';

class ImageGenerationService {
  static const String _model = 'sourceful/riverflow-v2-pro';

  Future<String> generateImage(String prompt) async {
    try {
      if (AiConfig.imageApiKey.isEmpty) {
        throw Exception(
          'OPENROUTER_IMAGE_API_KEY is missing. Configure it with --dart-define.',
        );
      }

      final response = await http.post(
        Uri.parse('${AiConfig.baseUrl}/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AiConfig.imageApiKey}',
          'HTTP-Referer': AiConfig.referer,
          'X-Title': 'Nisaba Image Gen',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final message = data['choices'][0]['message'];

        if (message.containsKey('images') &&
            (message['images'] as List).isNotEmpty) {
          final images = message['images'] as List;
          final firstImage = images.first;
          if (firstImage.containsKey('image_url')) {
            return firstImage['image_url']['url'].toString();
          } else if (firstImage.containsKey('url')) {
            return firstImage['url'].toString();
          }
        }

        return message['content'].toString();
      } else {
        throw Exception(
          'Image generation failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Image generation request failed: $e');
    }
  }
}
