import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/notification_watcher.dart';
import '../services/auth_service.dart';
import 'welcome_screen.dart';
import 'verify_email_screen.dart';
import 'complete_profile_screen.dart';
import '../../chat/screens/home_screen.dart';
import '../../../core/widgets/shimmer_loaders.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authStateAsync = ref.watch(authStateProvider);

    return authStateAsync.when(
      data: (user) {
        if (user == null) {
          return const WelcomeScreen();
        } else {
          // 1. Email Verification Check
          if (!user.emailVerified) {
            return const VerifyEmailScreen();
          }

          // 2. Profile Completion Check (Firestore)
          return StreamBuilder<DocumentSnapshot>(
            key: ValueKey(user.uid),
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const ShimmerLoadingScreen(
                  message: 'جاري التحقق من حسابك...',
                );
              }

              if (snapshot.hasError) {
                // Return simple error screen or retry
                return Scaffold(
                  body: Center(child: Text('خطأ: ${snapshot.error}')),
                );
              }

              if (snapshot.hasData && snapshot.data!.exists) {
                // Profile Exists & Email Verified -> Go Home
                NotificationService().saveTokenToDatabase();
                return const NotificationWatcher(child: HomeScreen());
              }

              // Profile Missing -> Go to Complete Profile
              // Check if user needs to create password (Social Login without password)
              final hasPassword = user.providerData.any(
                (p) => p.providerId == 'password',
              );
              return CompleteProfileScreen(isSocialLogin: !hasPassword);
            },
          );
        }
      },
      loading: () =>
          const ShimmerLoadingScreen(message: 'جاري تحميل بياناتك...'),
      error: (err, stack) =>
          Scaffold(body: Center(child: Text('حدث خطأ: $err'))),
    );
  }
}
