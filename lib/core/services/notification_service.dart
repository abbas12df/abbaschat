import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Background Handler (Must be top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Need reference to SettingsService logic
  // (We'll pass settings dynamically in showNotification methods)

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // 1. Request Permissions
    await _requestPermission();

    // 2. Setup Local Notifications
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Handle notification tap
        debugPrint("Notification tapped with payload: ${response.payload}");
      },
    );

    // Explicitly create the channel for Android
    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          'high_importance_channel',
          'High Importance Notifications',
          importance: Importance.max,
          playSound: true,
        ),
      );

      // Request permission explicitly here too for Android 13+ local notifications
      await androidImplementation.requestNotificationsPermission();
    }

    // 3. Setup Background Handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 4. Foreground Message Handler
    // NOTE: We don't show notifications here directly.
    // Instead, we rely on NotificationWatcher which checks if user is in active chat.
    // This prevents notifications from showing when user is inside the chat room.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Foreground message received.');

      // Suppress notifications when in foreground - NotificationWatcher handles this
      // This prevents duplicate notifications and ensures proper activeRoomId checking
      debugPrint(
        'Foreground message received - NotificationWatcher will handle notification display',
      );
    });

    _isInitialized = true;
  }

  Future<void> _requestPermission() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('User granted permission: ${settings.authorizationStatus}');
  }

  // Public method to show notification manually (for Local Listener)
  Future<void> showNotification(
    String title,
    String body, {
    bool sound = true,
    bool vibrate = true,
  }) async {
    // Note: We are relying on high_importance_channel configuration.
    // To truly dynmaically toggle sound/vibrate per notification on Android,
    // we would need multiple channels or update the channel configuration.
    // For simplicity, we'll keep the channel as is (max importance)
    // but we can choose NOT to show the notification if 'notificationsEnabled' is false
    // at the call site (Watcher).

    // HOWEVER, for sound/vibrate control, Android channels are rigid.
    // We can use 'playSound: false' in AndroidNotificationDetails details.

    final androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: sound,
      enableVibration: vibrate,
    );
    final notificationDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecond, // Unique ID
      title,
      body,
      notificationDetails,
    );
  }

  // Get and Save Token
  Future<void> saveTokenToDatabase() async {
    String? token = await _firebaseMessaging.getToken();
    if (token == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'fcmToken': token},
      );
      debugPrint('FCM token saved.');
    }

    // Listen for token refreshes
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': newToken});
        debugPrint('FCM token refreshed and saved.');
      }
    });
  }
}
