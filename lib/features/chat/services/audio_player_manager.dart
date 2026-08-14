import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Global provider for the single audio player manager
final audioPlayerManagerProvider = Provider<AudioPlayerManager>((ref) {
  final manager = AudioPlayerManager();
  ref.onDispose(() => manager.dispose());
  return manager;
});

// Provider that individual bubbles can watch to see if THEY are the one playing
final currentPlayingUrlProvider = StateProvider<String?>((ref) => null);

class AudioPlayerManager {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Expose stream for UI updates
  Stream<Duration> get onPositionChanged => _audioPlayer.onPositionChanged;
  Stream<Duration> get onDurationChanged => _audioPlayer.onDurationChanged;
  Stream<void> get onPlayerComplete => _audioPlayer.onPlayerComplete;
  Stream<PlayerState> get onPlayerStateChanged =>
      _audioPlayer.onPlayerStateChanged;

  Future<void> playUrl(String url) async {
    try {
      await _audioPlayer.stop(); // Stop any previous playback

      final source = url.startsWith('/')
          ? DeviceFileSource(url)
          : UrlSource(url);

      await _audioPlayer.play(source);
    } catch (e) {
      print('Error playing audio: $e');
    }
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
