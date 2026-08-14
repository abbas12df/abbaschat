import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const apiKey = String.fromEnvironment('OPENROUTER_API_KEY', defaultValue: '');
  if (apiKey.isEmpty) {
    print(
      'Missing OPENROUTER_API_KEY. Run with --dart-define=OPENROUTER_API_KEY=...',
    );
    return;
  }

  print('Fetching valid models...');
  try {
    final response = await http.get(
      Uri.parse('https://openrouter.ai/api/v1/models'),
      headers: {'Authorization': 'Bearer $apiKey'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> models = data['data'];
      print('Found ${models.length} models.');

      final sourcefulModels = models.where((m) {
        final id = m['id'].toString().toLowerCase();
        return id.contains('sourceful') || id.contains('riverflow');
      }).toList();

      if (sourcefulModels.isNotEmpty) {
        print('--- Sourceful/Riverflow Models ---');
        for (var m in sourcefulModels) {
          print('${m['id']} - ${m['name']}');
        }
      } else {
        print('No "sourceful" or "riverflow" models found.');
      }

      print('--- Google Models ---');
      final googleModels = models
          .where((m) {
            return m['id'].toString().toLowerCase().contains('google/gemini');
          })
          .take(5)
          .toList();
      for (var m in googleModels) {
        print('${m['id']}');
      }
    } else {
      print('Failed to list models: ${response.statusCode}');
      print(response.body);
    }
  } catch (e) {
    print('Error: $e');
  }
}
