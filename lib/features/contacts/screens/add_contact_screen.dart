import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/contact_repository.dart';
import '../../chat/models/user_model.dart';
import 'edit_contact_screen.dart';

class AddContactScreen extends ConsumerStatefulWidget {
  const AddContactScreen({super.key});

  @override
  ConsumerState<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends ConsumerState<AddContactScreen> {
  final _searchController = TextEditingController();
  List<UserModel> _results = [];
  bool _isLoading = false;

  void _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final results = await ref
          .read(contactRepositoryProvider)
          .searchUsers(query);
      setState(() => _results = results);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة جهة اتصال'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.scaffoldBackgroundColor,
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو اسم المستخدم...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _results = []);
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _performSearch(),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // Results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 60,
                              color: theme.iconTheme.color ?? Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.trim().isEmpty
                                  ? 'ابحث عن مستخدم لإضافته'
                                  : 'لا توجد نتائج',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final user = _results[index];
                          final isMe = user.uid == currentUserId;

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: theme.dividerColor.withOpacity(0.1),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                radius: 28,
                                backgroundImage: _getImageProvider(
                                  user.photoURL,
                                ),
                                backgroundColor:
                                    theme.primaryColor.withOpacity(0.1),
                                child: user.photoURL == null
                                    ? Text(
                                        user.displayName[0].toUpperCase(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                          color: theme.primaryColor,
                                        ),
                                      )
                                    : null,
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      user.displayName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (isMe)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'أنت',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (user.username != null)
                                    Text('@${user.username}'),
                                  if (user.bio != null && user.bio!.isNotEmpty)
                                    Text(
                                      user.bio!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.textTheme.bodySmall?.color,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: isMe
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    )
                                  : ElevatedButton.icon(
                                      icon: const Icon(Icons.person_add, size: 16),
                                      label: const Text('إضافة'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: theme.primaryColor,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => EditContactScreen(
                                              userToAdd: user,
                                            ),
                                          ),
                                        ).then((_) {
                                          if (mounted) {
                                            _searchController.clear();
                                            setState(() => _results = []);
                                          }
                                        });
                                      },
                                    ),
                            ),
                          ).animate().fadeIn(delay: (index * 50).ms).slideX(
                                begin: 0.1,
                              );
                        },
                      ),
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
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
