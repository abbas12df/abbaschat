import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  String _version = '1.0.0';
  String _buildNumber = '1';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    try {
      // Try to get version from platform channel (fallback)
      // For now, use hardcoded values - can be replaced with package_info_plus if added
      setState(() {
        _version = '1.0.0';
        _buildNumber = '1';
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('لا يمكن فتح الرابط: $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('حول التطبيق'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App Logo/Icon
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.primaryColor.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.lock_outline,
                size: 60,
                color: theme.primaryColor,
              ),
            ),
          ).animate().fadeIn().scale(),

          const SizedBox(height: 24),

          // App Name
          Center(
            child: Text(
              'تطبيق المراسلة الآمن',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.titleLarge?.color,
              ),
            ),
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 8),

          // Version
          Center(
            child: _isLoading
                ? const CircularProgressIndicator()
                : Text(
                    'الإصدار $_version (Build $_buildNumber)',
                    style: TextStyle(
                      color: theme.textTheme.bodySmall?.color,
                      fontSize: 14,
                    ),
                  ),
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 32),

          // Description Card
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: theme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'عن التطبيق',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: theme.textTheme.titleMedium?.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'تطبيق مراسلة آمن ومشفر بنسبة 100% مع تشفير End-to-End. جميع رسائلك محمية ومشفرة ولا يمكن لأحد قراءتها سواك والمستقبل.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 24),

          // Features
          _buildSectionHeader('الميزات'),
          _buildFeatureTile(
            icon: Icons.lock,
            title: 'تشفير End-to-End',
            subtitle: 'جميع الرسائل مشفرة بالكامل',
          ),
          _buildFeatureTile(
            icon: Icons.security,
            title: 'Forward Secrecy',
            subtitle: 'مفاتيح التشفير تتغير تلقائياً',
          ),
          _buildFeatureTile(
            icon: Icons.verified_user,
            title: 'التوقيعات الرقمية',
            subtitle: 'التحقق من صحة الرسائل',
          ),
          _buildFeatureTile(
            icon: Icons.cloud_off,
            title: 'P2P Sync',
            subtitle: 'مزامنة مباشرة بين الأجهزة',
          ),

          const SizedBox(height: 24),

          // Links
          _buildSectionHeader('روابط'),
          _buildLinkTile(
            icon: Icons.description,
            title: 'شروط الاستخدام',
            subtitle: 'اقرأ شروط استخدام التطبيق',
            onTap: null,
          ),
          _buildLinkTile(
            icon: Icons.privacy_tip,
            title: 'سياسة الخصوصية',
            subtitle: 'تعرف على كيفية حماية بياناتك',
            onTap: null,
          ),
          _buildLinkTile(
            icon: Icons.code,
            title: 'المصدر المفتوح',
            subtitle: 'شاهد الكود المصدري على GitHub',
            onTap: null,
          ),
          _buildLinkTile(
            icon: Icons.bug_report,
            title: 'الإبلاغ عن مشكلة',
            subtitle: 'ساعدنا في تحسين التطبيق',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'يمكنك الإبلاغ عن المشاكل من خلال إعدادات التطبيق',
                  ),
                ),
              );
            },
          ),
          _buildLinkTile(
            icon: Icons.update,
            title: 'التحقق من التحديثات',
            subtitle: 'تحقق من وجود تحديثات جديدة',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('الإصدار الحالي: $_version'),
                  action: SnackBarAction(
                    label: 'تحديث',
                    onPressed: () {
                      // Placeholder for update check
                    },
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Credits
          _buildSectionHeader('الاعتمادات'),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مطور بواسطة',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.titleMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'تم تطوير هذا التطبيق باستخدام Flutter و Firebase.',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '© 2024 جميع الحقوق محفوظة',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4, top: 8),
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

  Widget _buildFeatureTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.primaryColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: theme.primaryColor, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildLinkTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).iconTheme.color),
      title: Text(title),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall,
            )
          : null,
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 14,
        color: Theme.of(context).iconTheme.color,
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
