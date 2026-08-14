import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/qwen_service.dart';

class QwenState {
  final List<Map<String, String>> messages;
  final bool isLoading;
  final String? error;

  QwenState({this.messages = const [], this.isLoading = false, this.error});

  QwenState copyWith({
    List<Map<String, String>>? messages,
    bool? isLoading,
    String? error,
  }) {
    return QwenState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class QwenNotifier extends StateNotifier<QwenState> {
  final QwenService _service;

  QwenNotifier(this._service) : super(QwenState());

  Future<void> sendMessage(String prompt, {String? imagePath}) async {
    if (prompt.trim().isEmpty && imagePath == null) return;

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

  void clearChat() {
    state = QwenState();
  }
}

final qwenServiceProvider = Provider((ref) => QwenService());

final qwenProvider = StateNotifierProvider<QwenNotifier, QwenState>((ref) {
  final service = ref.watch(qwenServiceProvider);
  return QwenNotifier(service);
});
