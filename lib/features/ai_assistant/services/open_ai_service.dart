import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../core/config/ai_config.dart';

class OpenAiService {
  Future<String> sendMessage(String prompt, {String? imagePath}) async {
    try {
      if (AiConfig.apiKey.isEmpty) {
        throw Exception(
          'OPENROUTER_API_KEY is missing. Configure it with --dart-define.',
        );
      }

      final List<Map<String, dynamic>> messagesPayload = [];

      if (imagePath != null) {
        final File imageFile = File(imagePath);
        if (await imageFile.exists()) {
          final bytes = await imageFile.readAsBytes();
          final base64Image = base64Encode(bytes);

          messagesPayload.add({
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text': prompt.isEmpty ? 'Analyze this image' : prompt,
              },
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
              },
            ],
          });
        }
      } else {
        messagesPayload.add({'role': 'user', 'content': prompt});
      }

      final response = await http.post(
        Uri.parse('${AiConfig.baseUrl}/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AiConfig.apiKey}',
          'HTTP-Referer': AiConfig.referer,
          'X-Title': 'Nisaba Chat',
        },
        body: jsonEncode({
          'model': AiConfig.defaultModel,
          'messages': messagesPayload,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].toString();
      } else {
        throw Exception(
          'Failed to load AI response: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error sending message to AI: $e');
    }
  }
}
