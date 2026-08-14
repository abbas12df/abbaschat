import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/open_ai_service.dart';

class AiState {
  final List<Map<String, String>> messages;
  final bool isLoading;
  final String? error;

  AiState({this.messages = const [], this.isLoading = false, this.error});

  AiState copyWith({
    List<Map<String, String>>? messages,
    bool? isLoading,
    String? error,
  }) {
    return AiState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AiNotifier extends StateNotifier<AiState> {
  final OpenAiService _service;

  AiNotifier(this._service) : super(AiState());

  Future<void> sendMessage(String prompt, {String? imagePath}) async {
    if (prompt.trim().isEmpty && imagePath == null) return;

    // Add user message immediately
    state = state.copyWith(
      messages: [
        ...state.messages,
        {
          'role': 'user',
          'content': prompt,
          if (imagePath != null) 'image': imagePath,
        },
      ],
      isLoading: true,
      error: null,
    );

    try {
      final response = await _service.sendMessage(prompt, imagePath: imagePath);

      // Add AI response
      state = state.copyWith(
        messages: [
          ...state.messages,
          {'role': 'assistant', 'content': response},
        ],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final openAiServiceProvider = Provider((ref) => OpenAiService());

final aiProvider = StateNotifierProvider<AiNotifier, AiState>((ref) {
  final service = ref.watch(openAiServiceProvider);
  return AiNotifier(service);
});
