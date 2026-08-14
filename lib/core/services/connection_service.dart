import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ConnectionStatus { online, offline, connecting }

final connectionStatusProvider = StreamProvider<ConnectionStatus>((ref) {
  return ConnectionService().status;
});

class ConnectionService {
  final Connectivity _connectivity = Connectivity();
  final _controller = StreamController<ConnectionStatus>.broadcast();

  Stream<ConnectionStatus> get status => _controller.stream;

  ConnectionService() {
    // Initial check
    _checkStatus();

    // Listen to changes
    _connectivity.onConnectivityChanged.listen((results) {
      _updateStatus(results);
    });
  }

  Future<void> _checkStatus() async {
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.none)) {
      _controller.add(ConnectionStatus.offline);
    } else {
      // We have a network interface, we assume we are connecting/online
      // Ideally we would ping google.com, but for UI responsiveness
      // "Online" simply means we have a radio connection.
      _controller.add(ConnectionStatus.online);
    }
  }
}
