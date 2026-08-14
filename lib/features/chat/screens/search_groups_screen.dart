import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qqqq/features/chat/repositories/chat_repository.dart';

class SearchGroupsScreen extends ConsumerStatefulWidget {
  const SearchGroupsScreen({super.key});

  @override
  ConsumerState<SearchGroupsScreen> createState() => _SearchGroupsScreenState();
}

class _SearchGroupsScreenState extends ConsumerState<SearchGroupsScreen> {
  final _searchController = TextEditingController();
  final _handleSearchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _handleSearchController.dispose();
    super.dispose();
  }

  Future<void> _joinByHandle() async {
    final handle = _handleSearchController.text.trim();
    if (handle.isEmpty) return;

    setState(() => _isLoading = true);
    FocusScope.of(context).unfocus();

    try {
      await ref.read(chatRepositoryProvider).joinGroupByHandle(handle);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال الطلب أو الانضمام بنجاح ✅')),
        );
        _handleSearchController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: ${e.toString().replaceAll("Exception: ", "")}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    if (_searchController.text.trim().isEmpty) {
      if (mounted) setState(() => _searchResults = []);
      return;
    }
    _performSearch(_searchController.text.trim());
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);

    // We search locally by Name in public_groups collection
    // Note: Firestore text search is limited. This is a prefix search.
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('public_groups')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThan: query + 'z')
          .limit(20)
          .get();

      if (mounted) {
        setState(() {
          _searchResults = snapshot.docs.map((doc) => doc.data()).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Search error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinGroup(Map<String, dynamic> groupData) async {
    final groupId = groupData['id'];
    // Logic to join:
    // 1. Send 'group_join_request' to admin? Or just add self if it's public?
    // User requested "Search and Join".
    // For Public Groups, one should likely be able to join immediately or send request.
    // Given the P2P nature, we need to find an Admin to "Add" us, OR we insert ourselves?
    // If we insert ourselves in Firestore, that doesn't update everyone's local DB.
    // WE NEED TO CONTACT AN ADMIN.
    // "Join Request" -> Relay -> Admin -> Admin Accepts -> Admin broadcasts "Add Member".

    // Simplification for now:
    // We can't just "join" without an admin adding us in this architecture (encryption keys etc).
    // So we will implement "Request to Join".

    final createdBy = groupData['createdBy'];
    if (createdBy == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطأ: لا يمكن العثور على مشرف المجموعة')),
      );
      return;
    }

    try {
      await ref
          .read(chatRepositoryProvider)
          .requestToJoinGroup(groupId, createdBy);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال طلب الانضمام للمشرف ✅')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل الإرسال: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('بحث عن مجموعات')),
      body: Column(
        children: [
          // 1. Join By Handle Section
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.scaffoldBackgroundColor, // Ensure distinction
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'انضمام عبر المعرف (Join by Handle)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _handleSearchController,
                        decoration: InputDecoration(
                          hintText: '@group_handle',
                          prefixIcon: const Icon(Icons.alternate_email),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      onPressed: _isLoading ? null : _joinByHandle,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('انضمام'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),

          // 2. Public Groups Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'ابحث عن مجموعات عامة بالاسم...',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
          Expanded(
            child: _searchResults.isEmpty
                ? const Center(
                    child: Text('ابحث عن مجموعات عامة للانضمام إليها'),
                  )
                : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final group = _searchResults[index];
                      final name = group['name'] ?? 'مجموعة';
                      final desc = group['description'] ?? '';
                      final icon = group['icon']; // Assuming base64 or URL

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: icon != null
                                ? MemoryImage(
                                    const Base64Decoder().convert(icon),
                                  ) // Logic to decode if it was base64... wait.
                                // ChatRepo said we might store URL or Base64.
                                // CreateGroup stores base64.
                                // We need to import dart:convert
                                : null,
                            child: icon == null
                                ? const Icon(Icons.group)
                                : null,
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            desc,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _joinGroup(group),
                            child: const Text('انضمام'),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
