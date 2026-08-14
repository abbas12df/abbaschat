import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';

class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
  List<String> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        final blocked = List<String>.from(data?['blockedUsers'] ?? []);
        setState(() {
          _blockedUsers = blocked;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _unblockUser(String userId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'blockedUsers': FieldValue.arrayRemove([userId]),
      });

      setState(() {
        _blockedUsers.remove(userId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إلغاء الحظر بنجاح ✅'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المستخدمون المحظورون')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _blockedUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.block,
                        size: 64,
                        color: Theme.of(context).disabledColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'لا يوجد مستخدمون محظورون',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _blockedUsers.length,
                  itemBuilder: (context, index) {
                    final userId = _blockedUsers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                          child: Icon(
                            Icons.person_off,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        title: Text('مستخدم: ${userId.substring(0, 8)}...'),
                        subtitle: const Text('محظور'),
                        trailing: IconButton(
                          icon: const Icon(Icons.block_outlined, color: Colors.green),
                          onPressed: () => _showUnblockDialog(userId),
                          tooltip: 'إلغاء الحظر',
                        ),
                      ),
                    ).animate().fadeIn(delay: (index * 50).ms);
                  },
                ),
    );
  }

  Future<void> _showUnblockDialog(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الحظر'),
        content: const Text('هل أنت متأكد من إلغاء حظر هذا المستخدم؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('إلغاء الحظر'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _unblockUser(userId);
    }
  }
}
