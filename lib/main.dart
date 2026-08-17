import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'core/theme/nisaba_theme.dart';
import 'features/auth/screens/auth_wrapper.dart';
import 'core/services/notification_service.dart';
import 'core/services/deep_link_service.dart';

import 'package:hive_flutter/hive_flutter.dart';
import 'core/local/local_storage_service.dart';
import 'core/security/crypto_service.dart';
import 'core/security/secure_storage_service.dart';
import 'features/settings/services/settings_service.dart';
import 'core/security/app_lock_manager.dart';

import 'core/security/screen_security_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint(
        'Firebase initialization failed (probably already exists): $e',
      );
    }
  }

  // Initialize Local Storage (Hive)
  final secureStorage = SecureStorageService();
  final localStorage = LocalStorageService(secureStorage);
  await localStorage.init();
  await Hive.openBox('global_app_settings');

  // Apply saved global screenshot protection
  await ScreenSecurityService.applyGlobalProtection();

  // Initialize Identity Keys (RSA)
  await CryptoService().initializeKeys();

  // Enable offline persistence (Firestore - Legacy, will be removed later or kept for other features)
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: 104857600, // 100 MB cache limit
  );

  await NotificationService().initialize();
  runApp(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(localStorage),
        secureStorageServiceProvider.overrideWithValue(secureStorage),
      ],
      child: const MyApp(),
    ),
  );
}

final themeModeProvider = StateProvider<ThemeMode>((ref) {
  final settings = ref.read(settingsServiceProvider);
  final mode = settings.themeMode;
  // 'system' | 'light' | 'dark'
  if (mode == 'light') return ThemeMode.light;
  if (mode == 'dark') return ThemeMode.dark;
  return ThemeMode.system;
});

// Global navigator key for deep linking
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // Initialize deep link service after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        ref.read(deepLinkServiceProvider).initialize();
        print('DEBUG: DeepLinkService initialized in main.dart');
      } catch (e) {
        print('ERROR: Failed to initialize DeepLinkService: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch the theme provider for changes
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      navigatorKey: navigatorKey, // Add navigator key for deep linking
      title: 'Nisaba',
      debugShowCheckedModeBanner: false,
      theme: NisabaTheme.lightTheme(),
      darkTheme: NisabaTheme.darkTheme(),
      themeMode: themeMode,
      home: const AppLockManager(child: AuthWrapper()),
      // locale: const Locale('ar', 'SA'), // Removed to allow dynamic language switching
    );
  }
}
