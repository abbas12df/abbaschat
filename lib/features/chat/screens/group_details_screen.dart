import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import '../repositories/chat_repository.dart';
import '../models/chat_room.dart';
import '../models/user_model.dart';
import 'admin_settings_screen.dart';
import '../../../core/local/local_storage_service.dart';
import '../../profile/screens/user_profile_details_screen.dart';
import 'add_group_members_screen.dart';
import '../widgets/admin_permissions_dialog.dart';
import 'search_messages_screen.dart';

class GroupDetailsScreen extends ConsumerStatefulWidget {
  final String roomId;

  const GroupDetailsScreen({super.key, required this.roomId});

  @override
  ConsumerState<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends ConsumerState<GroupDetailsScreen> {
  bool _isEditing = false;
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  File? _newImageFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Force sync when entering details to ensure Admin list / Participants are fresh
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(chatRepositoryProvider)
          .validateGroupState(widget.roomId)
          .catchError((e) {
            print('GroupDetails Sync Error: $e');
          });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _updateGroupInfo() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .updateGroupInfo(
            widget.roomId,
            name: name,
            description: _descController.text.trim(),
            image: _newImageFile,
          );
      if (!mounted) return;
      setState(() {
        _isEditing = false;
        _newImageFile = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث معلومات المجموعه')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
    );
    if (picked != null) {
      setState(() => _newImageFile = File(picked.path));
    }
  }

  Future<void> _leaveGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مغادرة المجموعة؟'),
        content: const Text('هل أنت متأكد أنك تريد مغادرة هذه المجموعة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('مغادرة', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);

      // Fix Freeze: Pop all the way to the first route (Home) BEFORE deleting
      // This prevents ChatScreen from trying to read the deleted box
      Navigator.of(context).popUntil((route) => route.isFirst);

      await ref.read(chatRepositoryProvider).leaveGroup(widget.roomId);
    }
  }

  Future<void> _deleteGroupForEveryone() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المجموعة نهائياً؟'),
        content: const Text(
          'سيتم حذف المجموعة وجميع الرسائل لجميع الاعضاء. لا يمكن التراجع عن هذا الاجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف نهائي', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await ref
            .read(chatRepositoryProvider)
            .deleteGroupForEveryone(widget.roomId);
        if (mounted) {
          Navigator.pop(context); // Pop details
          Navigator.pop(context); // Pop chat
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = FirebaseAuth.instance.currentUser?.uid;
    final theme = Theme.of(context);
    final chatStream = ref.watch(chatRepositoryProvider).getUserChats();

    return StreamBuilder<List<ChatRoom>>(
      stream: chatStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final room = snapshot.data!.firstWhere(
          (r) => r.id == widget.roomId,
          orElse: () => ChatRoom(
            id: 'deleted',
            participants: [],
            lastMessage: '',
            lastMessageTime: DateTime.now(),
            unreadCounts: {},
          ),
        );

        if (room.id == 'deleted') return const SizedBox.shrink();

        final bool isCreator = myId != null && room.createdBy == myId;
        // Fallback for old groups: check if ID ends with myId (legacy deterministic ID)
        final bool isLegacyCreator =
            myId != null &&
            room.id.endsWith('_$myId') &&
            room.createdBy == null;

        final isOwner = isCreator || isLegacyCreator;
        final isAdmin = (room.admins?.contains(myId) ?? false) || isOwner;

        // --- Permissions Logic ---
        final permissionsMap =
            (room.adminPermissions as Map?)?.map(
              (key, value) =>
                  MapEntry(key.toString(), List<String>.from(value ?? [])),
            ) ??
            {};

        final myPerms = permissionsMap[myId] ?? [];

        final bool canEditInfo = isOwner || myPerms.contains('change_info');
        final bool canAddMembers = isOwner || myPerms.contains('add_members');
        final bool canRemoveMembers =
            isOwner || myPerms.contains('remove_members');
        final bool canManageAdmins =
            isOwner || myPerms.contains('manage_admins');

        // DEBUG: Print permission values
        print('DEBUG PERMISSIONS for user $myId:');
        print('  isOwner: $isOwner');
        print('  isAdmin: $isAdmin');
        print('  myPerms: $myPerms');
        print('  canEditInfo: $canEditInfo');
        print('  canAddMembers: $canAddMembers');
        print('  canRemoveMembers: $canRemoveMembers');
        print('  canManageAdmins: $canManageAdmins');
        print('  adminPermissions map: ${room.adminPermissions}');

        // Only show edit button if canEditInfo
        final showEditButton = canEditInfo;

        // Init controllers if switching to edit mode
        if (_isEditing &&
            _nameController.text.isEmpty &&
            (room.groupName?.isNotEmpty ?? false)) {
          _nameController.text = room.groupName ?? '';
          _descController.text = room.description ?? '';
        }

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // 1. Sliver App Bar with Image
              SliverAppBar(
                expandedHeight: 250.0,
                pinned: true,
                stretch: true,
                backgroundColor: theme.scaffoldBackgroundColor,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      _newImageFile != null
                          ? Image.file(_newImageFile!, fit: BoxFit.cover)
                          : (room.groupIcon != null
                                ? _buildHeaderImage(room.groupIcon!)
                                : Container(
                                    color: theme.primaryColor.withOpacity(0.1),
                                    child: Icon(
                                      Icons.groups,
                                      size: 80,
                                      color:
                                          theme.iconTheme.color?.withOpacity(
                                            0.5,
                                          ) ??
                                          Colors.grey,
                                    ),
                                  )),
                      // Gradient Overlay for text readability
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Theme.of(
                                context,
                              ).shadowColor.withValues(alpha: 0.7),
                            ],
                            stops: const [0.6, 1.0],
                          ),
                        ),
                      ),
                      if (_isEditing)
                        Center(
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                color: Theme.of(context).colorScheme.onPrimary,
                                size: 30,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                leading: IconButton(
                  icon: const ContainerWithShadow(
                    child: Icon(Icons.arrow_back),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  if (canEditInfo)
                    IconButton(
                      icon: ContainerWithShadow(
                        child: Icon(_isEditing ? Icons.check : Icons.edit),
                      ),
                      onPressed: () {
                        if (_isEditing) {
                          _updateGroupInfo();
                        } else {
                          setState(() {
                            _isEditing = true;
                            _nameController.text = room.groupName ?? '';
                            _descController.text = room.description ?? '';
                          });
                        }
                      },
                    ),
                ],
              ),

              // 2. Info & Actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Name & Description
                      if (_isEditing) ...[
                        TextField(
                          controller: _nameController,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'اسم المجموعة',
                            border: UnderlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _descController,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'وصف المجموعة',
                            border: UnderlineInputBorder(),
                          ),
                        ),
                      ] else ...[
                        Text(
                          room.groupName ?? 'مجموعة',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        // Beautiful Handle Card
                        if (room.groupHandle != null) ...[
                          const SizedBox(height: 12),
                          Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      theme.primaryColor.withOpacity(0.1),
                                      theme.primaryColor.withOpacity(0.05),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: theme.primaryColor.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.link,
                                          size: 18,
                                          color: theme.primaryColor,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'معرف المجموعة',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme
                                                .textTheme
                                                .bodySmall
                                                ?.color,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    SelectableText(
                                      '@${room.groupHandle}',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color:
                                            theme.brightness == Brightness.dark
                                            ? Colors.white
                                            : theme.primaryColor,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        // Copy Button
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () {
                                              Clipboard.setData(
                                                ClipboardData(
                                                  text: '@${room.groupHandle}',
                                                ),
                                              );
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: const Text(
                                                    'تم نسخ المعرف',
                                                  ),
                                                  duration: const Duration(
                                                    seconds: 2,
                                                  ),
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                  backgroundColor:
                                                      theme.primaryColor,
                                                ),
                                              );
                                            },
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: theme.primaryColor
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.copy,
                                                    size: 16,
                                                    color: theme.primaryColor,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'نسخ',
                                                    style: TextStyle(
                                                      color: theme.primaryColor,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Share Button
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () {
                                              final link =
                                                  'https://qqqq.app/join/@${room.groupHandle}';
                                              final message =
                                                  'انضم إلى مجموعة "${room.groupName}" على تطبيق qqqq:\n$link';

                                              // Use share_plus package
                                              Share.share(
                                                message,
                                                subject:
                                                    'دعوة للانضمام إلى ${room.groupName}',
                                              );
                                            },
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: theme.primaryColor,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.share,
                                                    size: 16,
                                                    color: theme
                                                        .colorScheme
                                                        .onPrimary,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'مشاركة',
                                                    style: TextStyle(
                                                      color: theme
                                                          .colorScheme
                                                          .onPrimary,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              )
                              .animate()
                              .fadeIn(duration: 300.ms)
                              .slideY(begin: 0.2, end: 0, duration: 300.ms),
                        ],

                        if (room.description != null &&
                            room.description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              room.description!,
                              style: TextStyle(
                                fontSize: 15,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Theme.of(context).iconTheme.color,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          '${room.participants.length} مشترك',
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey.shade400
                                : Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Quick Actions Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Builder(
                            builder: (context) {
                              final isMuted =
                                  myId != null &&
                                  (ref
                                          .watch(
                                            chatMuteProvider((
                                              userId: myId,
                                              roomId: widget.roomId,
                                            )),
                                          )
                                          .value ??
                                      ref
                                          .read(localStorageServiceProvider)
                                          .isMuted(myId, widget.roomId));
                              return _buildQuickAction(
                                icon: isMuted
                                    ? Icons.notifications_off
                                    : Icons.notifications_active,
                                label: isMuted ? 'مكتوم' : 'تنبيهات',
                                onTap: () async {
                                  if (myId == null) return;
                                  await ref
                                      .read(chatRepositoryProvider)
                                      .toggleMute(widget.roomId, !isMuted);
                                },
                                color: isMuted
                                    ? Colors.orange
                                    : theme.iconTheme.color ??
                                          theme.primaryColor,
                              );
                            },
                          ),
                          if (canAddMembers)
                            _buildQuickAction(
                              icon: Icons.person_add,
                              label: 'إضافة',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddGroupMembersScreen(
                                      roomId: widget.roomId,
                                      currentMemberIds: room.participants,
                                    ),
                                  ),
                                );
                              },
                              color: Colors.blue,
                            ),
                          _buildQuickAction(
                            icon: Icons.search,
                            label: 'بحث',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SearchMessagesScreen(
                                    roomId: widget.roomId,
                                  ),
                                ),
                              );
                            },
                            color:
                                Theme.of(context).iconTheme.color ??
                                Colors.grey,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Settings Groups
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      if (isAdmin) ...[
                        _buildSettingsGroup(
                          title: 'الإدارة',
                          children: [
                            _buildSettingTile(
                              icon: Icons.admin_panel_settings,
                              title: 'إعدادات المشرف',
                              subtitle: 'الأذونات والخصوصية',
                              trailing: Badge(
                                label: Text('${room.pendingRequests.length}'),
                                isLabelVisible: room.pendingRequests.isNotEmpty,
                                child: Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Theme.of(context).iconTheme.color,
                                ),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        AdminSettingsScreen(room: room),
                                  ),
                                ).then((_) => setState(() {}));
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],

                      _buildSettingsGroup(
                        title: 'التشفير والخصوصية',
                        children: [
                          _buildSettingTile(
                            icon: Icons.lock,
                            title: 'مشفرة طرفاً لطرف',
                            subtitle: 'الرسائل والمكالمات محمية',
                            trailing: const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 20,
                            ),
                            onTap: null, // Info dialog?
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // 4. Members List Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'الأعضاء',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                      Text(
                        '${room.participants.length}',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 5. Members List
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final uid = room.participants[index];
                  return FutureBuilder<UserModel?>(
                    future: ref.read(chatRepositoryProvider).getUserData(uid),
                    builder: (context, snap) {
                      final user = snap.data;
                      final isUserAdmin =
                          (room.admins?.contains(uid) ?? false) ||
                          (room.id.endsWith('_$uid'));
                      final isMe = uid == myId;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundImage: _getImageProvider(user?.photoURL),
                          child: user?.photoURL == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(
                          isMe ? 'أنت' : (user?.displayName ?? 'مستخدم'),
                        ),
                        subtitle: Text(
                          (room.createdBy == uid ||
                                  (room.createdBy == null &&
                                      room.id.endsWith('_$uid')))
                              ? 'المالك'
                              : (isUserAdmin ? 'مشرف' : (user?.bio ?? '')),
                          style: TextStyle(
                            color:
                                isUserAdmin ||
                                    (room.createdBy == uid ||
                                        (room.createdBy == null &&
                                            room.id.endsWith('_$uid')))
                                ? Colors.blue
                                : Theme.of(context).iconTheme.color ??
                                      Colors.grey,
                            fontWeight: isUserAdmin ? FontWeight.bold : null,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: (isAdmin && !isMe)
                            ? PopupMenuButton(
                                icon: Icon(
                                  Icons.more_vert,
                                  color: Theme.of(context).iconTheme.color,
                                ),
                                itemBuilder: (context) {
                                  final List<PopupMenuItem> items = [];

                                  // 1. MANAGE ADMINS (Promote/Demote)
                                  if (canManageAdmins) {
                                    if (isUserAdmin) {
                                      // Can only demote if I am Owner OR (I am Admin AND target is NOT Owner)
                                      // Actually, usually Admins can't demote other Admins unless they are Owner/Higher.
                                      // Let's stick to Owner can demote anyone. Admins can't demote other admins easily without hierarchy.
                                      // Simplified: Only Owner can Demote/Edit Perms of Admins?
                                      // Or "manage_admins" allows promoting normal users.
                                      // Let's say: Manage Admins allow Promote.
                                      // Only Owner can Demote or Edit Perms.
                                      if (isOwner) {
                                        items.add(
                                          PopupMenuItem(
                                            value: 'permissions',
                                            child: const Text('صلاحيات المشرف'),
                                            onTap: () {
                                              // Show Dialog
                                              Future.delayed(
                                                Duration.zero,
                                                () => _showPermissionsDialog(
                                                  uid,
                                                  user?.displayName ?? 'مشرف',
                                                  permissionsMap[uid] ?? [],
                                                ),
                                              );
                                            },
                                          ),
                                        );
                                        items.add(
                                          PopupMenuItem(
                                            value: 'demote',
                                            child: const Text('إلغاء الإشراف'),
                                            onTap: () async {
                                              await ref
                                                  .read(chatRepositoryProvider)
                                                  .demoteAdmin(
                                                    widget.roomId,
                                                    uid,
                                                  );
                                            },
                                          ),
                                        );
                                      }
                                    } else {
                                      // Promote
                                      items.add(
                                        PopupMenuItem(
                                          value: 'promote',
                                          child: const Text('تعيين مشرف'),
                                          onTap: () async {
                                            await ref
                                                .read(chatRepositoryProvider)
                                                .promoteAdmin(
                                                  widget.roomId,
                                                  uid,
                                                );
                                          },
                                        ),
                                      );
                                    }
                                  }

                                  // 2. REMOVE MEMBER
                                  // Can remove if canRemoveMembers AND target is not Owner
                                  // Also prevent removing other Admins if I am just an Admin? (Usually yes)
                                  final isTargetOwner =
                                      room.createdBy != null &&
                                      room.createdBy == uid;

                                  if (canRemoveMembers && !isTargetOwner) {
                                    // If target is Admin, only Owner can remove them?
                                    if (isUserAdmin && !isOwner) {
                                      // Skip
                                    } else {
                                      items.add(
                                        PopupMenuItem(
                                          value: 'remove',
                                          child: const Text(
                                            'إزالة من المجموعة',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                          onTap: () async {
                                            await ref
                                                .read(chatRepositoryProvider)
                                                .removeGroupMember(
                                                  widget.roomId,
                                                  uid,
                                                );
                                          },
                                        ),
                                      );
                                    }
                                  }

                                  return items;
                                },
                              )
                            : null,
                        onTap: () {
                          if (!isMe) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    UserProfileDetailsScreen(userId: uid),
                              ),
                            );
                          }
                        },
                      );
                    },
                  );
                }, childCount: room.participants.length),
              ),

              // 6. Leave / Delete Group (Footer)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      if (isOwner)
                        TextButton.icon(
                          onPressed: _deleteGroupForEveryone,
                          icon: const Icon(
                            Icons.delete_forever,
                            color: Colors.red,
                          ),
                          label: const Text(
                            'حذف المجموعة نهائياً',
                            style: TextStyle(color: Colors.red, fontSize: 16),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                            backgroundColor: Colors.red.withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        )
                      else
                        TextButton.icon(
                          onPressed: _leaveGroup,
                          icon: const Icon(
                            Icons.exit_to_app,
                            color: Colors.red,
                          ),
                          label: const Text(
                            'مغادرة المجموعة',
                            style: TextStyle(color: Colors.red, fontSize: 16),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                            backgroundColor: Colors.red.withOpacity(0.05),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
            ],
          ),
        );
      },
    );
  }

  // --- Helpers ---

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildSettingsGroup({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              color: Theme.of(context).iconTheme.color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.blue, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            )
          : null,
      trailing: trailing,
      onTap: onTap,
    );
  }

  ImageProvider? _getImageProvider(String? photoURL) {
    if (photoURL == null || photoURL.isEmpty) return null;
    if (photoURL.startsWith('http')) return NetworkImage(photoURL);
    try {
      return MemoryImage(base64Decode(photoURL));
    } catch (_) {
      return null;
    }
  }

  Widget _buildHeaderImage(String photoURL) {
    if (photoURL.startsWith('http')) {
      return Image.network(photoURL, fit: BoxFit.cover);
    }
    try {
      return Image.memory(base64Decode(photoURL), fit: BoxFit.cover);
    } catch (_) {
      return const SizedBox();
    }
  }

  void _showPermissionsDialog(
    String adminId,
    String adminName,
    List<String> currentPerms,
  ) {
    showDialog(
      context: context,
      builder: (context) => AdminPermissionsDialog(
        adminName: adminName,
        currentPermissions: currentPerms,
        onSave: (newPerms) async {
          await ref
              .read(chatRepositoryProvider)
              .updateAdminPermissions(widget.roomId, adminId, newPerms);
          if (mounted) setState(() {});
        },
      ),
    );
  }
}

class ContainerWithShadow extends StatelessWidget {
  final Widget child;
  const ContainerWithShadow({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).shadowColor.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: child,
    );
  }
}
