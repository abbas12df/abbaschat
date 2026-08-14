import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import 'auth_wrapper.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CompleteProfileScreen extends ConsumerStatefulWidget {
  final bool isSocialLogin;
  const CompleteProfileScreen({super.key, this.isSocialLogin = false});

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passController = TextEditingController(); // Only for Social

  bool _isLoading = false;
  String? _usernameError;

  @override
  void initState() {
    super.initState();
    // Pre-fill name if available via social
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null) {
      _nameController.text = user!.displayName!;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Check Username Uniqueness
    setState(() => _isLoading = true);
    final isAvailable = await ref
        .read(authServiceProvider)
        .isUsernameAvailable(_usernameController.text);
    if (!isAvailable) {
      setState(() {
        _isLoading = false;
        _usernameError = 'هذا المعرف مستخدم بالفعل';
      });
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // If Social, create Password first
      if (widget.isSocialLogin && _passController.text.isNotEmpty) {
        await ref.read(authServiceProvider).linkPassword(_passController.text);
      }

      // Save Profile
      await ref
          .read(authServiceProvider)
          .saveUserProfile(
            uid: user.uid,
            email: user.email!, // Email is guaranteed available here
            displayName: _nameController.text,
            username: _usernameController.text,
          );

      if (mounted) {
        // Navigate Home
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إكمال الملف الشخصي')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'خطوة أخيرة!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'يرجى إكمال بياناتك للبدء.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'الاسم الظاهر',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    (val == null || val.length < 3) ? 'الاسم قصير جداً' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'معرف المستخدم (Username)',
                  border: const OutlineInputBorder(),
                  prefixText: '@',
                  errorText: _usernameError,
                ),
                onChanged: (_) => setState(() => _usernameError = null),
                validator: (val) {
                  if (val == null || val.length < 4)
                    return 'يجب أن يكون 4 أحرف على الأقل';
                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(val))
                    return 'أحرف إنجليزية وأرقام فقط';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Conditional Password Field for Social Login
              if (widget.isSocialLogin) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '⚠️ تنبيه أمني',
                        style: TextStyle(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'بما أنك سجلت عبر Google/Apple، يجب تعيين كلمة مرور لهذا الحساب لضمان أمانك.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passController,
                        decoration: const InputDecoration(
                          labelText: 'تعيين كلمة مرور جديدة',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (val) => (val == null || val.length < 6)
                            ? 'كلمة المرور مطلوبة (6+ أحرف)'
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('حفظ وبدء الاستخدام'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
