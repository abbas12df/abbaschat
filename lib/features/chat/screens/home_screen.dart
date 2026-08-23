import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/responsive_utils.dart';
import '../../../core/widgets/connection_status_bar.dart';
import '../../ai_assistant/screens/ai_chat_screen.dart';
import '../../ai_assistant/screens/image_generator_screen.dart';
import '../../ai_assistant/screens/qwen_chat_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../models/chat_room.dart';
import '../models/user_model.dart';
import '../repositories/chat_repository.dart';
import '../widgets/avatar_with_presence.dart';
import '../widgets/chat_list_skeleton.dart';
import '../widgets/message_preview.dart';
import '../widgets/unread_badge.dart';
import 'chat_screen.dart';
import 'create_group_screen.dart';
import 'search_user_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _channelsScrollController = ScrollController();
  final TextEditingController _mobileSearchController = TextEditingController();
  int _selectedChannelIndex = 0;
  String _mobileSearchQuery = '';
  String _selectedMobileCategory = _mobileAllCategory;

  static const String _mobileAllCategory = '__all__';
  static const String _mobileDirectCategory = 'Direct chats';
  static const String _mobileUncategorized = 'Uncategorized';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _channelsScrollController.dispose();
    _mobileSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatsAsync = ref.watch(userChatsProvider);
    final isLargeScreen = ResponsiveUtils.isLargeScreen(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/app_logo_transparent.png',
              width: 28,
              height: 28,
              errorBuilder: (_, __, ___) => Icon(
                Icons.shield_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Nisaba'),
          ],
        ),
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: InkWell(
            onTap: () => _push(const ProfileScreen()),
            borderRadius: BorderRadius.circular(40),
            child: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              child: Icon(
                Icons.person,
                color: Theme.of(context).colorScheme.onSecondary,
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'البحث عن مستخدمين',
            onPressed: () => _push(const SearchUserScreen()),
          ),
          if (isLargeScreen)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'الإعدادات',
              onPressed: () => _push(const SettingsScreen()),
            ),
          if (isLargeScreen)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'إنشاء جديد',
              onPressed: () => _showCreateMenu(preferDialog: true),
            ),
        ],
      ),
      body: Column(
        children: [
          const ConnectionStatusBar(),
          Expanded(
            child: chatsAsync.when(
              data: (chats) {
                if (chats.isEmpty) {
                  return _buildEmptyState();
                }

                if (isLargeScreen) {
                  return _buildLargeScreenHub(chats);
                }

                return _buildMobileChannelList(chats);
              },
              error: (err, stack) => _AutoRetryErrorWidget(
                onRetry: () => ref.invalidate(userChatsProvider),
              ),
              loading: () => const ChatListSkeleton(),
            ),
          ),
        ],
      ),
      floatingActionButton: isLargeScreen
          ? null
          : FloatingActionButton(
              onPressed: () => _showCreateMenu(preferDialog: false),
              child: const Icon(Icons.add_comment_rounded),
            ).animate().scale(delay: 350.ms),
    );
  }

  Widget _buildLargeScreenHub(List<ChatRoom> chats) {
    final theme = Theme.of(context);
    final isTv = ResponsiveUtils.isTv(context);
    final selectedIndex = _normalizedIndex(chats.length);
    final selectedChat = chats[selectedIndex];

    final hub = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surface,
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
          ],
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: isTv ? 460 : 420,
            child: Column(
              children: [
                if (isTv)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.5,
                    ),
                    child: Text(
                      'استخدم الأسهم للتنقل واضغط موافق للفتح.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    controller: _channelsScrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    itemCount: chats.length,
                    itemBuilder: (context, index) {
                      return _buildAdaptiveChatTile(
                        chat: chats[index],
                        index: index,
                        isLargeScreen: true,
                        selectedIndex: selectedIndex,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: theme.dividerColor.withValues(alpha: 0.4),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
              child: _buildSelectedChannelPanel(selectedChat),
            ),
          ),
        ],
      ),
    );

    if (!isTv) return hub;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _moveSelection(chats, 1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            _moveSelection(chats, -1),
        const SingleActivator(LogicalKeyboardKey.enter): () =>
            _openChatByIndex(chats, selectedIndex),
        const SingleActivator(LogicalKeyboardKey.select): () =>
            _openChatByIndex(chats, selectedIndex),
        const SingleActivator(LogicalKeyboardKey.gameButtonA): () =>
            _openChatByIndex(chats, selectedIndex),
        const SingleActivator(LogicalKeyboardKey.contextMenu): () =>
            _showCreateMenu(preferDialog: true),
      },
      child: Focus(autofocus: true, child: hub),
    );
  }

  Widget _buildSelectedChannelPanel(ChatRoom selectedChat) {
    final otherUserId = _resolveOtherUserId(selectedChat);

    return FutureBuilder<UserModel?>(
      future: selectedChat.isGroup
          ? Future<UserModel?>.value(null)
          : ref.read(chatRepositoryProvider).getUserData(otherUserId),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final channelName = selectedChat.isGroup
            ? (selectedChat.groupName ?? 'مجموعة')
            : (user?.displayName ?? 'جهة اتصال');
        final channelSubtitle = selectedChat.isGroup
            ? 'قناة مجموعة'
            : (user?.username != null ? '@${user!.username}' : 'محادثة مباشرة');
        final unreadCount =
            selectedChat.unreadCounts[FirebaseAuth.instance.currentUser?.uid] ??
            0;

        return Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AvatarWithPresence(
                      imageUrl: selectedChat.isGroup
                          ? selectedChat.groupIcon
                          : user?.photoURL,
                      fallbackText: channelName,
                      isGroup: selectedChat.isGroup,
                      radius: 34,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            channelName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            channelSubtitle,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    if (unreadCount > 0) UnreadBadge(count: unreadCount),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'آخر رسالة',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: MessagePreview(
                    content: selectedChat.lastMessage,
                    isUnread: unreadCount > 0,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(selectedChat.lastMessageTime),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  'إجراءات سريعة',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildQuickActionChip(
                      icon: Icons.open_in_new_rounded,
                      label: 'فتح المحادثة',
                      onTap: () => _openChat(selectedChat),
                    ),
                    _buildQuickActionChip(
                      icon: Icons.person_search_rounded,
                      label: 'البحث عن مستخدم',
                      onTap: () => _push(const SearchUserScreen()),
                    ),
                    _buildQuickActionChip(
                      icon: Icons.group_add_rounded,
                      label: 'مجموعة جديدة',
                      onTap: () => _push(const CreateGroupScreen()),
                    ),
                    _buildQuickActionChip(
                      icon: Icons.smart_toy_rounded,
                      label: 'مساعد ذكي',
                      onTap: () => _push(const AiChatScreen()),
                    ),
                    _buildQuickActionChip(
                      icon: Icons.auto_awesome_rounded,
                      label: 'محادثة Qwen',
                      onTap: () => _push(const QwenChatScreen()),
                    ),
                    _buildQuickActionChip(
                      icon: Icons.image_outlined,
                      label: 'توليد صورة',
                      onTap: () => _push(const ImageGeneratorScreen()),
                    ),
                    _buildQuickActionChip(
                      icon: Icons.settings_outlined,
                      label: 'الإعدادات',
                      onTap: () => _push(const SettingsScreen()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
            width: 2.0,
          ),
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileChannelList(List<ChatRoom> chats) {
    final availableCategories = _extractAvailableMobileCategories(chats);
    final sections = _buildMobileSections(chats);
    final visibleCount = sections.fold<int>(
      0,
      (sum, section) => sum + section.chats.length,
    );

    if (_selectedMobileCategory != _mobileAllCategory &&
        !availableCategories.contains(_selectedMobileCategory)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedMobileCategory = _mobileAllCategory);
      });
    }

    final originalIndexes = <String, int>{};
    for (int i = 0; i < chats.length; i++) {
      originalIndexes[chats[i].id] = i;
    }

    return Column(
      children: [
        _buildMobileFiltersBar(
          availableCategories: availableCategories,
          visibleCount: visibleCount,
        ),
        Expanded(
          child: sections.isEmpty
              ? _buildMobileNoResultsState()
              : CustomScrollView(
                  slivers: [
                    for (final section in sections) ...[
                      SliverToBoxAdapter(
                        child: _buildMobileSectionHeader(
                          section.title,
                          section.chats.length,
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final chat = section.chats[index];
                          return _buildAdaptiveChatTile(
                            chat: chat,
                            index: originalIndexes[chat.id] ?? index,
                            isLargeScreen: false,
                            selectedIndex: 0,
                          );
                        }, childCount: section.chats.length),
                      ),
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildMobileFiltersBar({
    required List<String> availableCategories,
    required int visibleCount,
  }) {
    final theme = Theme.of(context);
    final chips = [_mobileAllCategory, ...availableCategories];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.35)),
        ),
      ),
      child: Column(
        children: [
          TextField(
            controller: _mobileSearchController,
            onChanged: _onMobileSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'ابحث في المحادثات أو التصنيفات',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _mobileSearchQuery.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _mobileSearchController.clear();
                        _onMobileSearchChanged('');
                      },
                    ),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: chips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = chips[index];
                final selected = _selectedMobileCategory == category;
                return ChoiceChip(
                  label: Text(
                    _mobileCategoryLabel(category),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _selectedMobileCategory = category);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '$visibleCount محادثات',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileNoResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_alt_off_rounded,
              size: 52,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'لا توجد محادثات تطابق البحث',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'جرّب مسح البحث أو اختيار تصنيف آخر.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileSectionHeader(String title, int count) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _mobileCategoryLabel(title),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$count',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  List<String> _extractAvailableMobileCategories(List<ChatRoom> chats) {
    final categories = chats.map(_mobileCategoryForChat).toSet().toList()
      ..sort(_sortMobileCategories);
    return categories;
  }

  List<_MobileSection> _buildMobileSections(List<ChatRoom> chats) {
    final grouped = <String, List<ChatRoom>>{};
    for (final chat in chats) {
      if (!_matchesMobileFilters(chat)) continue;
      final category = _mobileCategoryForChat(chat);
      grouped.putIfAbsent(category, () => <ChatRoom>[]).add(chat);
    }

    final titles = grouped.keys.toList()..sort(_sortMobileCategories);
    return titles
        .map((title) => _MobileSection(title: title, chats: grouped[title]!))
        .toList();
  }

  bool _matchesMobileFilters(ChatRoom chat) {
    final category = _mobileCategoryForChat(chat);
    if (_selectedMobileCategory != _mobileAllCategory &&
        category != _selectedMobileCategory) {
      return false;
    }

    final query = _mobileSearchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;

    return _mobileSearchableText(chat).contains(query);
  }

  String _mobileCategoryForChat(ChatRoom chat) {
    if (!chat.isGroup) return _mobileDirectCategory;
    return _normalizedMetaValue(chat.category) ??
        _normalizedMetaValue(chat.source) ??
        _mobileUncategorized;
  }

  String _mobileCategoryLabel(String category) {
    if (category == _mobileAllCategory) return 'الكل';
    if (category == _mobileDirectCategory) return 'محادثات مباشرة';
    if (category == _mobileUncategorized) return 'غير مصنفة';
    return category;
  }

  String _mobileSearchableText(ChatRoom chat) {
    final fields = <String>[
      chat.groupName ?? '',
      chat.lastMessage,
      chat.id,
      _mobileCategoryForChat(chat),
      chat.category ?? '',
      chat.source ?? '',
    ];
    return fields.join(' ').toLowerCase();
  }

  String? _normalizedMetaValue(String? value) {
    if (value == null) return null;
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  int _sortMobileCategories(String a, String b) {
    if (a == _mobileDirectCategory && b != _mobileDirectCategory) return -1;
    if (b == _mobileDirectCategory && a != _mobileDirectCategory) return 1;
    if (a == _mobileUncategorized && b != _mobileUncategorized) return 1;
    if (b == _mobileUncategorized && a != _mobileUncategorized) return -1;
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  void _onMobileSearchChanged(String value) {
    final normalized = value.trim();
    if (_mobileSearchQuery == normalized) return;
    setState(() => _mobileSearchQuery = normalized);
  }

  Widget _buildAdaptiveChatTile({
    required ChatRoom chat,
    required int index,
    required bool isLargeScreen,
    required int selectedIndex,
  }) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final unreadCount = chat.unreadCounts[currentUserId] ?? 0;

    if (chat.isGroup) {
      final groupName = chat.groupName ?? 'مجموعة';
      final groupIcon = chat.groupIcon;

      return _buildTileShell(
        chat: chat,
        index: index,
        isLargeScreen: isLargeScreen,
        selectedIndex: selectedIndex,
        unreadCount: unreadCount,
        displayName: groupName,
        messagePreview: chat.lastMessage,
        avatar: AvatarWithPresence(
          imageUrl: groupIcon,
          fallbackText: groupName,
          isGroup: true,
          radius: isLargeScreen ? 30 : 28,
        ),
      );
    }

    final otherUserId = _resolveOtherUserId(chat);

    return FutureBuilder<UserModel?>(
      future: ref.read(chatRepositoryProvider).getUserData(otherUserId),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final displayName = user?.displayName ?? 'مستخدم';

        return StreamBuilder<Map<String, dynamic>>(
          stream: ref
              .watch(chatRepositoryProvider)
              .getUserPresence(otherUserId),
          builder: (context, presenceSnapshot) {
            final isOnline = presenceSnapshot.data?['state'] == 'online';

            final theme = Theme.of(context);
            return _buildTileShell(
              chat: chat,
              index: index,
              isLargeScreen: isLargeScreen,
              selectedIndex: selectedIndex,
              unreadCount: unreadCount,
              displayName: displayName,
              messagePreview: chat.lastMessage,
              avatar: AvatarWithPresence(
                imageUrl: user?.photoURL,
                fallbackText: displayName,
                backgroundColor: index.isEven
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.secondaryContainer,
                isOnline: isOnline,
                radius: isLargeScreen ? 30 : 28,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTileShell({
    required ChatRoom chat,
    required int index,
    required bool isLargeScreen,
    required int selectedIndex,
    required int unreadCount,
    required String displayName,
    required String messagePreview,
    required Widget avatar,
  }) {
    final bool isSelected = isLargeScreen && selectedIndex == index;
    final theme = Theme.of(context);

    final tile = Column(
      children: [
        Material(
          color: isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
              : Colors.transparent,
          child: InkWell(
            onTap: () => _openChat(chat),
            onHover: isLargeScreen
                ? (hovering) {
                    if (hovering) {
                      setState(() => _selectedChannelIndex = index);
                    }
                  }
                : null,
            onFocusChange: isLargeScreen
                ? (focused) {
                    if (focused) {
                      setState(() => _selectedChannelIndex = index);
                    }
                  }
                : null,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isLargeScreen ? 16 : 20,
                vertical: 14,
              ),
              child: Row(
                children: [
                  avatar,
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        MessagePreview(
                          content: messagePreview,
                          isUnread: unreadCount > 0,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatTime(chat.lastMessageTime),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      if (unreadCount > 0)
                        UnreadBadge(count: unreadCount)
                      else
                        const SizedBox(height: 24),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isLargeScreen)
          Divider(indent: 76, color: theme.dividerColor, height: 0.5),
      ],
    );

    if (isLargeScreen) return tile;

    return Dismissible(
      key: Key(chat.id),
      direction: DismissDirection.endToStart,
      background: _buildDismissBackground(context),
      confirmDismiss: (_) =>
          _confirmDelete(context, ref, chat.id, chat.isGroup),
      onDismissed: (_) {
        ref.read(chatRepositoryProvider).deleteChat(chat.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              chat.isGroup ? 'تمت إزالة المجموعة' : 'تمت إزالة المحادثة',
            ),
          ),
        );
      },
      child: tile,
    );
  }

  Widget _buildDismissBackground(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      color: Theme.of(context).colorScheme.error,
      child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onError),
    );
  }

  Future<bool?> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String roomId,
    bool isGroup,
  ) async {
    if (isGroup) {
      return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('مغادرة المجموعة؟'),
          content: const Text(
            'سيؤدي ذلك إلى إزالة النسخة المحلية ومغادرة المجموعة إذا كنت لا تزال عضوًا فيها.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () async {
                await ref.read(chatRepositoryProvider).leaveGroup(roomId);
                if (ctx.mounted) Navigator.of(ctx).pop(true);
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('مغادرة وحذف'),
            ),
          ],
        ),
      );
    }

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            const Text(
              'حذف المحادثة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'يمكنك حذف المحادثة من جهازك فقط أو حذفها من الطرفين.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop('me'),
                    child: const Text('حذف من جهازي'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop('everyone'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                child: const Text('حذف من الطرفين'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('cancel'),
              child: const Text('إلغاء'),
            ),
          ],
        ),
      ),
    );

    if (result == 'me') {
      return true;
    }

    if (result == 'everyone') {
      if (context.mounted) {
        await _deleteForEveryone(context, ref, roomId);
      }
    }

    return false;
  }

  Future<void> _deleteForEveryone(
    BuildContext context,
    WidgetRef ref,
    String roomId,
  ) async {
    try {
      await ref
          .read(chatRepositoryProvider)
          .deleteConversationForEveryone(roomId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف المحادثة من الطرفين')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر الحذف من الطرفين: $e')));
      }
    }
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primaryContainer,
                              theme.colorScheme.secondaryContainer,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.forum_outlined,
                          size: 54,
                          color: theme.colorScheme.primary,
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 500.ms)
                      .scale(delay: 120.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 24),
                  Text(
                    'لا توجد محادثات بعد',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ).animate().fadeIn(delay: 220.ms),
                  const SizedBox(height: 8),
                  Text(
                    'ابدأ محادثة آمنة أو أنشئ مجموعة للبدء.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ).animate().fadeIn(delay: 320.ms),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _push(const SearchUserScreen()),
                          icon: const Icon(Icons.person_add_outlined),
                          label: const Text('محادثة جديدة'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _push(const CreateGroupScreen()),
                          icon: const Icon(Icons.group_add_outlined),
                          label: const Text('مجموعة جديدة'),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 420.ms).slideY(begin: 0.2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateMenu({required bool preferDialog}) async {
    final actions = [
      _ActionEntry(
        icon: Icons.person_add_outlined,
        title: 'محادثة مباشرة',
        subtitle: 'ابحث عن مستخدم وابدأ محادثة آمنة',
        onTap: () => _push(const SearchUserScreen()),
      ),
      _ActionEntry(
        icon: Icons.group_add_outlined,
        title: 'إنشاء مجموعة',
        subtitle: 'أنشئ مجموعة جديدة للتواصل',
        onTap: () => _push(const CreateGroupScreen()),
      ),
      _ActionEntry(
        icon: Icons.smart_toy_rounded,
        title: 'مساعد الذكاء الاصطناعي',
        subtitle: 'افتح محادثة المساعد الذكي',
        onTap: () => _push(const AiChatScreen()),
      ),
      _ActionEntry(
        icon: Icons.auto_awesome,
        title: 'محادثة Qwen',
        subtitle: 'محادثة نصية وبصرية',
        onTap: () => _push(const QwenChatScreen()),
      ),
      _ActionEntry(
        icon: Icons.image_outlined,
        title: 'مولد الصور',
        subtitle: 'أنشئ صورًا باستخدام الذكاء الاصطناعي',
        onTap: () => _push(const ImageGeneratorScreen()),
      ),
    ];

    if (preferDialog) {
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('إنشاء جديد'),
            content: SizedBox(
              width: 520,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: actions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = actions[index];
                  return ListTile(
                    leading: Icon(item.icon),
                    title: Text(item.title),
                    subtitle: Text(item.subtitle),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      item.onTap();
                    },
                  );
                },
              ),
            ),
          );
        },
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: actions
                .map(
                  (item) => ListTile(
                    leading: Icon(item.icon),
                    title: Text(item.title),
                    subtitle: Text(item.subtitle),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      item.onTap();
                    },
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  Future<void> _openChatByIndex(List<ChatRoom> chats, int index) async {
    if (chats.isEmpty) return;
    final safeIndex = index.clamp(0, chats.length - 1).toInt();
    await _openChat(chats[safeIndex]);
  }

  Future<void> _openChat(ChatRoom chat) async {
    if (!mounted) return;

    if (chat.isGroup) {
      final groupName = chat.groupName ?? 'مجموعة';
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            userName: groupName,
            otherUserId: chat.id,
            isGroup: true,
          ),
        ),
      );
      return;
    }

    final otherUserId = _resolveOtherUserId(chat);
    final user = await ref
        .read(chatRepositoryProvider)
        .getUserData(otherUserId);
    final displayName = user?.displayName ?? 'مستخدم';

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          userName: displayName,
          otherUserId: otherUserId,
          isGroup: false,
        ),
      ),
    );
  }

  void _moveSelection(List<ChatRoom> chats, int delta) {
    if (chats.isEmpty) return;

    setState(() {
      final next = _selectedChannelIndex + delta;
      _selectedChannelIndex = next.clamp(0, chats.length - 1).toInt();
    });

    _scrollToSelection();
  }

  void _scrollToSelection() {
    if (!_channelsScrollController.hasClients) return;

    final itemExtent = ResponsiveUtils.isTv(context) ? 104.0 : 96.0;
    final target = _selectedChannelIndex * itemExtent;
    _channelsScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  int _normalizedIndex(int length) {
    if (length == 0) return 0;
    if (_selectedChannelIndex < 0) return 0;
    if (_selectedChannelIndex >= length) return length - 1;
    return _selectedChannelIndex;
  }

  String _resolveOtherUserId(ChatRoom chat) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    return chat.participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => 'غير معروف',
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (now.day == time.day &&
        now.month == time.month &&
        now.year == time.year) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    return '${time.day}/${time.month}';
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

class _MobileSection {
  final String title;
  final List<ChatRoom> chats;

  const _MobileSection({required this.title, required this.chats});
}

class _ActionEntry {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

class _AutoRetryErrorWidget extends StatefulWidget {
  final VoidCallback onRetry;

  const _AutoRetryErrorWidget({required this.onRetry});

  @override
  State<_AutoRetryErrorWidget> createState() => _AutoRetryErrorWidgetState();
}

class _AutoRetryErrorWidgetState extends State<_AutoRetryErrorWidget> {
  int _countdown = 3;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        widget.onRetry();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                      Icons.cloud_off_outlined,
                      size: 58,
                      color: theme.colorScheme.primary,
                    )
                    .animate(
                      onPlay: (controller) => controller.repeat(reverse: true),
                    )
                    .fadeIn(duration: 700.ms)
                    .fadeOut(duration: 700.ms),
                const SizedBox(height: 16),
                Text(
                  'تعذر تحميل المحادثات',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'سنعيد المحاولة تلقائيًا خلال $_countdown ثوانٍ.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    value: _countdown / 3,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 18),
                TextButton.icon(
                  onPressed: () {
                    _timer?.cancel();
                    widget.onRetry();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة المحاولة الآن'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
