import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../services/audio_player_manager.dart';

class VoiceMessagePlayer extends ConsumerStatefulWidget {
  final String audioUrl;
  final Duration? duration;
  final bool isMe;

  const VoiceMessagePlayer({
    super.key,
    required this.audioUrl,
    this.duration,
    required this.isMe,
  });

  @override
  ConsumerState<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends ConsumerState<VoiceMessagePlayer> {
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  // Subscriptions to the centralized manager
  StreamSubscription? _positionSubscription;
  StreamSubscription? _stateSubscription;
  StreamSubscription? _completeSubscription;
  StreamSubscription? _durationSubscription;

  @override
  void initState() {
    super.initState();
    // Default duration from metadata if available
    if (widget.duration != null) {
      _totalDuration = widget.duration!;
    }
  }

  void _subscribeToManager(AudioPlayerManager manager) {
    // 1. Position Stream
    _positionSubscription = manager.onPositionChanged.listen((pos) {
      if (mounted && _isPlaying) {
        setState(() => _currentPosition = pos);
      }
    });

    // 3. Completion
    _completeSubscription = manager.onPlayerComplete.listen((_) {
      if (mounted && _isPlaying) {
        setState(() {
          _isPlaying = false;
          _currentPosition = Duration.zero;
        });
        // Also update global provider to null
        ref.read(currentPlayingUrlProvider.notifier).state = null;
      }
    });

    // 4. Duration (Only relevant if we are playing)
    _durationSubscription = manager.onDurationChanged.listen((d) {
      if (mounted && _isPlaying) {
        setState(() => _totalDuration = d);
      }
    });
  }

  void _unsubscribe() {
    _positionSubscription?.cancel();
    _stateSubscription?.cancel();
    _completeSubscription?.cancel();
    _durationSubscription?.cancel();
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final manager = ref.read(audioPlayerManagerProvider);

    if (_isPlaying) {
      // Pause
      await manager.pause();
      ref.read(currentPlayingUrlProvider.notifier).state = null;
      setState(() => _isPlaying = false);
      _unsubscribe();
    } else {
      // If someone else is active, they will stop themselves via the listener below

      // 1. Set global state
      ref.read(currentPlayingUrlProvider.notifier).state = widget.audioUrl;

      // 2. Play
      _subscribeToManager(manager); // Start listening to events
      await manager.playUrl(widget.audioUrl);

      setState(() => _isPlaying = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch global state to see if *I* am the one playing
    final playingUrl = ref.watch(currentPlayingUrlProvider);

    // Logic: If global playing URL is NOT me, and I was playing, stop.
    if (playingUrl != widget.audioUrl && _isPlaying) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _currentPosition = Duration.zero;
          });
          _unsubscribe();
        }
      });
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: const BoxConstraints(maxWidth: 250, minWidth: 180),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPlayButton(),
          const SizedBox(width: 8),
          Expanded(child: _buildWaveform()),
          const SizedBox(width: 8),
          _buildDuration(),
        ],
      ),
    );
  }

  Widget _buildPlayButton() {
    return GestureDetector(
      onTap: _togglePlay,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: widget.isMe
              ? Colors.white.withValues(alpha: 0.3)
              : Colors.blue.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(
          _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: widget.isMe ? Colors.white : Colors.blue,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildWaveform() {
    final progress = _totalDuration.inMilliseconds > 0
        ? _currentPosition.inMilliseconds / _totalDuration.inMilliseconds
        : 0.0;

    return SizedBox(
      height: 24,
      child: CustomPaint(
        painter: WaveformPainter(
          progress: progress.clamp(0.0, 1.0),
          color: widget.isMe ? Colors.white : Colors.blue,
          activeColor: widget.isMe ? Colors.white : Colors.blue[700]!,
        ),
      ),
    );
  }

  Widget _buildDuration() {
    final displayDuration = _isPlaying ? _currentPosition : _totalDuration;

    return Text(
      _formatDuration(displayDuration),
      style: TextStyle(
        fontSize: 11,
        fontFamily: 'monospace',
        color: widget.isMe ? Colors.white70 : Colors.black54,
        decoration: TextDecoration.none, // Fix for implicit text defaults
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d == Duration.zero) return "0:00";
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "${d.inMinutes}:$twoDigitSeconds";
  }
}

class WaveformPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color activeColor;

  WaveformPainter({
    required this.progress,
    required this.color,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final inactivePaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = activeColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Generate waveform bars (20 bars)
    const barCount = 20;
    final barWidth = size.width / barCount;

    // Predefined heights for aesthetic waveform
    const heights = [
      0.3,
      0.7,
      0.5,
      0.9,
      0.6,
      0.4,
      0.8,
      0.5,
      0.7,
      0.6,
      0.4,
      0.8,
      0.6,
      0.5,
      0.9,
      0.4,
      0.7,
      0.5,
      0.6,
      0.8,
    ];

    for (int i = 0; i < barCount; i++) {
      final x = i * barWidth + barWidth / 2;
      final height = size.height * heights[i % heights.length];
      final isActive = (i / barCount) < progress;

      canvas.drawLine(
        Offset(x, size.height / 2 - height / 2),
        Offset(x, size.height / 2 + height / 2),
        isActive ? activePaint : inactivePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
