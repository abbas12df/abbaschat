import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../security/secure_service_account.dart';

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  AutoRefreshingAuthClient? _client;
  final List<String> _scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

  /// SECURE PATH: server-side Cloud Function.
  /// The service account lives only on Google's servers — nothing secret in the app.
  Future<bool> _sendViaCloudFunction({
    required String targetToken,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('sendPushNotification');
      // Serialize the data payload to strings only (Cloud Functions requirement).
      final stringData = data.map((k, v) => MapEntry(k, v?.toString() ?? ''));
      await callable.call(<String, dynamic>{
        'targetToken': targetToken,
        'title': title,
        'body': body,
        'data': stringData,
      });
      debugPrint('Push notification sent via Cloud Function.');
      return true;
    } catch (e) {
      debugPrint('Cloud Function push failed (falling back to legacy): $e');
      return false;
    }
  }

  Future<void> init() async {
    if (_client != null) return;
    try {
      final jsonString = SecureServiceAccount.getDecryptedJson();
      final accountCredentials = ServiceAccountCredentials.fromJson(jsonString);
      
      _client = await clientViaServiceAccount(accountCredentials, _scopes);
      debugPrint('PushNotificationService initialized successfully.');
    } catch (e) {
      debugPrint('Failed to initialize PushNotificationService: $e');
    }
  }

  Future<void> sendPushMessage({
    required String targetToken,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    // 1. Preferred secure path: Cloud Function (service account is server-side).
    final sentSecurely = await _sendViaCloudFunction(
      targetToken: targetToken,
      title: title,
      body: body,
      data: data,
    );
    if (sentSecurely) return;

    // 2. LEGACY FALLBACK (transitional): direct FCM with embedded credentials.
    //    Remove SecureServiceAccount + this path once the function is deployed.
    if (_client == null) {
      await init();
    }
    
    if (_client == null) {
      debugPrint('Cannot send push notification, client is not initialized.');
      return;
    }

    final projectId = Firebase.app().options.projectId;
    final endpoint = 'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

    final message = {
      'message': {
        'token': targetToken,
        'notification': {
          'title': title,
          'body': body,
        },
        'data': {
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          ...data,
        },
        'android': {
          'priority': 'high',
          'notification': {
            'channel_id': 'high_importance_channel',
            'sound': 'default',
          }
        },
        'apns': {
          'payload': {
            'aps': {
              'sound': 'default',
              'badge': 1,
            }
          }
        }
      }
    };

    try {
      final response = await _client!.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(message),
      );

      if (response.statusCode == 200) {
        debugPrint('Push notification sent successfully');
      } else {
        debugPrint('Failed to send push notification: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error sending push notification: $e');
    }
  }
}
