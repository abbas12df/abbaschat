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
    final items = _buildItems();

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: isLargeScreen
          ? _buildLargeSettingsView(context, items, isTv)
          : _buildMobileSettingsView(context, items),
    );
  }

  List<_SettingItem> _buildItems() {
    return const [
      _SettingItem(
        section: 'Account',
        icon: Icons.person_outline,
        title: 'Account',
        subtitle: 'Email, password, and account controls',
        destination: AccountSettingsScreen(),
      ),
      _SettingItem(
        section: 'Privacy & Security',
        icon: Icons.lock_outline,
        title: 'Privacy',
        subtitle: 'Online status, typing, and read receipts',
        destination: PrivacySettingsScreen(),
      ),
      _SettingItem(
        section: 'Privacy & Security',
        icon: Icons.shield_outlined,
        title: 'Security',
        subtitle: 'App lock and identity safety',
        destination: SecuritySettingsScreen(),
      ),
      _SettingItem(
        section: 'Data',
        icon: Icons.storage_outlined,
        title: 'Storage & Data',
        subtitle: 'Local data and cleanup controls',
        destination: StorageSettingsScreen(),
      ),
      _SettingItem(
        section: 'App',
        icon: Icons.notifications_none,
        title: 'Notifications',
        subtitle: 'Alerts, sounds, and vibration',
        destination: NotificationsSettingsScreen(),
      ),
      _SettingItem(
        section: 'App',
        icon: Icons.palette_outlined,
        title: 'Appearance',
        subtitle: 'Theme and visual preferences',
        destination: AppearanceSettingsScreen(),
      ),
      _SettingItem(
        section: 'App',
        icon: Icons.language,
        title: 'Language',
        subtitle: 'Application language',
        destination: LanguageSettingsScreen(),
      ),
      _SettingItem(
        section: 'App',
        icon: Icons.info_outline,
        title: 'About',
        subtitle: 'Version and legal info',
        destination: AboutScreen(),
      ),
    ];
  }

  Widget _buildMobileSettingsView(
    BuildContext context,
    List<_SettingItem> items,
  ) {
    final sections = <String, List<_SettingItem>>{};
    for (final item in items) {
      sections.putIfAbsent(item.section, () => []).add(item);
    }

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: sections.entries.expand((entry) {
          final header = [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
              child: Text(
                entry.key,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ];

          final tiles = entry.value
              .map((item) => _SettingsListTile(item: item))
              .toList();
          return [...header, ...tiles];
        }).toList(),
      ),
    );
  }

  Widget _buildLargeSettingsView(
    BuildContext context,
    List<_SettingItem> items,
    bool isTv,
  ) {
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            sliver: SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.5),
                      Theme.of(
                        context,
                      ).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                    ],
                  ),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 28,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isTv
                            ? 'Use D-pad arrows to move and OK/Enter to open.'
                            : 'Large-screen settings dashboard with quick access cards.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate((context, index) {
                final item = items[index];
                return _SettingsGridCard(
                  item: item,
                  autofocus: isTv && index == 0,
                );
              }, childCount: items.length),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isTv ? 3 : 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                mainAxisExtent: isTv ? 100 : 90,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsListTile extends StatelessWidget {
  final _SettingItem item;

  const _SettingsListTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${item.title}: ${item.subtitle}',
      button: true,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.icon,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          title: Text(
            item.title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(item.subtitle),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => _open(context, item.destination),
        ),
      ),
    );
  }
}

class _SettingsGridCard extends StatefulWidget {
  final _SettingItem item;
  final bool autofocus;

  const _SettingsGridCard({required this.item, this.autofocus = false});

  @override
  State<_SettingsGridCard> createState() => _SettingsGridCardState();
}

class _SettingsGridCardState extends State<_SettingsGridCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Actions(
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _open(context, widget.item.destination);
            return null;
          },
        ),
      },
      child: FocusableActionDetector(
        autofocus: widget.autofocus,
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.surface,
                theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.35,
                ),
              ],
            ),
            border: Border.all(
              color: _focused
                  ? theme.colorScheme.primary
                  : theme.dividerColor.withValues(alpha: 0.35),
              width: _focused ? 2.0 : 1.0,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.22),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : const [],
          ),
          child: Semantics(
            label: '${widget.item.title}: ${widget.item.subtitle}',
            button: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _open(context, widget.item.destination),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.14,
                        ),
                      ),
                      child: Icon(
                        widget.item.icon,
                        color: theme.colorScheme.primary,
                      ),
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
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
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
        ),
      ),
    );
  }
}

void _open(BuildContext context, Widget destination) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => destination));
}

class _SettingItem {
  final String section;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget destination;

  const _SettingItem({
    required this.section,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.destination,
  });
}
