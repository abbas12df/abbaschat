import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/auth_service.dart';
import '../../../core/utils/validators.dart';
// We will navigate to wrapper to handle state
import 'verify_email_screen.dart'; // Create next

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      // 1. Create Account
      await ref
          .read(authServiceProvider)
          .signUpWithEmail(_emailController.text.trim(), _passController.text);

      // 2. Send Verification
      await ref.read(authServiceProvider).sendEmailVerification();

      if (mounted) {
        // Navigate to Verification Screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        String message = 'فشل التسجيل';
        if (e.toString().contains('email-already-in-use')) {
          message = 'البريد الإلكتروني مسجل مسبقاً. حاول تسجيل الدخول.';
        } else if (e.toString().contains('weak-password')) {
          message = 'كلمة المرور ضعيفة جداً.';
        } else if (e.toString().contains('invalid-email')) {
          message = 'البريد الإلكتروني غير صالح.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء حساب جديد')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.person_add_rounded,
                size: 80,
                color: Colors.blue,
              ).animate().scale(),
              const SizedBox(height: 32),

              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || !val.contains('@')) return 'بريد غير صالح';
                  return null;
                },
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 16),

              TextFormField(
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
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                  ),
                ),
                validator: Validators.validatePassword,
              ).animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 16),

              TextFormField(
                controller: _confirmPassController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'تأكيد كلمة المرور',
                  prefixIcon: const Icon(Icons.lock_reset),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (val) {
                  if (val != _passController.text)
                    return 'كلمات المرور غير متطابقة';
                  return null;
                },
              ).animate().fadeIn(delay: 600.ms),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _isLoading ? null : _signUp,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'إنشاء الحساب',
                        style: TextStyle(fontSize: 18),
                      ),
              ).animate().fadeIn(delay: 800.ms),
            ],
          ),
        ),
      ),
    );
  }
}
