import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const apiKey = String.fromEnvironment(
    'OPENROUTER_QWEN_API_KEY',
    defaultValue: String.fromEnvironment(
      'OPENROUTER_API_KEY',
      defaultValue: '',
    ),
  );
  const model = 'qwen/qwen3-next-80b-a3b-instruct:free';

  if (apiKey.isEmpty) {
    print('Missing OPENROUTER_QWEN_API_KEY (or OPENROUTER_API_KEY).');
    return;
  }

  print('Testing Qwen Model: $model ...');

  try {
    final response = await http.post(
      Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'user', 'content': 'Hello, who are you?'},
        ],
      }),
    );

    print('Status: ${response.statusCode}');
    print('Body: ${response.body}');
  } catch (e) {
    print('Error: $e');
  }
}
