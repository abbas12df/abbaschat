import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:qqqq/core/widgets/nisaba_button.dart';
import 'package:qqqq/core/widgets/nisaba_text_field.dart';
import 'package:qqqq/core/widgets/nisaba_card.dart';
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
    final theme = Theme.of(context);
    
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
                      color: theme.colorScheme.tertiary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Center(
                      child: Text(
                        '✨',
                        style: TextStyle(fontSize: 48),
                      ),
                    ),
                  ),
                )
                    .animate()
                    .scale(curve: Curves.easeOutBack, duration: 600.ms)
                    .fadeIn(),

                const SizedBox(height: 32),

                Text(
                  'خطوة أخيرة!',
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2, curve: Curves.easeOutBack),

                const SizedBox(height: 12),
                Text(
                  'يرجى إكمال بياناتك للبدء في استخدام التطبيق.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, curve: Curves.easeOutBack),

                const SizedBox(height: 48),

                NisabaCard(
                  hasShadow: true,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      NisabaTextField(
                        controller: _nameController,
                        labelText: 'الاسم الظاهر',
                        prefixIcon: Icons.person_rounded,
                        validator: (val) =>
                            (val == null || val.length < 3) ? 'الاسم قصير جداً' : null,
                      ),
                      const SizedBox(height: 20),

                      NisabaTextField(
                        controller: _usernameController,
                        labelText: 'معرف المستخدم (Username)',
                        prefixIcon: Icons.alternate_email_rounded,
                        errorText: _usernameError,
                        onChanged: (_) {
                          if (_usernameError != null) {
                            setState(() => _usernameError = null);
                          }
                        },
                        validator: (val) {
                          if (val == null || val.length < 4) {
                            return 'يجب أن يكون 4 أحرف على الأقل';
                          }
                          if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(val)) {
                            return 'أحرف إنجليزية وأرقام فقط';
                          }
                          return null;
                        },
                      ),
                      
                      // Conditional Password Field for Social Login
                      if (widget.isSocialLogin) ...[
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.shield_rounded, color: theme.colorScheme.error),
                                  const SizedBox(width: 8),
                                  Text(
                                    'تنبيه أمني',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: theme.colorScheme.error,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'بما أنك سجلت الدخول باستخدام شبكات التواصل الاجتماعي، يرجى تعيين كلمة مرور لضمان أمان حسابك.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 20),
                              NisabaTextField(
                                controller: _passController,
                                labelText: 'تعيين كلمة مرور جديدة',
                                prefixIcon: Icons.lock_rounded,
                                isPassword: true,
                                validator: (val) => (val == null || val.length < 6)
                                    ? 'كلمة المرور مطلوبة (6+ أحرف)'
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, curve: Curves.easeOutBack),

                const SizedBox(height: 48),

                NisabaButton(
                  text: 'حفظ وبدء الاستخدام',
                  isLoading: _isLoading,
                  onPressed: _submit,
                  icon: Icons.check_circle_rounded,
                ).animate().fadeIn(delay: 400.ms).scale(curve: Curves.easeOutBack),
                
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
