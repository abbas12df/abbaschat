class AiConfig {
  // Pass with: --dart-define=OPENROUTER_API_KEY=...
  static const String apiKey = String.fromEnvironment(
    'OPENROUTER_API_KEY',
    defaultValue: '',
  );
  static const String qwenApiKey = String.fromEnvironment(
    'OPENROUTER_QWEN_API_KEY',
    defaultValue: apiKey,
  );
  static const String imageApiKey = String.fromEnvironment(
    'OPENROUTER_IMAGE_API_KEY',
    defaultValue: apiKey,
  );
  static const String referer = String.fromEnvironment(
    'OPENROUTER_HTTP_REFERER',
    defaultValue: 'https://your-app-domain.com',
  );
  static const String baseUrl = 'https://openrouter.ai/api/v1';
  static const String defaultModel =
      'google/gemini-2.0-flash-001'; // Confirmed working
}
