import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/chat/repositories/chat_repository.dart';

final deepLinkServiceProvider = Provider((ref) {
  // Get navigatorKey from main.dart (will be passed via override if needed)
  return DeepLinkService(ref);
});

/// Service to handle deep links for group joining
/// This is completely separate from the messaging/encryption system
class DeepLinkService {
  final Ref _ref;
  final AppLinks _appLinks = AppLinks();

  // Navigation key to navigate without context
  final GlobalKey<NavigatorState> navigatorKey;

  DeepLinkService(this._ref) : navigatorKey = GlobalKey<NavigatorState>();

  /// Initialize deep link handling
  /// Call this once in main.dart after app starts
  Future<void> initialize() async {
    print('DEBUG: DeepLinkService initializing...');

    try {
      // Handle initial link (app opened from link while closed)
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        print('DEBUG: Initial link detected: $initialLink');
        await _handleDeepLink(initialLink);
      }

      // Handle links while app is running
      _appLinks.uriLinkStream.listen(
        (uri) {
          print('DEBUG: Deep link received: $uri');
          _handleDeepLink(uri);
        },
        onError: (err) {
          print('ERROR: Deep link error: $err');
        },
      );

      print('DEBUG: DeepLinkService initialized successfully');
    } catch (e) {
      print('ERROR: Failed to initialize DeepLinkService: $e');
    }
  }

  /// Handle incoming deep link
  Future<void> _handleDeepLink(Uri uri) async {
    try {
      print('DEBUG: Processing deep link: $uri');
      print('  Scheme: ${uri.scheme}');
      print('  Host: ${uri.host}');
      print('  Path: ${uri.path}');
      print('  Segments: ${uri.pathSegments}');

      // Parse different link formats:
      // 1. https://qqqq.app/join/@handle
      // 2. qqqq://group/@handle

      String? handle;

      if (uri.scheme == 'https' && uri.host == 'qqqq.app') {
        // HTTPS link: https://qqqq.app/join/@handle
        if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'join') {
          handle = uri.pathSegments[1].replaceAll('@', '');
        }
      } else if (uri.scheme == 'qqqq' && uri.host == 'group') {
        // Custom scheme: qqqq://group/@handle
        if (uri.pathSegments.isNotEmpty) {
          handle = uri.pathSegments[0].replaceAll('@', '');
        }
      }

      if (handle != null && handle.isNotEmpty) {
        print('DEBUG: Extracted handle: $handle');
        await _joinGroupByHandle(handle);
      } else {
        print('WARNING: Could not extract handle from link: $uri');
      }
    } catch (e) {
      print('ERROR: Failed to handle deep link: $e');
    }
  }

  /// Join group by handle
  /// This uses the existing ChatRepository method (safe, no changes to encryption)
  Future<void> _joinGroupByHandle(String handle) async {
    try {
      print('DEBUG: Attempting to join group with handle: @$handle');

      // Use existing ChatRepository method
      // This is safe - it uses the existing join logic
      await _ref.read(chatRepositoryProvider).joinGroupByHandle(handle);

      print('DEBUG: Successfully joined group @$handle');

      // Show success message
      _showSnackBar('تم الانضمام إلى المجموعة بنجاح', isError: false);
    } catch (e) {
      print('ERROR: Failed to join group @$handle: $e');

      // Show error message
      String errorMessage = 'فشل الانضمام إلى المجموعة';
      if (e.toString().contains('المجموعة غير موجودة')) {
        errorMessage = 'المجموعة غير موجودة';
      } else if (e.toString().contains('خاصة')) {
        errorMessage = 'تم إرسال طلب الانضمام';
      }

      _showSnackBar(errorMessage, isError: e.toString().contains('فشل'));
    }
  }

  /// Show snackbar message (simplified - just print for now)
  void _showSnackBar(String message, {bool isError = false}) {
    // For now, just print the message
    // In a real app, you'd use a global scaffold messenger or overlay
    print(isError ? 'ERROR: $message' : 'SUCCESS: $message');
  }
}
