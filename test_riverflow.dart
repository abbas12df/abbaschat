import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const apiKey = String.fromEnvironment(
    'OPENROUTER_IMAGE_API_KEY',
    defaultValue: String.fromEnvironment(
      'OPENROUTER_API_KEY',
      defaultValue: '',
    ),
  );
  const baseUrl = 'https://openrouter.ai/api/v1';
  const model = 'sourceful/riverflow-v2-pro';

  if (apiKey.isEmpty) {
    print('Missing OPENROUTER_IMAGE_API_KEY (or OPENROUTER_API_KEY).');
    return;
  }

  print('Testing $model ...');

  try {
    final response = await http.post(
      Uri.parse('$baseUrl/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
        'HTTP-Referer': 'https://test.com',
        'X-Title': 'Test Script',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'user', 'content': 'Generate a cute cat'},
        ],
      }),
    );

    print('Status Code: ${response.statusCode}');
    print('Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      try {
        final message = data['choices'][0]['message'];
        if (message.containsKey('images')) {
          print('Found images array: ${message['images']}');
        } else {
          print('No custom "images" field in message.');
        }
        print('Content: ${message['content']}');
      } catch (e) {
        print('Parsing error: $e');
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
