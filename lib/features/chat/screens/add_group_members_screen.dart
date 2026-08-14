import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../repositories/chat_repository.dart';
import '../../contacts/repositories/contact_repository.dart';
import '../../contacts/screens/add_contact_screen.dart';
import '../../chat/models/user_model.dart';

class AddGroupMembersScreen extends ConsumerStatefulWidget {
  final String roomId;
  final List<String> currentMemberIds;

  const AddGroupMembersScreen({
    super.key,
    required this.roomId,
    required this.currentMemberIds,
  });

  @override
  ConsumerState<AddGroupMembersScreen> createState() =>
      _AddGroupMembersScreenState();
}

class _AddGroupMembersScreenState extends ConsumerState<AddGroupMembersScreen> {
  final _searchController = TextEditingController();
  final Set<String> _selectedUserIds = {};
  List<Map<String, dynamic>> _searchResults = [];
  List<UserModel> _contacts = [];
  bool _isLoading = false;
  bool _showContacts = true; // Show contacts by default
  bool _isLoadingContacts = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoadingContacts = true);
    try {
      final contacts = await ref
          .read(contactRepositoryProvider)
          .getContactsAsUsers();
      
      // Filter out current members
      final filteredContacts = contacts.where((contact) {
        return !widget.currentMemberIds.contains(contact.uid);
      }).toList();

      if (mounted) {
        setState(() {
          _contacts = filteredContacts;
          _isLoadingContacts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingContacts = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showContacts = true;
      });
      return;
    }
    setState(() => _showContacts = false);
    _performSearch(query);
  }

  Future<void> _performSearch(String query) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('displayName', isGreaterThanOrEqualTo: query)
        .where('displayName', isLessThan: query + 'z')
        .limit(20)
        .get();

    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (mounted) {
      setState(() {
        _searchResults = snapshot.docs
            .map((doc) => doc.data())
            .where(
              (data) =>
                  data['uid'] != currentUid &&
                  !widget.currentMemberIds.contains(
                    data['uid'],
                  ), // Filter existing members
            )
            .toList();
      });
    }
  }

  Future<void> _addMembers() async {
    if (_selectedUserIds.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await ref
          .read(chatRepositoryProvider)
          .addGroupMembers(widget.roomId, _selectedUserIds.toList());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إضافة الأعضاء بنجاح ✅')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة أعضاء'),
        actions: [
          TextButton(
            onPressed: (_isLoading || _selectedUserIds.isEmpty)
                ? null
                : _addMembers,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'إضافة (${_selectedUserIds.length})',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _selectedUserIds.isEmpty
                          ? theme.disabledColor
                          : primaryColor,
                    ),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'ابحث عن اسم أو اختر من جهات الاتصال...',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Tabs or Section Header
          if (_showContacts && _searchController.text.trim().isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.contacts,
                    size: 18,
                    color: theme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'جهات الاتصال (${_contacts.length})',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddContactScreen(),
                        ),
                      ).then((_) => _loadContacts());
                    },
                    icon: const Icon(Icons.person_add, size: 16),
                    label: const Text('إضافة'),
                  ),
                ],
              ),
            ),

          // Content
          Expanded(
            child: _showContacts && _searchController.text.trim().isEmpty
                ? _buildContactsList()
                : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsList() {
    if (_isLoadingContacts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_contacts.isEmpty) {
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
            const Text(
              'لا توجد جهات اتصال',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddContactScreen(),
                  ),
                ).then((_) => _loadContacts());
              },
              icon: const Icon(Icons.person_add),
              label: const Text('إضافة جهة اتصال'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _contacts.length,
      itemBuilder: (context, index) {
        final contact = _contacts[index];
        final isSelected = _selectedUserIds.contains(contact.uid);

        return ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundImage: _getImageProvider(contact.photoURL),
                child: contact.photoURL == null
                    ? Text(
                        contact.displayName[0].toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              if (contact.isOnline)
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
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            contact.displayName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            contact.username != null
                ? '@${contact.username}'
                : contact.bio ?? 'لا توجد حالة',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Checkbox(
            value: isSelected,
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedUserIds.add(contact.uid);
                } else {
                  _selectedUserIds.remove(contact.uid);
                }
              });
            },
          ),
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedUserIds.remove(contact.uid);
              } else {
                _selectedUserIds.add(contact.uid);
              }
            });
          },
        ).animate().fadeIn(delay: (index * 50).ms);
      },
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty && _searchController.text.trim().isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 60,
              color: Theme.of(context).iconTheme.color ?? Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'لا توجد نتائج',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final uid = user['uid'];
        final isSelected = _selectedUserIds.contains(uid);
        final isContact = _contacts.any((c) => c.uid == uid);

        return ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundImage: user['photoURL'] != null &&
                        (user['photoURL'] as String).startsWith('http')
                    ? NetworkImage(user['photoURL'])
                    : null,
                child: user['photoURL'] == null
                    ? Text(
                        (user['displayName'] ?? 'م')[0].toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              if (isContact)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.contacts,
                      color: Theme.of(context).primaryColor,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  user['displayName'] ?? 'مستخدم',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (isContact)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'جهة اتصال',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Text('@${user['username'] ?? ''}'),
          trailing: Checkbox(
            value: isSelected,
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedUserIds.add(uid);
                } else {
                  _selectedUserIds.remove(uid);
                }
              });
            },
          ),
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedUserIds.remove(uid);
              } else {
                _selectedUserIds.add(uid);
              }
            });
          },
        ).animate().fadeIn(delay: (index * 50).ms);
      },
    );
  }

  ImageProvider? _getImageProvider(String? url) {
    if (url == null || url.isEmpty) return null;
    try {
      if (url.startsWith('http')) {
        return NetworkImage(url);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
