import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'biometric_service.dart';
import '../../features/settings/services/settings_service.dart';

class AppLockManager extends ConsumerStatefulWidget {
  final Widget child;
  const AppLockManager({super.key, required this.child});

  @override
  ConsumerState<AppLockManager> createState() => _AppLockManagerState();
}

class _AppLockManagerState extends ConsumerState<AppLockManager>
    with WidgetsBindingObserver {
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // FIX: Lock on Cold Start (Initial Launch)
    // We defer reading the provider slightly to ensure safety, or read directly.
    // Reading in initState is generally safe for sync providers.
    final settings = ref.read(settingsServiceProvider);
    if (settings.appLock) {
      _isLocked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _promptBiometrics(ignoreLockState: true);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  DateTime? _pausedTime;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pausedTime ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final settings = ref.read(settingsServiceProvider);
      if (settings.appLock && _pausedTime != null) {
        final elapsedSeconds =
            DateTime.now().difference(_pausedTime!).inSeconds;
        // autoLockTimeout: 0 = immediately, 30 = 30s, 60 = 1m, 300 = 5m
        if (elapsedSeconds >= settings.autoLockTimeout) {
          _promptBiometrics();
        }
      }
      _pausedTime = null;
    }
  }

  Future<void> _promptBiometrics({bool ignoreLockState = false}) async {
    // Prevent multiple overlays
    if (_isLocked && !ignoreLockState) return;

    if (!_isLocked && mounted) {
      setState(() => _isLocked = true);
    }

    // Show Covering Screen or just prompt?
    // A covering screen is safer to hide content.
    // For now, we instantly verify.

    final bio = ref.read(biometricServiceProvider);
    bool didAuth = false;

    // Loop until auth is successful or user force closes?
    // Or just once? Usually loops.
    while (!didAuth) {
      didAuth = await bio.authenticate(
        localizedReason: 'مطلوب البصمة لفك القفل',
      );
      if (!didAuth) {
        // User cancelled or failed.
        // We must keep the app locked/blank.
        // Wait a bit before retrying?
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    if (mounted) {
      setState(() => _isLocked = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isLocked)
          Positioned.fill(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('التطبيق مقفل', style: TextStyle(fontSize: 20)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
