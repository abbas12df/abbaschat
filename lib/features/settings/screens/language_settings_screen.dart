import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/settings_service.dart';

class LanguageSettingsScreen extends ConsumerStatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  ConsumerState<LanguageSettingsScreen> createState() =>
      _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState
    extends ConsumerState<LanguageSettingsScreen> {
  String _selectedLanguage = 'ar';
  bool _isLoading = true;

  final Map<String, Map<String, String>> _languages = {
    'ar': {'name': 'العربية', 'native': 'العربية'},
    'en': {'name': 'English', 'native': 'English'},
  };

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final settings = ref.read(settingsServiceProvider);
    await settings.init();

    setState(() {
      _selectedLanguage = settings.language;
      _isLoading = false;
    });
  }

  Future<void> _updateLanguage(String langCode) async {
    setState(() => _selectedLanguage = langCode);
    await ref.read(settingsServiceProvider).setLanguage(langCode);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تغيير اللغة إلى ${_languages[langCode]!['native']}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('اللغة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfoCard(
            context,
            'اختر اللغة',
            'اختر اللغة المفضلة لعرض التطبيق',
            Icons.language,
          ),
          const SizedBox(height: 24),
          ..._languages.entries.map(
            (entry) => _buildLanguageTile(
              code: entry.key,
              name: entry.value['name']!,
              native: entry.value['native']!,
            ),
          ),
        ],
      ).animate().fadeIn(),
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
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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

  Widget _buildLanguageTile({
    required String code,
    required String name,
    required String native,
  }) {
    final isArabic = code == 'ar';
    final isSelected = _selectedLanguage == code;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.55)
            : theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: isSelected ? 1.2 : 0.8,
        ),
      ),
      child: ListTile(
        onTap: isArabic
            ? () => _updateLanguage('ar')
            : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'اللغة الإنجليزية قيد التطوير حالياً. اللغة الأساسية المتاحة هي العربية.',
                    ),
                  ),
                );
              },
        leading: Icon(
          Icons.check_circle,
          size: 20,
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        title: Row(
          children: [
            Text(
              native,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
            if (!isArabic) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF5A3B12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'قريباً',
                  style: TextStyle(
                    fontSize: 10,
                    color: const Color(0xFFFFB74D),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          isArabic
              ? 'اللغة الرسمية للتطبيق (مُفعلة بالكامل)'
              : 'قيد التطوير - التطبيق يدعم العربية حالياً',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
