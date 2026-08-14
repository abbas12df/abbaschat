import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/chat_repository.dart';
import '../models/user_model.dart';

class GroupRequestsScreen extends ConsumerStatefulWidget {
  final String roomId;
  final List<String> pendingRequests;

  const GroupRequestsScreen({
    super.key,
    required this.roomId,
    required this.pendingRequests,
  });

  @override
  ConsumerState<GroupRequestsScreen> createState() =>
      _GroupRequestsScreenState();
}

class _GroupRequestsScreenState extends ConsumerState<GroupRequestsScreen> {
  late List<String> _requests;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _requests = List.from(widget.pendingRequests);
  }

  Future<void> _handleAction(String userId, bool accept) async {
    setState(() => _isLoading = true);
    try {
      if (accept) {
        await ref
            .read(chatRepositoryProvider)
            .acceptJoinRequest(widget.roomId, userId);
      } else {
        await ref
            .read(chatRepositoryProvider)
            .rejectJoinRequest(widget.roomId, userId);
      }

      setState(() {
        _requests.remove(userId);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? 'تم قبول الطلب' : 'تم رفض الطلب'),
          backgroundColor: accept ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_requests.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('طلبات الانضمام')),
        body: const Center(child: Text('لا توجد طلبات معلقة')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('طلبات الانضمام')),
      body: ListView.builder(
        itemCount: _requests.length,
        itemBuilder: (context, index) {
          final uid = _requests[index];
          return FutureBuilder<UserModel?>(
            future: ref.read(chatRepositoryProvider).getUserData(uid),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const ListTile(
                  leading: CircleAvatar(child: Icon(Icons.person)),
                  title: Text('تحميل...'),
                );
              }
              final user = snapshot.data;
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage:
                      (user?.photoURL != null && user!.photoURL!.isNotEmpty)
                      ? NetworkImage(
                          user.photoURL!,
                        ) // Assuming URL for now, or adapt helper
                      : null,
                  child: (user?.photoURL == null || user!.photoURL!.isEmpty)
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(user?.displayName ?? 'مستخدم غير معروف'),
                subtitle: Text('@${user?.username ?? uid}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: _isLoading
                          ? null
                          : () => _handleAction(uid, true),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: _isLoading
                          ? null
                          : () => _handleAction(uid, false),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
