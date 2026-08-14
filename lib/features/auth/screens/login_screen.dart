import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/auth_service.dart';

import 'register_screen.dart';
import 'auth_wrapper.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePass = true;

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final pass = _passController.text;

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال البريد الإلكتروني'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال كلمة المرور'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Strict password validation removed (length/complexity) for Login flow.
    // The server will handle credential verification.

    setState(() => _isLoading = true);
    try {
      await ref
          .read(authServiceProvider)
          .signInWithEmail(_emailController.text.trim(), _passController.text);

      // Navigate to Wrapper to handle checks (Verify/Profile)
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'فشل الدخول: ${e.toString().contains('user-not-found') ? 'مستخدم غير موجود' : 'كلمة المرور خاطئة أو حدث خطأ'}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'برجاء إدخال البريد الإلكتروني أولاً لإرسال رابط الاستعادة',
          ),
        ),
      );
      return;
    }

    try {
      await ref.read(authServiceProvider).sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم إرسال رابط استعادة كلمة المرور إلى بريدك الإلكتروني ✅',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الدخول')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.lock_person_outlined,
              size: 80,
              color: Colors.blue,
            ).animate().slideY(begin: -0.2, end: 0),
            const SizedBox(height: 32),

            const Text(
              'مرحباً بعودتك! 👋',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: 32),

            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
            ).animate().fadeIn(delay: 400.ms),

            const SizedBox(height: 16),

            TextField(
              controller: _passController,
              obscureText: _obscurePass,
              decoration: InputDecoration(
                labelText: 'كلمة المرور',
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePass ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                ),
              ),
            ).animate().fadeIn(delay: 600.ms),

            // Forgot Password Link
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _forgotPassword,
                child: const Text('هل نسيت كلمة السر؟'),
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('تسجيل الدخول', style: TextStyle(fontSize: 18)),
            ).animate().fadeIn(delay: 800.ms),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('ليس لديك حساب؟'),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    );
                  },
                  child: const Text('إنشاء حساب جديد'),
                ),
              ],
            ).animate().fadeIn(delay: 1000.ms),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),

            // Social Login
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSocialButton(
                  icon: Icons.g_mobiledata,
                  color: Colors.red.shade50,
                  iconColor: Colors.red,
                  onTap: () async {
                    try {
                      setState(() => _isLoading = true);
                      await ref.read(authServiceProvider).signInWithGoogle();
                      if (mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const AuthWrapper(),
                          ),
                          (route) => false,
                        );
                      }
                    } catch (e) {
                      if (mounted)
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  },
                ),
                const SizedBox(width: 24),
                _buildSocialButton(
                  icon: Icons.apple,
                  color: Colors.grey.shade100,
                  iconColor: Colors.black,
                  onTap: () async {
                    try {
                      setState(() => _isLoading = true);
                      await ref.read(authServiceProvider).signInWithApple();
                      if (mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const AuthWrapper(),
                          ),
                          (route) => false,
                        );
                      }
                    } catch (e) {
                      if (mounted)
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: 32, color: iconColor),
      ),
    );
  }
}
