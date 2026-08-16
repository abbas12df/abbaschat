import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto/crypto.dart'; // Added for fingerprint
import 'dart:convert'; // Added for utf8

import '../../../../core/security/crypto_service.dart';
import '../../../../core/security/screen_security_service.dart';
import '../../auth/repositories/key_repository.dart';
import '../services/settings_service.dart';
import '../../../../core/security/biometric_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'blocked_users_screen.dart';

class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() =>
      _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState
    extends ConsumerState<SecuritySettingsScreen> {
  bool _appLockEnabled = false;
  String _currentFingerprint = '...';
  String _lastRotationTime = '...';
  int _autoLockTimeout = 0; // 0 = Immediately (بالثواني)
  bool _preventScreenshots = false;

  @override
  void initState() {
    super.initState();
    _initSecuritySettings();
    _loadSecurityInfo();
  }

  Future<void> _initSecuritySettings() async {
    final settings = ref.read(settingsServiceProvider);
    await settings.init();

    await ScreenSecurityService.applyGlobalProtection();
    final preventScreenshots =
        await ScreenSecurityService.isGlobalProtectionEnabled();

    if (!mounted) return;
    setState(() {
      _appLockEnabled = settings.appLock;
      _autoLockTimeout = settings.autoLockTimeout;
      _preventScreenshots = preventScreenshots;
    });
  }

  Future<void> _loadSecurityInfo() async {
    final pubKey = await CryptoService().getPublicKeyPem();
    final lastRot = await CryptoService().getLastRotationTime();

    if (mounted) {
      setState(() {
        _currentFingerprint = _calculateFingerprint(pubKey ?? 'unknown');
        _lastRotationTime = lastRot != null
            ? _formatDate(lastRot)
            : 'غير معروف';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الأمان')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('الوصول للتطبيق'),
          SwitchListTile(
            secondary: Icon(
              Icons.fingerprint,
              color: Theme.of(context).iconTheme.color,
            ),
            title: const Text('قفل التطبيق'),
            subtitle: const Text('استخدام البصمة أو FaceID لفتح التطبيق'),
            value: _appLockEnabled,
            activeColor: Theme.of(context).primaryColor,
            onChanged: (val) => _handleAppLockToggle(val),
          ),

          SwitchListTile(
            secondary: Icon(
              Icons.screenshot_monitor,
              color: Theme.of(context).iconTheme.color,
            ),
            title: const Text('منع لقطات الشاشة'),
            subtitle: const Text(
              'يحمي جهازك أنت فقط من التقاط الشاشة ويخفي المعاينة بقائمة التطبيقات (لا يمنع الطرف الآخر من تصوير شاشته)',
            ),
            value: _preventScreenshots,
            activeThumbColor: Theme.of(context).primaryColor,
            onChanged: _handlePreventScreenshotsToggle,
          ),

          ListTile(
            enabled: _appLockEnabled,
            title: const Text('القفل التلقائي'),
            subtitle: Text(_getTimeoutLabel(_autoLockTimeout)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: _showAutoLockOptions,
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('الهوية والتشفير'),
          _buildSecurityTile(
            context,
            icon: Icons.sync_lock,
            title: 'تحديث هوية التشفير',
            subtitle:
                'البصمة: $_currentFingerprint\nآخر تدوير: $_lastRotationTime',
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('تحديث الهوية الأمنية؟'),
                  content: const Text(
                    'سيتم إنشاء مفاتيح تشفير جديدة يدوياً.\n\nℹ️ معلومة: التطبيق يقوم الآن بتحديث المفاتيح تلقائياً عند فتح التطبيق أو العودة إليه لضمان أمان الجلسة. استخدم هذا الخيار فقط للطوارئ.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('إلغاء'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('تحديث'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                try {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('جارٍ تحديث المفاتيح...')),
                  );
                  await CryptoService().rotateKeys(force: true);
                  await ref.read(keyRepositoryProvider).uploadMyPublicKey();
                  await _loadSecurityInfo(); // Refresh UI to show new fingerprint
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تحديث الهوية بنجاح ✅')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                  }
                }
              }
            },
          ),

          const Divider(height: 32),
          _buildSectionHeader('الخصوصية'),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('المستخدمون المحظورون'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
              );
            },
          ),

          const Divider(height: 32),
          _buildSectionHeader('الجلسات'),
          ListTile(
            leading: const Icon(Icons.devices),
            title: const Text('الأجهزة المتصلة'),
            subtitle: const Text('عرض معلومات الجهاز الحالي'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: _showDeviceInfo,
          ),
          ListTile(
            leading: Icon(
              Icons.logout,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'تسجيل الخروج من جميع الأجهزة',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            subtitle: const Text('سيتم تسجيل الخروج من جميع الأجهزة الأخرى'),
            onTap: null, // MISSING_BACKEND
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodySmall?.color,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  String _calculateFingerprint(String input) {
    var bytes = utf8.encode(input);
    var digest = sha256.convert(bytes);
    var hex = digest.toString().toUpperCase().substring(0, 16);
    return '${hex.substring(0, 4)}-${hex.substring(4, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}';
  }

  String _formatDate(DateTime date) {
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')}  ${date.day}/${date.month}';
  }

  String _getTimeoutLabel(int seconds) {
    if (seconds == 0) return 'فوراً';
    if (seconds < 60) return '$seconds ثانية';
    return '${seconds ~/ 60} دقيقة';
  }

  Future<void> _showAutoLockOptions() async {
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('قفل التطبيق تلقائياً'),
        children: [
          _buildTimeoutOption(ctx, 0, 'فوراً'),
          _buildTimeoutOption(ctx, 30, 'بعد 30 ثانية'),
          _buildTimeoutOption(ctx, 60, 'بعد دقيقة'),
          _buildTimeoutOption(ctx, 300, 'بعد 5 دقائق'),
        ],
      ),
    );

    if (selected != null) {
      setState(() => _autoLockTimeout = selected);
      await ref.read(settingsServiceProvider).setAutoLockTimeout(selected);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حفظ الإعداد: ${_getTimeoutLabel(selected)}'),
          ),
        );
      }
    }
  }

  Widget _buildTimeoutOption(BuildContext ctx, int value, String label) {
    return SimpleDialogOption(
      onPressed: () => Navigator.pop(ctx, value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: _autoLockTimeout == value
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // --- Helpers ---
  Future<void> _handlePreventScreenshotsToggle(bool val) async {
    setState(() => _preventScreenshots = val);
    await ScreenSecurityService.setGlobalProtection(val);
  }

  Future<void> _handleAppLockToggle(bool val) async {
    if (val) {
      // Enabling: specific check
      final bio = ref.read(biometricServiceProvider);
      final available = await bio.isBiometricsAvailable;
      if (!available) {
        if (!mounted) return;

        final status = await bio.getBiometricStatus();

        // Show detailed error dialog
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('خطأ في البصمة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('عذراً، لم نتمكن من الوصول للبصمة.'),
                  const Divider(),
                  const Text(
                    'التفاصيل التقنية (Debugging):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('Can Check: ${status['canCheckBiometrics']}'),
                  Text('Device Supported: ${status['isDeviceSupported']}'),
                  Text('Available Types: ${status['availableBiometrics']}'),
                  if (status.containsKey('error'))
                    Text(
                      'Error: ${status['error']}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  const SizedBox(height: 10),
                  const Text(
                    'نصيحة: تأكد من إعداد البصمة في إعدادات هاتفك، وأنك قمت بإعادة تشغيل التطبيق بالكامل إذا كنت قد أضفت الميزة للتو.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
        return;
      }

      final authenticated = await bio.authenticate(
        localizedReason: 'يرجى تأكيد البصمة لتفعيل القفل',
      );
      if (!authenticated) return;
    }

    // Save
    setState(() => _appLockEnabled = val);
    await ref.read(settingsServiceProvider).setAppLock(val);

    if (val && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تفعيل قفل التطبيق ✅')));
    }
  }

  Future<void> _showDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    String deviceName = 'Unknown';
    String osVersion = 'Unknown';

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceName = '${androidInfo.brand} ${androidInfo.model}';
      osVersion = 'Android ${androidInfo.version.release}';
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceName = iosInfo.name;
      osVersion = '${iosInfo.systemName} ${iosInfo.systemVersion}';
    } else if (Platform.isWindows) {
      final winInfo = await deviceInfo.windowsInfo;
      deviceName = winInfo.computerName;
      osVersion = 'Windows';
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تفاصيل الجهاز',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildInfoRow('الجهاز:', deviceName),
            const SizedBox(height: 8),
            _buildInfoRow('النظام:', osVersion),
            const SizedBox(height: 8),
            _buildInfoRow('الحالة:', 'نشط حالياً (هذا الجهاز)'),
            const SizedBox(height: 8),
            _buildInfoRow(
              'معرف المستخدم:',
              FirebaseAuth.instance.currentUser?.uid.substring(0, 12) ??
                  'غير معروف',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(value),
      ],
    );
  }



  Widget _buildSecurityTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).iconTheme.color),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: trailing,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
