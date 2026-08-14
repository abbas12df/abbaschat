import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/settings_service.dart';

class NotificationsSettingsScreen extends ConsumerStatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  ConsumerState<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends ConsumerState<NotificationsSettingsScreen> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrateEnabled = true;
  bool _showPreview = true;
  bool _dndEnabled = false;
  String _dndStart = '22:00';
  String _dndEnd = '08:00';
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
        _notificationsEnabled = settings.notificationsEnabled;
        _soundEnabled = settings.notificationSound;
        _vibrateEnabled = settings.notificationVibrate;
        _showPreview = settings.notificationPreview;
        _dndEnabled = settings.doNotDisturbEnabled;
        _dndStart = settings.doNotDisturbStart;
        _dndEnd = settings.doNotDisturbEnd;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateNotifications(bool val) async {
    setState(() => _notificationsEnabled = val);
    await ref.read(settingsServiceProvider).setNotificationsEnabled(val);
  }

  Future<void> _updateSound(bool val) async {
    setState(() => _soundEnabled = val);
    await ref.read(settingsServiceProvider).setNotificationSound(val);

    if (val) {
      // Play a quick test sound
      // AudioPlayer().play(AssetSource('sounds/notification.mp3'));
      // Note: Needs asset setup, skipping for now to avoid crash
    }
  }

  Future<void> _updateVibrate(bool val) async {
    setState(() => _vibrateEnabled = val);
    await ref.read(settingsServiceProvider).setNotificationVibrate(val);
  }

  Future<void> _updatePreview(bool val) async {
    setState(() => _showPreview = val);
    await ref.read(settingsServiceProvider).setNotificationPreview(val);
  }

  Future<void> _updateDND(bool val) async {
    setState(() => _dndEnabled = val);
    await ref.read(settingsServiceProvider).setDoNotDisturbEnabled(val);
  }

  Future<void> _selectDNDTime(bool isStart) async {
    final time = isStart ? _dndStart : _dndEnd;
    final parts = time.split(':');
    final initialTime = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (selectedTime != null) {
      final timeString =
          '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
      
      setState(() {
        if (isStart) {
          _dndStart = timeString;
        } else {
          _dndEnd = timeString;
        }
      });

      final settings = ref.read(settingsServiceProvider);
      if (isStart) {
        await settings.setDoNotDisturbStart(timeString);
      } else {
        await settings.setDoNotDisturbEnd(timeString);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfoCard(
            context,
            'التحكم في التنبيهات',
            'يمكنك تخصيص طريقة استقبالك لإشعارات الرسائل الجديدة.',
            Icons.notifications_active_outlined,
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('عام'),
          SwitchListTile(
            title: const Text(
              'تفعيل الإشعارات',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('استلام تنبيهات عند ورود رسائل جديدة'),
            value: _notificationsEnabled,
            activeColor: theme.primaryColor,
            onChanged: _updateNotifications,
          ),

          const Divider(height: 32),

          _buildSectionHeader('التنبيهات'),
          SwitchListTile(
            title: const Text('الأصوات'),
            subtitle: const Text('تشغيل نغمة عند الاستلام'),
            value: _soundEnabled,
            onChanged: _notificationsEnabled ? _updateSound : null,
            activeColor: theme.primaryColor,
            secondary: Icon(
              Icons.music_note,
              color: _notificationsEnabled
                  ? theme.primaryColor
                  : theme.disabledColor,
            ),
          ),
          SwitchListTile(
            title: const Text('الاهتزاز'),
            subtitle: const Text('الاهتزاز عند الاستلام'),
            value: _vibrateEnabled,
            onChanged: _notificationsEnabled ? _updateVibrate : null,
            activeColor: theme.primaryColor,
            secondary: Icon(
              Icons.vibration,
              color: _notificationsEnabled
                  ? theme.primaryColor
                  : theme.disabledColor,
            ),
          ),

          const Divider(height: 32),

          _buildSectionHeader('الخصوصية'),
          SwitchListTile(
            title: const Text('معاينة الرسالة'),
            subtitle: const Text('إظهار نص الرسالة داخل الإشعار'),
            value: _showPreview,
            onChanged: _notificationsEnabled ? _updatePreview : null,
            activeColor: theme.primaryColor,
            secondary: Icon(
              Icons.visibility_outlined,
              color: _notificationsEnabled
                  ? theme.primaryColor
                  : theme.disabledColor,
            ),
          ),

          const Divider(height: 32),

          _buildSectionHeader('جدولة الإشعارات'),
          SwitchListTile(
            title: const Text('عدم الإزعاج'),
            subtitle: const Text('تعطيل الإشعارات في أوقات معينة'),
            value: _dndEnabled,
            onChanged: _notificationsEnabled ? _updateDND : null,
            activeColor: theme.primaryColor,
            secondary: Icon(
              Icons.bedtime,
              color: _notificationsEnabled && _dndEnabled
                  ? theme.primaryColor
                  : theme.disabledColor,
            ),
          ),
          if (_dndEnabled && _notificationsEnabled)
            ListTile(
              title: const Text('من'),
              subtitle: Text(_dndStart),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () => _selectDNDTime(true),
            ),
          if (_dndEnabled && _notificationsEnabled)
            ListTile(
              title: const Text('إلى'),
              subtitle: Text(_dndEnd),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () => _selectDNDTime(false),
            ),
        ],
      ).animate().fadeIn(),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
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

  Widget _buildInfoCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).iconTheme.color, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
