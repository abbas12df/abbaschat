import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:convert';
import '../../chat/screens/chat_screen.dart';
import '../../chat/screens/add_group_members_screen.dart';
import '../../chat/repositories/chat_repository.dart';
import '../../chat/models/chat_room.dart';
import '../../profile/screens/user_profile_details_screen.dart';
import '../repositories/contact_repository.dart';
import 'add_contact_screen.dart';
import 'edit_contact_screen.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(
        () => _searchQuery = _searchController.text.trim().toLowerCase(),
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Fetch Contacts Stream
    final contactStream = StreamBuilder<List<Contact>>(
      stream: ref.watch(contactRepositoryProvider).watchContacts(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(child: Text('خطأ: ${snapshot.error}'));
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        var contacts = snapshot.data!;

        // 2. Local Filter
        if (_searchQuery.isNotEmpty) {
          contacts = contacts.where((c) {
            final name = c.displayName.toLowerCase();
            final phone = c.user.phoneNumber?.toLowerCase() ?? '';
            final username = c.user.username?.toLowerCase() ?? '';
            return name.contains(_searchQuery) ||
                phone.contains(_searchQuery) ||
                username.contains(_searchQuery);
          }).toList();
        }

        if (contacts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 60,
                  color: Theme.of(context).iconTheme.color ?? Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty
                      ? 'لا توجد جهات اتصال بعد'
                      : 'لا توجد نتائج',
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                ),
                if (_searchQuery.isEmpty)
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddContactScreen(),
                      ),
                    ),
                    child: const Text('إضافة جهة اتصال جديدة'),
                  ),
              ],
            ),
          );
        }

        // Group contacts by group name
        final groupedContacts = <String, List<Contact>>{};
        final ungroupedContacts = <Contact>[];

        for (final contact in contacts) {
          if (contact.group != null && contact.group!.isNotEmpty) {
            if (!groupedContacts.containsKey(contact.group)) {
              groupedContacts[contact.group!] = [];
            }
            groupedContacts[contact.group!]!.add(contact);
          } else {
            ungroupedContacts.add(contact);
          }
        }

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            // Grouped contacts
            ...groupedContacts.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.group,
                          size: 16,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          entry.key,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${entry.value.length})',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...entry.value.map((contact) => _buildContactTile(contact)),
                ],
              );
            }),

            // Ungrouped contacts header
            if (ungroupedContacts.isNotEmpty && groupedContacts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person,
                      size: 16,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'أخرى',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

            // Ungrouped contacts
            ...ungroupedContacts.map((contact) => _buildContactTile(contact)),
          ],
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('جهات الاتصال'),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'بحث في جهات الاتصال...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: contactStream,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddContactScreen()),
        ).then((_) {
          // Refresh contacts if needed
          setState(() {});
        }),
        icon: const Icon(Icons.person_add),
        label: const Text('إضافة جهة اتصال'),
      ),
    );
  }

  Widget _buildContactTile(Contact contact) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: _getImageProvider(contact.user.photoURL),
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              child: contact.user.photoURL == null
                  ? Text(
                      contact.displayName[0].toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Theme.of(context).primaryColor,
                      ),
                    )
                  : null,
            ),
            if (contact.user.isOnline)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.circle,
                    color: Colors.green,
                    size: 14,
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                contact.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (contact.user.isOnline)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'متصل',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (contact.user.username != null)
              Text(
                '@${contact.user.username}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            if (contact.user.bio != null && contact.user.bio!.isNotEmpty)
              Text(
                contact.user.bio!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (contact.group != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  contact.group!,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Theme.of(context).iconTheme.color,
            ),
          ],
        ),
        onTap: () {
          // Navigate to Chat
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                userName: contact.displayName,
                otherUserId: contact.user.uid,
              ),
            ),
          );
        },
        onLongPress: () {
          // Show quick actions menu
          _showQuickActionsMenu(context, contact);
        },
      ),
    ).animate().fadeIn().slideX(begin: 0.1);
  }

  void _showQuickActionsMenu(BuildContext context, Contact contact) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundImage: _getImageProvider(contact.user.photoURL),
                    child: contact.user.photoURL == null
                        ? Text(
                            contact.displayName[0].toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contact.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (contact.user.username != null)
                          Text(
                            '@${contact.user.username}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Quick Actions
            _buildActionTile(
              context,
              icon: Icons.chat_bubble_outline,
              title: 'بدء محادثة',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      userName: contact.displayName,
                      otherUserId: contact.user.uid,
                    ),
                  ),
                );
              },
            ),
            _buildActionTile(
              context,
              icon: Icons.group_add,
              title: 'إضافة للمجموعة',
              onTap: () {
                Navigator.pop(ctx);
                _showAddToGroupDialog(context, contact);
              },
            ),
            _buildActionTile(
              context,
              icon: Icons.person_outline,
              title: 'عرض الملف الشخصي',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserProfileDetailsScreen(
                      userId: contact.user.uid,
                    ),
                  ),
                );
              },
            ),
            const Divider(),
            _buildActionTile(
              context,
              icon: Icons.edit,
              title: 'تعديل الاسم أو المجموعة',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditContactScreen(contact: contact),
                  ),
                );
              },
            ),
            _buildActionTile(
              context,
              icon: Icons.delete_outline,
              title: 'حذف جهة الاتصال',
              color: Colors.red,
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, contact);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? Theme.of(context).iconTheme.color),
      title: Text(
        title,
        style: TextStyle(color: color),
      ),
      onTap: onTap,
    );
  }

  Future<void> _showAddToGroupDialog(
    BuildContext context,
    Contact contact,
  ) async {
    // Get user's groups
    final chatRepo = ref.read(chatRepositoryProvider);
    final chatsStream = chatRepo.getUserChats();
    
    showDialog(
      context: context,
      builder: (ctx) => StreamBuilder<List<ChatRoom>>(
        stream: chatsStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const AlertDialog(
              content: Center(child: CircularProgressIndicator()),
            );
          }

          final groups = snapshot.data!
              .where((chat) => chat.isGroup && chat.id.startsWith('group_'))
              .toList();

          if (groups.isEmpty) {
            return AlertDialog(
              title: const Text('لا توجد مجموعات'),
              content: const Text('لا توجد مجموعات يمكن إضافة هذا المستخدم إليها'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('حسناً'),
                ),
              ],
            );
          }

          return AlertDialog(
            title: const Text('اختر المجموعة'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final group = groups[index];
                  final participants = group.participants;
                  final isAlreadyMember = participants.contains(contact.user.uid);
                  final groupName = group.groupName ?? 'مجموعة بدون اسم';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                      child: group.groupIcon != null
                          ? ClipOval(
                              child: Image.network(
                                group.groupIcon!,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Text(
                                  groupName[0].toUpperCase(),
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )
                          : Text(
                              groupName[0].toUpperCase(),
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    title: Text(groupName),
                    subtitle: Text('${participants.length} عضو'),
                    trailing: isAlreadyMember
                        ? const Icon(Icons.check, color: Colors.green)
                        : const Icon(Icons.arrow_forward_ios, size: 16),
                    enabled: !isAlreadyMember,
                    onTap: isAlreadyMember
                        ? null
                        : () async {
                            try {
                              await chatRepo.addGroupMembers(
                                group.id,
                                [contact.user.uid],
                              );
                              if (context.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'تم إضافة ${contact.displayName} إلى $groupName ✅',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('خطأ: $e')),
                                );
                              }
                            }
                          },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, Contact contact) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف جهة الاتصال؟'),
        content: Text(
          'هل أنت متأكد من حذف "${contact.displayName}" من جهات الاتصال؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              await ref
                  .read(contactRepositoryProvider)
                  .removeContact(contact.user.uid);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  ImageProvider? _getImageProvider(String? url) {
    if (url == null || url.isEmpty) return null;
    try {
      if (url.startsWith('http')) {
        return NetworkImage(url);
      } else {
        // Assume base64
        return MemoryImage(
          const Base64Decoder().convert(url),
        );
      }
    } catch (e) {
      return null;
    }
  }
}
