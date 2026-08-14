import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/settings_service.dart';
import '../../../../main.dart';

class AppearanceSettingsScreen extends ConsumerStatefulWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  ConsumerState<AppearanceSettingsScreen> createState() =>
      _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState
    extends ConsumerState<AppearanceSettingsScreen> {
  String _selectedMode = 'system';
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
        _selectedMode = settings.themeMode;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateTheme(String mode) async {
    setState(() => _selectedMode = mode);
    await ref.read(settingsServiceProvider).setThemeMode(mode);

    // Update global theme provider
    final themeMode = mode == 'light'
        ? ThemeMode.light
        : mode == 'dark'
        ? ThemeMode.dark
        : ThemeMode.system;

    ref.read(themeModeProvider.notifier).state = themeMode;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('المظهر')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfoCard(
            context,
            'تخصيص المظهر',
            'اختر الوضع المناسب لعينيك والبيئة المحيطة.',
            Icons.palette_outlined,
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('الوضع'),

          _buildRadioTile(
            title: 'تلقائي (مستحسن)',
            subtitle: 'يتبع إعدادات النظام وتوفير البطارية',
            value: 'system',
            icon: Icons.brightness_auto,
          ),
          _buildRadioTile(
            title: 'الوضع الفاتح',
            subtitle: 'مثالي للاستخدام في الإضاءة الساطعة',
            value: 'light',
            icon: Icons.brightness_5,
          ),
          _buildRadioTile(
            title: 'الوضع الداكن',
            subtitle: 'مريح للعين وموفر للطاقة في شاشات OLED',
            value: 'dark',
            icon: Icons.brightness_2,
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

  Widget _buildRadioTile({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
  }) {
    final isSelected = _selectedMode == value;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? theme.primaryColor.withOpacity(0.05) : null,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: theme.primaryColor.withOpacity(0.3))
            : null,
      ),
      child: RadioListTile<String>(
        value: value,
        groupValue: _selectedMode,
        onChanged: (val) {
          if (val != null) _updateTheme(val);
        },
        activeColor: theme.primaryColor,
        title: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? theme.primaryColor : theme.iconTheme.color,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? theme.primaryColor : null,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(right: 32.0),
          child: Text(subtitle, style: const TextStyle(fontSize: 12)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
