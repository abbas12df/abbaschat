import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/chat_repository.dart';
// import '../../../core/theme/app_theme.dart'; // Unused

class SearchMessagesScreen extends ConsumerStatefulWidget {
  final String roomId;

  const SearchMessagesScreen({super.key, required this.roomId});

  @override
  ConsumerState<SearchMessagesScreen> createState() =>
      _SearchMessagesScreenState();
}

class _SearchMessagesScreenState extends ConsumerState<SearchMessagesScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _allMessages = [];
  List<Map<String, dynamic>> _filteredMessages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    final repo = ref.read(chatRepositoryProvider);
    try {
      final msgs = await repo.getMessagesOnce(widget.roomId);
      if (mounted) {
        setState(() {
          _allMessages = msgs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() => _filteredMessages = []);
      return;
    }

    setState(() {
      _filteredMessages = _allMessages.where((msg) {
        // Only text messages for now
        if (msg['type'] != 'text') return false;
        final text = (msg['text'] ?? '').toString().toLowerCase();
        return text.contains(query);
      }).toList();
    });
  }

  String _formatTime(int timestamp) {
    if (timestamp == 0) return '';
    return DateFormat(
      'h:mm a',
    ).format(DateTime.fromMillisecondsSinceEpoch(timestamp));
  }

  @override
  Widget build(BuildContext context) {
    // If query is empty, show nothing? Or show recent?
    // WhatsApp shows nothing until you type.
    final isEmpty = _searchController.text.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'بحث في المحادثة...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white70),
          ),
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : isEmpty
          ? Center(
              child: Text(
                'اكتب للبحث عن رسائل',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : _filteredMessages.isEmpty
          ? const Center(child: Text('لا توجد نتائج'))
          : ListView.builder(
              itemCount: _filteredMessages.length,
              itemBuilder: (context, index) {
                final msg = _filteredMessages[index];
                final isMe =
                    msg['senderId'] == FirebaseAuth.instance.currentUser?.uid;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isMe
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Icon(
                      isMe ? Icons.person : Icons.person_outline,
                      color: isMe
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  title: Text(
                    msg['text'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    _formatTime(msg['timestamp'] ?? 0),
                    style: const TextStyle(fontSize: 12),
                  ),
                  // trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  // onTap: () {
                  //   // Optional: Scroll to message in chat?
                  //   // Hard to implement without robust scroll controller logic
                  // },
                );
              },
            ),
    );
  }
}
