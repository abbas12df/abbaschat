import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/auth_service.dart';

import 'register_screen.dart';
import 'auth_wrapper.dart';
import '../../../core/widgets/nisaba_button.dart';
import '../../../core/widgets/nisaba_text_field.dart';
import '../../../core/widgets/nisaba_card.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(authServiceProvider)
          .signInWithEmail(_emailController.text.trim(), _passController.text);

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
            backgroundColor: Theme.of(context).colorScheme.error,
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
          content: Text('برجاء إدخال البريد الإلكتروني أولاً لإرسال رابط الاستعادة'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await ref.read(authServiceProvider).sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال رابط استعادة كلمة المرور إلى بريدك الإلكتروني ✅'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                // Fun bubbly icon
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/images/app_logo_transparent.png',
                        width: 70,
                        height: 70,
                      ),
                    ),
                  ),
                )
                    .animate()
                    .scale(curve: Curves.easeOutBack, duration: 600.ms)
                    .fadeIn(),

                const SizedBox(height: 32),

                // Greeting
                Text(
                  'مرحباً بعودتك!',
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2, curve: Curves.easeOutBack),

                const SizedBox(height: 12),
                Text(
                  'سجل دخولك للمتابعة والتواصل بشكل آمن.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, curve: Curves.easeOutBack),

                const SizedBox(height: 48),

                // Inputs directly on the surface, or inside a soft shadow card
                NisabaCard(
                  hasShadow: true,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      NisabaTextField(
                        controller: _emailController,
                        labelText: 'البريد الإلكتروني',
                        prefixIcon: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'يرجى إدخال البريد الإلكتروني';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      NisabaTextField(
                        controller: _passController,
                        labelText: 'كلمة المرور',
                        prefixIcon: Icons.lock_rounded,
                        isPassword: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'يرجى إدخال كلمة المرور';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: NisabaButton(
                          text: 'هل نسيت كلمة السر؟',
                          type: NisabaButtonType.text,
                          fullWidth: false,
                          onPressed: _forgotPassword,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, curve: Curves.easeOutBack),

                const SizedBox(height: 32),

                // Login Button
                NisabaButton(
                  text: 'تسجيل الدخول',
                  isLoading: _isLoading,
                  onPressed: _login,
                  icon: Icons.login_rounded,
                ).animate().fadeIn(delay: 400.ms).scale(curve: Curves.easeOutBack),

                const SizedBox(height: 40),

                // Social Login Section
                Row(
                  children: [
                    Expanded(child: Divider(color: theme.colorScheme.surfaceContainerHighest)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'أو الدخول باستخدام',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: theme.colorScheme.surfaceContainerHighest)),
                  ],
                ).animate().fadeIn(delay: 500.ms),

                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSocialButton(
                      icon: Icons.g_mobiledata_rounded,
                      color: isDark ? const Color(0xFF1E293B) : Colors.red.shade50,
                      iconColor: Colors.red,
                      onTap: () async {
                        try {
                          setState(() => _isLoading = true);
                          await ref.read(authServiceProvider).signInWithGoogle();
                          if (mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const AuthWrapper()),
                              (route) => false,
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('خطأ: $e')),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isLoading = false);
                        }
                      },
                    ),
                    const SizedBox(width: 24),
                    _buildSocialButton(
                      icon: Icons.apple_rounded,
                      color: isDark ? const Color(0xFF1E293B) : Colors.black87,
                      iconColor: Colors.white,
                      onTap: () async {
                        try {
                          setState(() => _isLoading = true);
                          await ref.read(authServiceProvider).signInWithApple();
                          if (mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const AuthWrapper()),
                              (route) => false,
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('خطأ: $e')),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isLoading = false);
                        }
                      },
                    ),
                  ],
                ).animate().fadeIn(delay: 600.ms).scale(curve: Curves.easeOutBack),

                const SizedBox(height: 32),

                // Register Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'ليس لديك حساب؟',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    NisabaButton(
                      text: 'إنشاء حساب جديد',
                      type: NisabaButtonType.text,
                      fullWidth: false,
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisterScreen()),
                        );
                      },
                    ),
                  ],
                ).animate().fadeIn(delay: 700.ms),
              ],
            ),
          ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 64, // Bigger for squircle feel
          height: 64, 
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(icon, size: 40, color: iconColor),
        ),
      ),
    );
  }
}
