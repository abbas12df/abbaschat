import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/responsive_utils.dart';
import 'about_screen.dart';
import 'account_settings_screen.dart';
import 'appearance_settings_screen.dart';
import 'language_settings_screen.dart';
import 'notifications_settings_screen.dart';
import 'privacy_settings_screen.dart';
import 'security_settings_screen.dart';
import 'storage_settings_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLargeScreen = ResponsiveUtils.isLargeScreen(context);
    final isTv = ResponsiveUtils.isTv(context);
    final sections = _buildSections();

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: isLargeScreen
          ? _buildLargeView(context, sections, isTv)
          : _buildMobileView(context, sections),
    );
  }

  List<_SettingsSection> _buildSections() {
    return [
      _SettingsSection(
        title: 'الحساب',
        items: [
          _SettingItem(
            icon: Icons.person_outline_rounded,
            title: 'الحساب',
            subtitle: 'البريد وكلمة المرور',
            destination: const AccountSettingsScreen(),
          ),
        ],
      ),
      _SettingsSection(
        title: 'الخصوصية والأمان',
        items: [
          _SettingItem(
            icon: Icons.lock_outline_rounded,
            title: 'الخصوصية',
            subtitle: 'الحالة، الكتابة، إشعارات القراءة',
            destination: const PrivacySettingsScreen(),
          ),
          _SettingItem(
            icon: Icons.shield_outlined,
            title: 'الأمان',
            subtitle: 'قفل التطبيق وحماية الهوية',
            destination: const SecuritySettingsScreen(),
          ),
        ],
      ),
      _SettingsSection(
        title: 'البيانات',
        items: [
          _SettingItem(
            icon: Icons.folder_outlined,
            title: 'التخزين والبيانات',
            subtitle: 'إدارة البيانات المحلية',
            destination: const StorageSettingsScreen(),
          ),
        ],
      ),
      _SettingsSection(
        title: 'التطبيق',
        items: [
          _SettingItem(
            icon: Icons.notifications_none_rounded,
            title: 'الإشعارات',
            subtitle: 'التنبيهات والأصوات',
            destination: const NotificationsSettingsScreen(),
          ),
          _SettingItem(
            icon: Icons.palette_outlined,
            title: 'المظهر',
            subtitle: 'السمة والتفضيلات',
            destination: const AppearanceSettingsScreen(),
          ),
          _SettingItem(
            icon: Icons.language_rounded,
            title: 'اللغة',
            subtitle: 'لغة التطبيق',
            destination: const LanguageSettingsScreen(),
          ),
          _SettingItem(
            icon: Icons.info_outline_rounded,
            title: 'حول',
            subtitle: 'الإصدار والمعلومات',
            destination: const AboutScreen(),
          ),
        ],
      ),
    ];
  }

  Widget _buildMobileView(
    BuildContext context,
    List<_SettingsSection> sections,
  ) {
    final theme = Theme.of(context);

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      itemCount: sections.length,
      itemBuilder: (context, sectionIndex) {
        final section = sections[sectionIndex];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text(
                section.title,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Items — no cards, just clean rows with dividers
            ...section.items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isLast = index == section.items.length - 1;

              return _SettingsRow(
                item: item,
                showDivider: !isLast,
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildLargeView(
    BuildContext context,
    List<_SettingsSection> sections,
    bool isTv,
  ) {
    final allItems = sections.expand((s) => s.items).toList();

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = allItems[index];
                  return _SettingsGridTile(
                    item: item,
                    autofocus: isTv && index == 0,
                  );
                },
                childCount: allItems.length,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isTv ? 3 : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 88,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Row for mobile settings ─────────────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  final _SettingItem item;
  final bool showDivider;

  const _SettingsRow({
    required this.item,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        InkWell(
          onTap: () => _open(context, item.destination),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 22,
                  color: theme.iconTheme.color,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: theme.colorScheme.outline,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 0.5,
            indent: 58,
            color: theme.dividerColor,
          ),
      ],
    );
  }
}

// ─── Grid tile for large screens ─────────────────────────────────────────────

class _SettingsGridTile extends StatefulWidget {
  final _SettingItem item;
  final bool autofocus;

  const _SettingsGridTile({required this.item, this.autofocus = false});

  @override
  State<_SettingsGridTile> createState() => _SettingsGridTileState();
}

class _SettingsGridTileState extends State<_SettingsGridTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FocusableActionDetector(
      autofocus: widget.autofocus,
      onFocusChange: (focused) => setState(() => _focused = focused),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _open(context, widget.item.destination);
            return null;
          },
        ),
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: _focused
              ? theme.colorScheme.primary.withValues(alpha: 0.08)
              : theme.colorScheme.surfaceContainerHighest,
          border: _focused
              ? Border.all(color: theme.colorScheme.primary, width: 1.5)
              : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _open(context, widget.item.destination),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  widget.item.icon,
                  size: 22,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.item.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

void _open(BuildContext context, Widget destination) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => destination));
}

class _SettingsSection {
  final String title;
  final List<_SettingItem> items;

  const _SettingsSection({required this.title, required this.items});
}

class _SettingItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget destination;

  const _SettingItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.destination,
  });
}
