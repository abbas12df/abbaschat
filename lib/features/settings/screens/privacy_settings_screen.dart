import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../chat/repositories/chat_repository.dart';
import '../services/settings_service.dart';
import 'blocked_users_screen.dart';

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  bool _isOnlineVisible = true;
  bool _isTypingIndicatorEnabled = true;
  bool _isReadReceiptsEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = ref.read(settingsServiceProvider);
    await settings.init();

    if (mounted) {
      setState(() {
        _isOnlineVisible = settings.onlineStatus;
        _isTypingIndicatorEnabled = settings.typingIndicator;
        _isReadReceiptsEnabled = settings.readReceipts;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateOnline(bool val) async {
    setState(() => _isOnlineVisible = val);
    await ref.read(settingsServiceProvider).setOnlineStatus(val);
    await ref.read(chatRepositoryProvider).updateOnlinePrivacy(val);
  }

  Future<void> _updateTyping(bool val) async {
    setState(() => _isTypingIndicatorEnabled = val);
    await ref.read(settingsServiceProvider).setTypingIndicator(val);
  }

  Future<void> _updateReadReceipts(bool val) async {
    setState(() => _isReadReceiptsEnabled = val);
    await ref.read(settingsServiceProvider).setReadReceipts(val);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('الخصوصية')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('الدردشة'),
          _buildToggle(
            'حالة الاتصال',
            'الظهور "متصل" أونلاين لدى الآخرين',
            _isOnlineVisible,
            _updateOnline,
          ),
          _buildToggle(
            'مؤشر الكتابة',
            'إظهار "جاري الكتابة..." عند المراسلة',
            _isTypingIndicatorEnabled,
            _updateTyping,
          ),
          _buildToggle(
            'إيصالات القراءة',
            'إرسال العلامة المزدوجة الملونة',
            _isReadReceiptsEnabled,
            _updateReadReceipts,
          ),

          const Divider(height: 32),

          _buildSectionHeader('المجموعات والاتصال'),
          ListTile(
            title: const Text('المجموعات'),
            subtitle: const Text('من يمكنه إضافتي للمجموعات (قريباً)'),
            enabled: false,
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
          ),
          ListTile(
            title: const Text('المحظورين'),
            subtitle: const Text('إدارة جهات الاتصال المحظورة'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BlockedUsersScreen(),
                ),
              );
            },
          ),
        ],
      ).animate().fadeIn(),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4, top: 4),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildToggle(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      value: value,
      onChanged: onChanged,
      activeColor: Theme.of(context).primaryColor,
      contentPadding: EdgeInsets.zero,
    );
  }
}
