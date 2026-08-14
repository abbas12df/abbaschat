import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../chat/repositories/chat_repository.dart';
import '../../chat/screens/chat_screen.dart';
import '../../../core/widgets/shimmer_loaders.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SearchUserScreen extends ConsumerStatefulWidget {
  const SearchUserScreen({super.key});

  @override
  ConsumerState<SearchUserScreen> createState() => _SearchUserScreenState();
}

class _SearchUserScreenState extends ConsumerState<SearchUserScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  void _searchUsers() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // Improved Search Logic:
      // Firestore is case-sensitive. We construct two queries to cover common cases:
      // 1. Exact match (or prefix) as typed.
      // 2. Capitalized first letter (common for names like "ahmed" -> "Ahmed").

      final String capitalizedQuery = query.length > 1
          ? query[0].toUpperCase() + query.substring(1)
          : query.toUpperCase();

      final Future<QuerySnapshot<Map<String, dynamic>>> q1 = FirebaseFirestore
          .instance
          .collection('users')
          .where('displayName', isGreaterThanOrEqualTo: query)
          .where('displayName', isLessThan: query + '\uf8ff')
          .limit(10)
          .get();

      final Future<QuerySnapshot<Map<String, dynamic>>?> q2 =
          (query != capitalizedQuery)
          ? FirebaseFirestore.instance
                .collection('users')
                .where('displayName', isGreaterThanOrEqualTo: capitalizedQuery)
                .where('displayName', isLessThan: capitalizedQuery + '\uf8ff')
                .limit(10)
                .get()
          : Future<QuerySnapshot<Map<String, dynamic>>?>.value(null);

      final results = await Future.wait([q1, q2]);

      final Set<String> seenUids = {};
      final List<Map<String, dynamic>> finalResults = [];

      for (var snapshot in results) {
        if (snapshot == null) continue;
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final uid = data['uid'];
          if (uid != FirebaseAuth.instance.currentUser?.uid &&
              !seenUids.contains(uid)) {
            seenUids.add(uid);
            finalResults.add(data);
          }
        }
      }

      setState(() {
        _searchResults = finalResults;
        _isLoading = false;
      });
    } catch (e) {
      print('Search Error: $e');
      setState(() => _isLoading = false);
    }
  }

  void _startChat(String otherUserId, String otherUserName) async {
    // Logic to ensure room exists but DOES NOT PERSIST until message is sent
    final repo = ref.read(chatRepositoryProvider);
    // Passing persist: false prevents empty chat creation just by viewing
    await repo.createOrGetChatRoom(otherUserId, persist: false);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              ChatScreen(userName: otherUserName, otherUserId: otherUserId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'ابحث عن مستخدم...',
            border: InputBorder.none,
          ),
          onSubmitted: (_) => _searchUsers(),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: _searchUsers),
        ],
      ),
      body: _isLoading
          ? const ShimmerUserList()
          : ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final user = _searchResults[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(user['displayName'] ?? 'Unknown'),
                  subtitle: Text(user['phoneNumber'] ?? ''),
                  onTap: () => _startChat(user['uid'], user['displayName']),
                );
              },
            ),
    );
  }
}
