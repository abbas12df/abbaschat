import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'auth_wrapper.dart';
import '../../../core/widgets/nisaba_button.dart';
import '../../../core/widgets/nisaba_text_field.dart';
import '../../../core/widgets/nisaba_card.dart';

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
  
  // Password validation state
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  @override
  void initState() {
    super.initState();
    _passController.addListener(_validatePasswordRules);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  void _validatePasswordRules() {
    final pass = _passController.text;
    setState(() {
      _hasMinLength = pass.length >= 8;
      _hasUppercase = pass.contains(RegExp(r'[A-Z]'));
      _hasLowercase = pass.contains(RegExp(r'[a-z]'));
      _hasNumber = pass.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = pass.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  bool _isPasswordValid() {
    return _hasMinLength &&
        _hasUppercase &&
        _hasLowercase &&
        _hasNumber &&
        _hasSpecialChar;
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isPasswordValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('يرجى استيفاء جميع شروط كلمة المرور'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref
          .read(authServiceProvider)
          .signUpWithEmail(_emailController.text.trim(), _passController.text);
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
            content: Text('فشل التسجيل: ${e.toString().contains('email-already-in-use') ? 'البريد مستخدم بالفعل' : 'حدث خطأ'}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildValidationRow(String text, bool isValid, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isValid 
                  ? theme.colorScheme.primary 
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
            ),
            child: Icon(
              isValid ? Icons.check_rounded : Icons.lock_outline_rounded,
              size: 14,
              color: isValid ? Colors.white : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(
              color: isValid ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
              fontWeight: isValid ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
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
                      color: theme.colorScheme.secondary.withValues(alpha: 0.1),
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

                Text(
                  'إنشاء حساب جديد',
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2, curve: Curves.easeOutBack),

                const SizedBox(height: 12),
                Text(
                  'انضم إلينا الآن وابدأ بالتواصل بشكل آمن.',
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
                        controller: _emailController,
                        labelText: 'البريد الإلكتروني',
                        prefixIcon: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'يرجى إدخال البريد الإلكتروني';
                          }
                          if (!value.contains('@')) {
                            return 'بريد إلكتروني غير صالح';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      NisabaTextField(
                        controller: _passController,
                        labelText: 'كلمة المرور',
                        prefixIcon: Icons.lock_outline_rounded,
                        isPassword: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'يرجى إدخال كلمة المرور';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      NisabaTextField(
                        controller: _confirmPassController,
                        labelText: 'تأكيد كلمة المرور',
                        prefixIcon: Icons.lock_rounded,
                        isPassword: true,
                        validator: (value) {
                          if (value != _passController.text) {
                            return 'كلمات المرور غير متطابقة';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Password Rules indicator (Bubbly style)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'يجب أن تحتوي كلمة المرور على:',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildValidationRow('8 أحرف على الأقل', _hasMinLength, theme),
                            _buildValidationRow('حرف كبير (A-Z)', _hasUppercase, theme),
                            _buildValidationRow('حرف صغير (a-z)', _hasLowercase, theme),
                            _buildValidationRow('رقم (0-9)', _hasNumber, theme),
                            _buildValidationRow('رمز مميز (!@#\$&*)', _hasSpecialChar, theme),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, curve: Curves.easeOutBack),

                const SizedBox(height: 48),

                NisabaButton(
                  text: 'إنشاء الحساب',
                  isLoading: _isLoading,
                  onPressed: _register,
                  icon: Icons.person_add_rounded,
                ).animate().fadeIn(delay: 400.ms).scale(curve: Curves.easeOutBack),

                const SizedBox(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'لديك حساب بالفعل؟',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    NisabaButton(
                      text: 'تسجيل الدخول',
                      type: NisabaButtonType.text,
                      fullWidth: false,
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                    ),
                  ],
                ).animate().fadeIn(delay: 500.ms),
                
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
