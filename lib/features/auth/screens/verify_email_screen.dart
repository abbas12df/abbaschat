import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'auth_wrapper.dart'; // To navigate back to main check logic
import '../services/auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  Timer? _countdownTimer;
  Timer? _pollingTimer;
  bool _canResend = false;
  int _secondsRemaining = 60;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _startPolling();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    setState(() {
      _canResend = false;
      _secondsRemaining = 60;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) setState(() => _secondsRemaining--);
      } else {
        if (mounted) setState(() => _canResend = true);
        timer.cancel();
      }
    });
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _checkEmailVerified();
    });
  }

  Future<void> _checkEmailVerified() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await user.reload(); // Critical: Force refresh of auth token/state
        if (user.emailVerified) {
          _pollingTimer?.cancel();
          _countdownTimer?.cancel();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم تأكيد البريد بنجاح! جاري الدخول... ✅'),
                backgroundColor: Colors.green,
              ),
            );

            // Restart app flow to enter CompleteProfile or Home
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AuthWrapper()),
              (route) => false,
            );
          }
        }
      } catch (e) {
        // Silently ignore network errors during polling to prevent annoyance
        debugPrint('Polling error: $e');
      }
    }
  }

  Future<void> _resendEmail() async {
    if (!_canResend) return;
    try {
      await ref.read(authServiceProvider).sendEmailVerification();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إرسال الرابط مجدداً ✅')));
      _startTimer();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تأكيد البريد الإلكتروني'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                    Icons.mark_email_unread_outlined,
                    size: 100,
                    color: Colors.amber,
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(begin: 1, end: 1.1, duration: 1.seconds),
              const SizedBox(height: 32),

              const Text(
                'تحقق من بريدك الوارد',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              Text(
                'لقد أرسلنا رابط تفعيل إلى:\n${FirebaseAuth.instance.currentUser?.email ?? ""}\n\nيرجى الضغط على الرابط في الرسالة لتفعيل حسابك.',
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.5, color: Colors.grey),
              ),

              const SizedBox(height: 48),

              ElevatedButton.icon(
                onPressed: _canResend ? _resendEmail : null,
                icon: const Icon(Icons.refresh),
                label: Text(
                  _canResend
                      ? 'إعادة الإرسال'
                      : 'انتظر $_secondsRemaining ثانية',
                ),
              ),

              TextButton(
                onPressed: () => _checkEmailVerified(),
                child: const Text('لقد قمت بالتفعيل، تحديث الآن'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
