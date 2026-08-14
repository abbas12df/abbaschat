import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/chat_repository.dart';
import 'chat_screen.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController(); // Added
  final _searchController = TextEditingController();
  File? _imageFile;
  final Set<String> _selectedUserIds = {};

  // Search State
  List<Map<String, dynamic>> _searchResults = [];
  bool _isCreating = false;

  // New Options
  bool _isPublic = false;
  bool _onlyAdminsCanPost = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_searchController.text.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _performSearch(_searchController.text.trim());
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
            .where((data) => data['uid'] != currentUid)
            .toList();
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 70,
    );
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال اسم المجموعة')),
      );
      return;
    }
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار عضو واحد على الأقل')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final roomId = await ref
          .read(chatRepositoryProvider)
          .createGroup(
            name,
            _selectedUserIds.toList(),
            _imageFile,
            description: _descController.text.trim(),
            isPublic: _isPublic,
            onlyAdminsCanPost: _onlyAdminsCanPost,
          );

      if (mounted) {
        Navigator.pop(context); // Close create screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ChatScreen(userName: name, otherUserId: roomId, isGroup: true),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
      setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مجموعة جديدة'),
        actions: [
          TextButton(
            onPressed: _isCreating ? null : _createGroup,
            child: _isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'إنشاء',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Group Info Section
          Container(
            padding: const EdgeInsets.all(20),
            color: theme.cardColor,
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 35,
                            backgroundColor: theme.colorScheme.surfaceVariant,
                            backgroundImage: _imageFile != null
                                ? FileImage(_imageFile!)
                                : null,
                            child: _imageFile == null
                                ? Icon(
                                    Icons.camera_alt,
                                    color: theme.iconTheme.color,
                                    size: 30,
                                  )
                                : null,
                          ),
                          if (_imageFile == null)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.add,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                  size: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          hintText: 'اسم المجموعة',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(),
                TextField(
                  controller: _descController,
                  decoration: const InputDecoration(
                    hintText: 'وصف المجموعة (اختياري)',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 14),
                  maxLines: 2,
                  minLines: 1,
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 2. Search Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'إضافة أعضاء...',
                filled: true,
                fillColor: theme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: primaryColor, width: 1.5),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 3. Results / Selection List
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final user = _searchResults[index];
                final uid = user['uid'];
                final isSelected = _selectedUserIds.contains(uid);

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage:
                        user['photoURL'] != null &&
                            (user['photoURL'] as String).startsWith('http')
                        ? NetworkImage(user['photoURL'])
                        : null,
                    child:
                        user['photoURL'] == null ||
                            !(user['photoURL'] as String).startsWith('http')
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(
                    user['displayName'] ?? 'مستخدم',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    user['username'] != null ? '@${user['username']}' : '',
                  ),
                  trailing: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? primaryColor : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? primaryColor : theme.disabledColor,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check,
                            size: 16,
                            color: theme.colorScheme.onPrimary,
                          )
                        : null,
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
                );
              },
            ),
          ),

          // 4. Selected Count Footer
          if (_selectedUserIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              color: primaryColor.withOpacity(0.1),
              child: SafeArea(
                // Add SafeArea for bottom devices
                child: Row(
                  children: [
                    Text(
                      '${_selectedUserIds.length} أعضاء تم اختيارهم',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (!_isCreating)
                      Icon(Icons.check_circle, color: primaryColor),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
