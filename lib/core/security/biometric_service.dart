import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Detailed check for biometric availability
  Future<Map<String, dynamic>> getBiometricStatus() async {
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isDeviceSupported = await _auth.isDeviceSupported();
      final List<BiometricType> availableBiometrics = await _auth
          .getAvailableBiometrics();

      return {
        'canCheckBiometrics': canCheck,
        'isDeviceSupported': isDeviceSupported,
        'availableBiometrics': availableBiometrics
            .map((e) => e.toString())
            .toList(),
        'isAvailable':
            (canCheck || isDeviceSupported) && availableBiometrics.isNotEmpty,
      };
    } on PlatformException catch (e) {
      return {'error': e.toString(), 'isAvailable': false};
    }
  }

  /// Check if the device is capable of biometric authentication
  Future<bool> get isBiometricsAvailable async {
    final status = await getBiometricStatus();
    return status['isAvailable'] == true;
  }

  /// Authenticate the user
  Future<bool> authenticate({required String localizedReason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow PIN/Pattern as fallback
        ),
      );
    } on PlatformException catch (e) {
      print('Auth Error: $e');
      return false;
    }
  }
}
