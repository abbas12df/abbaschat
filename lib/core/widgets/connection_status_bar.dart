import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ConnectionStatusBar extends StatefulWidget {
  const ConnectionStatusBar({super.key});

  @override
  State<ConnectionStatusBar> createState() => _ConnectionStatusBarState();
}

class _ConnectionStatusBarState extends State<ConnectionStatusBar> {
  late StreamSubscription<List<ConnectivityResult>> _subscription;
  Timer? _hideBannerTimer;
  bool _isConnected = true;
  bool _isChecking = true;
  bool _showBanner = false;

  @override
  void initState() {
    super.initState();
    // Check initial status
    _checkConnectivity();

    // Listen for changes
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      if (mounted) {
        _updateStatus(results);
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (mounted) {
      _updateStatus(results);
    }
  }

  void _updateStatus(List<ConnectivityResult> results) {
    // FIXED: Check mounted before any setState
    if (!mounted) return;

    // If any result is not none, we are connected (roughly)
    final hasConnection = !results.contains(ConnectivityResult.none);

    // Cancel any existing timer
    _hideBannerTimer?.cancel();

    if (hasConnection && !_isConnected) {
      // Transition: Offline -> Online
      setState(() {
        _isConnected = true;
        _showBanner = true; // Show "Connected" briefly
      });

      // Hide after 2 seconds
      _hideBannerTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _showBanner = false;
          });
        }
      });
    } else if (!hasConnection && _isConnected) {
      // Transition: Online -> Offline
      setState(() {
        _isConnected = false;
        _showBanner = true; // Show "Offline" continuously
      });
    } else if (!hasConnection) {
      // Already offline, ensure banner is separate
      setState(() => _showBanner = true);
    }

    if (mounted) {
      setState(() => _isChecking = false);
    }
  }

  @override
  void dispose() {
    // FIXED: Cancel timer and subscription before dispose
    _hideBannerTimer?.cancel();
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking && !_showBanner) return const SizedBox.shrink();

    return AnimatedSize(
      duration: 300.ms,
      child: _showBanner
          ? Container(
              width: double.infinity,
              color: _isConnected ? Colors.green : Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isConnected ? Icons.wifi : Icons.wifi_off,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isConnected
                        ? 'تم الاتصال بالإنترنت'
                        : 'لا يوجد اتصال بالإنترنت',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ).animate().fadeIn()
          : const SizedBox.shrink(),
    );
  }
}
