import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../chat/models/user_model.dart';
import '../../chat/repositories/chat_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfileDetailsScreen extends ConsumerWidget {
  final String userId;

  const UserProfileDetailsScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final myId = FirebaseAuth.instance.currentUser?.uid;

    return FutureBuilder<UserModel?>(
      future: ref.read(chatRepositoryProvider).getUserData(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data!;
        final isMe = user.uid == myId;

        // Use StreamBuilder for real-time updates on Contacts/Blocked status
        return StreamBuilder<DocumentSnapshot>(
          stream: myId != null
              ? FirebaseFirestore.instance
                    .collection('users')
                    .doc(myId)
                    .snapshots()
              : null,
          builder: (ctx, mySnapshot) {
            final myData = mySnapshot.data?.data() as Map<String, dynamic>?;
            final contacts = List<String>.from(myData?['contacts'] ?? []);
            final blockedUsers = List<String>.from(
              myData?['blockedUsers'] ?? [],
            );

            final isContact = contacts.contains(userId);
            final isBlocked = blockedUsers.contains(userId);

            return Scaffold(
              appBar: AppBar(title: const Text('معلومات المستخدم')),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Profile Picture
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.primaryColor, width: 4),
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 10),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 70,
                        backgroundColor: theme.colorScheme.surfaceVariant,
                        backgroundImage: _getImageProvider(user.photoURL),
                        child: user.photoURL == null
                            ? Icon(
                                Icons.person,
                                size: 70,
                                color: theme.iconTheme.color,
                              )
                            : null,
                      ),
                    ).animate().scale(curve: Curves.easeOutBack),

                    const SizedBox(height: 20),
                    Text(
                      user.displayName,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (user.username != null)
                      Text(
                        '@${user.username}',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),

                    const SizedBox(height: 30),

                    // Bio Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.dividerColor.withOpacity(0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'نبذة',
                            style: TextStyle(
                              color: theme.textTheme.bodySmall?.color,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            user.bio ?? 'لا توجد نبذة',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn().slideY(begin: 0.1),

                    const SizedBox(height: 30),

                    if (!isMe) ...[
                      // Actions
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: isContact
                              ? theme.disabledColor
                              : theme.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          if (isContact) {
                            await ref
                                .read(chatRepositoryProvider)
                                .removeContact(userId);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تمت الإزالة من جهات الاتصال'),
                              ),
                            );
                          } else {
                            await ref
                                .read(chatRepositoryProvider)
                                .addContact(userId);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تمت الإضافة إلى جهات الاتصال'),
                              ),
                            );
                          }
                          // Force refresh logic could be added here
                          (context as Element).markNeedsBuild();
                        },
                        icon: Icon(
                          isContact ? Icons.person_remove : Icons.person_add,
                        ),
                        label: Text(
                          isContact
                              ? 'إزالة من جهات الاتصال'
                              : 'إضافة إلى جهات الاتصال',
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: isBlocked
                                ? theme.colorScheme.secondary
                                : theme.colorScheme.error,
                          ),
                          foregroundColor: isBlocked
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.error,
                        ),
                        onPressed: () async {
                          if (isBlocked) {
                            await ref
                                .read(chatRepositoryProvider)
                                .unblockUser(userId);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم إلغاء الحظر')),
                            );
                          } else {
                            await ref
                                .read(chatRepositoryProvider)
                                .blockUser(userId);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم حظر المستخدم')),
                            );
                            Navigator.pop(context); // Close screen on block
                          }
                        },
                        icon: Icon(
                          isBlocked ? Icons.check_circle : Icons.block,
                        ),
                        label: Text(isBlocked ? 'إلغاء الحظر' : 'حظر المستخدم'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
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
}
