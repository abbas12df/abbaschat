import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const key2 = String.fromEnvironment('OPENROUTER_API_KEY', defaultValue: '');
  const key3 = String.fromEnvironment(
    'OPENROUTER_IMAGE_API_KEY',
    defaultValue: String.fromEnvironment(
      'OPENROUTER_API_KEY',
      defaultValue: '',
    ),
  );

  if (key2.isEmpty || key3.isEmpty) {
    print('Missing OPENROUTER_API_KEY / OPENROUTER_IMAGE_API_KEY.');
    return;
  }

  const riverflow = 'sourceful/riverflow-v2-pro';
  const google = 'google/gemini-2.5-flash-image';

  print('--- Testing Scenario A: Key 2 + Riverflow ---');
  await test(key2, riverflow);

  print('\n--- Testing Scenario B: Key 3 + Google ---');
  await test(key3, google);
}

Future<void> test(String key, String model) async {
  try {
    final response = await http.post(
      Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $key',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'user', 'content': 'Test'},
        ],
      }),
    );
    print('Status: ${response.statusCode}');
    if (response.statusCode != 200) {
      print('Error: ${response.body}');
    } else {
      print('Success!');
    }
  } catch (e) {
    print('Exception: $e');
  }
}
