import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qqqq/features/auth/services/auth_service.dart';

class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('الحساب')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info Card
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : null,
                    child: user?.photoURL == null
                        ? const Icon(Icons.person, size: 30)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.displayName ?? 'مستخدم',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(color: theme.textTheme.bodySmall?.color),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (user?.providerData.any(
                            (p) => p.providerId == 'google.com',
                          ) ??
                          false)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.g_mobiledata, color: Colors.red),
                        ),
                      if (user?.providerData.any(
                            (p) => p.providerId == 'password',
                          ) ??
                          false)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.lock,
                            color: Colors.green,
                            size: 18,
                          ),
                        ),
                      if (user?.providerData.any(
                            (p) => p.providerId == 'apple.com',
                          ) ??
                          false)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.apple, size: 18),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'الأمان',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.textTheme.titleMedium?.color,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.password),
            title: const Text('إدارة كلمة المرور'),
            subtitle: const Text('تغيير أو إنشاء كلمة مرور'),
            onTap: () => _handlePasswordReset(context),
          ),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('تحديث البريد الإلكتروني'),
            subtitle: Text(
              user?.emailVerified == true
                  ? 'البريد الإلكتروني مُتحقق منه'
                  : 'البريد الإلكتروني غير مُتحقق',
              style: TextStyle(
                fontSize: 12,
                color: user?.emailVerified == true
                    ? Colors.green
                    : Colors.orange,
              ),
            ),
            trailing: user?.emailVerified == false
                ? TextButton(
                    onPressed: () => _resendVerificationEmail(context, ref),
                    child: const Text('إعادة الإرسال'),
                  )
                : null,
            onTap: () => _updateEmail(context, ref),
          ),
          if (user?.emailVerified == false)
            Card(
              margin: const EdgeInsets.only(top: 8),
              color: Colors.orange.withOpacity(0.1),
              child: ListTile(
                leading: const Icon(Icons.warning_amber, color: Colors.orange),
                title: const Text(
                  'تحقق من بريدك الإلكتروني',
                  style: TextStyle(fontSize: 13),
                ),
                subtitle: const Text(
                  'يرجى التحقق من بريدك الإلكتروني لتفعيل جميع الميزات',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: TextButton(
                  onPressed: () => _resendVerificationEmail(context, ref),
                  child: const Text('إعادة الإرسال'),
                ),
              ),
            ),

          const SizedBox(height: 24),
          const Text(
            'المنطقة الخطرة',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              'حذف الحساب',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () => _showDeleteConfirmDialog(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePasswordReset(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return;

    // Check if user is signed in with password
    final isPasswordProvider = user!.providerData.any(
      (p) => p.providerId == 'password',
    );
    if (!isPasswordProvider) {
      // Suggest adding a password
      final addPassword = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('إنشاء كلمة مرور'),
          content: const Text(
            'حسابك مسجل عبر Google/Apple ولا يملك كلمة مرور مستقلة.\n\nهل تريد إنشاء كلمة مرور لهذا الحساب لتتمكن من تسجيل الدخول بها أيضاً؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('نعم، إنشاء'),
            ),
          ],
        ),
      );

      if (addPassword == true && context.mounted) {
        _showCreatePasswordDialog(context);
      }
      return;
    }

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);

      if (context.mounted) {
        Navigator.pop(context); // Close loading
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('✅ تم الإرسال'),
            content: Text(
              'تم إرسال رابط إعادة التعيين إلى:\n\n${user.email}\n\nيرجى التحقق من البريد الوارد ورسائل السبام (spam).',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading if open (might need check)
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('خطأ'),
            content: Text('فشل الإرسال: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _showCreatePasswordDialog(BuildContext context) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعيين كلمة مرور جديدة'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'كلمة المرور الجديدة',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          Consumer(
            builder: (context, ref, _) {
              return ElevatedButton(
                onPressed: () async {
                  try {
                    if (controller.text.length < 6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('كلمة المرور قصيرة جداً')),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    await ref
                        .read(authServiceProvider)
                        .linkPassword(controller.text);
                    if (context.mounted) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('نجاح'),
                          content: const Text(
                            'تم إنشاء كلمة المرور بنجاح ✅\nيمكنك الآن تسجيل الدخول باستخدام البريد وكلمة المرور.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('ممتاز'),
                            ),
                          ],
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('فشل الإنشاء: $e')),
                      );
                    }
                  }
                },
                child: const Text('حفظ'),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _resendVerificationEmail(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      await ref.read(authServiceProvider).sendEmailVerification();

      if (context.mounted) {
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('✅ تم الإرسال'),
            content: Text(
              'تم إرسال رابط التحقق إلى:\n\n${user.email}\n\nيرجى التحقق من البريد الوارد ورسائل السبام (spam).',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('خطأ'),
            content: Text('فشل الإرسال: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _updateEmail(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تحديث البريد الإلكتروني'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ستصلك رسالة تحقق على البريد الجديد قبل اعتماده.'),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'البريد الجديد',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('تحديث'),
          ),
        ],
      ),
    );

    if (confirmed != null && confirmed.isNotEmpty) {
      // Validate email format
      if (!confirmed.contains('@') || !confirmed.contains('.')) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('يرجى إدخال بريد إلكتروني صحيح')),
          );
        }
        return;
      }

      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(child: CircularProgressIndicator()),
        );

        await ref.read(authServiceProvider).updateEmail(confirmed);
        
        if (context.mounted) {
          Navigator.pop(context);
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('✅ تم الإرسال'),
              content: Text(
                'تم إرسال رابط التحقق إلى:\n$confirmed\n\nيجب النقر على الرابط لتفعيل البريد الجديد.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('حسناً'),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context);
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('خطأ'),
              content: Text('فشل التحديث: $e'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إغلاق'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  void _showDeleteConfirmDialog(BuildContext context, WidgetRef ref) {
    bool loading = false;
    final passController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('حذف الحساب نهائياً؟'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'تحذير: هذا الإجراء لا يمكن التراجع عنه! سيتم حذف كل بياناتك.\n\nللإستمرار، أدخل كلمة المرور:',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور',
                  border: OutlineInputBorder(),
                ),
              ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: loading
                  ? null
                  : () async {
                      setState(() => loading = true);
                      try {
                        // 1. Re-auth
                        await ref
                            .read(authServiceProvider)
                            .reauthenticateUser(passController.text);
                        // 2. Delete
                        await ref.read(authServiceProvider).deleteAccount();
                        // 3. Navigate
                        if (context.mounted) {
                          Navigator.pop(ctx); // Dialog
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/login',
                            (route) => false,
                          ); // Or AuthWrapper handles it
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('فشل الحذف: $e')),
                          );
                          Navigator.pop(ctx);
                        }
                      }
                    },
              child: const Text(
                'تأكيد الحذف',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
