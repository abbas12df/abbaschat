import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/config/ai_config.dart';

class QwenService {
  // List of models to try in order (Primary -> Fallbacks)
  static const List<String> _models = [
    'qwen/qwen3-next-80b-a3b-instruct:free',
    'qwen/qwen2.5-72b-instruct',
    'qwen/qwen2.5-vl-72b-instruct:free',
    'qwen/qwen3-4b:free',
  ];

  Future<String> sendMessage(String prompt, {String? imagePath}) async {
    if (AiConfig.qwenApiKey.isEmpty) {
      throw Exception(
        'OPENROUTER_QWEN_API_KEY is missing. Configure it with --dart-define.',
      );
    }

    const maxRetries = 3;

    for (var model in _models) {
      for (int attempt = 0; attempt < maxRetries; attempt++) {
        try {
          return await _attemptSend(model, prompt, imagePath);
        } catch (e) {
          debugPrint('Attempt ${attempt + 1} for $model failed: $e');
          if (e.toString().contains('429') ||
              e.toString().contains('Rate limit')) {
            await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
            continue;
          }
          break;
        }
      }
    }

    throw Exception(
      'All Qwen models are currently unavailable. Try again later.',
    );
  }

  Future<String> _attemptSend(
    String modelId,
    String prompt,
    String? imagePath,
  ) async {
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
              'text': prompt.isEmpty ? 'Describe this image' : prompt,
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
        'Authorization': 'Bearer ${AiConfig.qwenApiKey}',
        'HTTP-Referer': AiConfig.referer,
        'X-Title': 'Nisaba Qwen',
      },
      body: jsonEncode({'model': modelId, 'messages': messagesPayload}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'].toString();
    } else if (response.statusCode == 429) {
      throw Exception('Rate limit (429)');
    } else {
      throw Exception('${response.statusCode}');
    }
  }
}
