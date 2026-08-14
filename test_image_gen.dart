import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const apiKey = String.fromEnvironment('OPENROUTER_API_KEY', defaultValue: '');
  if (apiKey.isEmpty) {
    print('Missing OPENROUTER_API_KEY.');
    return;
  }

  print('Testing image generation...');

  try {
    final modelsResponse = await http.get(
      Uri.parse('https://openrouter.ai/api/v1/models'),
      headers: {'Authorization': 'Bearer $apiKey'},
    );

    if (modelsResponse.statusCode == 200) {
      final modelsData = jsonDecode(modelsResponse.body);
      final models = modelsData['data'] as List;

      final candidates = models.where((m) {
        final id = m['id'].toString().toLowerCase();
        return id.contains('qwen') && id.contains('free');
      }).toList();

      if (candidates.isNotEmpty) {
        print('--- Candidate Models ---');
        for (var m in candidates) {
          print('${m['id']}');
        }
      } else {
        print('No free Qwen models found.');
      }
    } else {
      print(
        'Failed to fetch models. Status Code: ${modelsResponse.statusCode}',
      );
      print('Body: ${modelsResponse.body}');
    }

    final response = await http.post(
      Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'google/gemini-2.5-flash-image',
        'messages': [
          {'role': 'user', 'content': 'Generate a cute cat'},
        ],
      }),
    );

    print('Status Code: ${response.statusCode}');
    print('Body: ${response.body}');
  } catch (e) {
    print('Error: $e');
  }
}
