import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../chat/repositories/chat_repository.dart';
import '../../profile/screens/user_profile_details_screen.dart';
import '../../auth/repositories/key_repository.dart';
import '../models/user_model.dart';
import '../models/chat_room.dart'; // Added
import '../../../core/local/local_storage_service.dart';
import '../screens/search_messages_screen.dart';

class UserProfileBottomSheet extends ConsumerWidget {
  final String userId;
  final String userName;
  final String? photoContent; // URL or Base64
  final String? roomId;

  const UserProfileBottomSheet({
    super.key,
    required this.userId,
    required this.userName,
    this.photoContent,
    this.roomId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final myId = FirebaseAuth.instance.currentUser?.uid;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle Bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Content
              Expanded(
                child: FutureBuilder(
                  future: Future.wait([
                    ref.read(chatRepositoryProvider).getUserData(userId),
                    ref.read(keyRepositoryProvider).getUserPublicKey(userId),
                  ]),
                  builder: (context, snapshot) {
                    final data = snapshot.data as List<dynamic>?;
                    final user = data?[0] as UserModel?;
                    final publicKey = data?[1] as String?;

                    final displayName = user?.displayName ?? userName;
                    final username = user?.username;
                    final bio = user?.bio ?? 'لا توجد نبذة';
                    final photo = user?.photoURL ?? photoContent;
                    final isMe = userId == myId;

                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      children: [
                        // 1. Header Section with Enhanced Design
                        const SizedBox(height: 10),
                        Center(
                          child:
                              Hero(
                                    tag: 'profile_pic_${userId}_sheet',
                                    child: Container(
                                      width: 120,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            theme.primaryColor,
                                            theme.primaryColor.withOpacity(0.6),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: theme.primaryColor
                                                .withOpacity(0.3),
                                            blurRadius: 20,
                                            spreadRadius: 3,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      padding: const EdgeInsets.all(4),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: theme.scaffoldBackgroundColor,
                                        ),
                                        child: CircleAvatar(
                                          radius: 56,
                                          backgroundImage: _getImageProvider(
                                            photo,
                                          ),
                                          backgroundColor: Colors.grey.shade200,
                                          child: photo == null
                                              ? Icon(
                                                  Icons.person,
                                                  size: 60,
                                                  color:
                                                      theme.iconTheme.color ??
                                                      Colors.grey,
                                                )
                                              : null,
                                        ),
                                      ),
                                    ),
                                  )
                                  .animate()
                                  .scale(
                                    delay: 100.ms,
                                    duration: 400.ms,
                                    curve: Curves.easeOutBack,
                                  )
                                  .fadeIn(duration: 300.ms),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Column(
                            children: [
                              Text(
                                    displayName,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                    textAlign: TextAlign.center,
                                  )
                                  .animate()
                                  .fadeIn(delay: 200.ms, duration: 400.ms)
                                  .slideY(begin: -0.2, end: 0),
                              if (username != null) ...[
                                const SizedBox(height: 4),
                                Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.primaryColor.withOpacity(
                                          0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: theme.primaryColor.withOpacity(
                                            0.2,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        '@$username',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: theme.primaryColor,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(delay: 300.ms, duration: 400.ms)
                                    .slideY(begin: -0.2, end: 0),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // 2. Identity Section (Fingerprint) - Enhanced
                        _buildSectionHeader(context, 'الهوية'),
                        Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    theme.primaryColor.withOpacity(0.1),
                                    theme.primaryColor.withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: theme.primaryColor.withOpacity(0.2),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.primaryColor.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: theme.primaryColor.withOpacity(
                                        0.15,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.fingerprint_rounded,
                                      color: theme.primaryColor,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'بصمة التحقق',
                                          style: TextStyle(
                                            color: theme
                                                .textTheme
                                                .bodySmall
                                                ?.color,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                theme.scaffoldBackgroundColor,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            _getIdentityFingerprint(publicKey),
                                            style: TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 11,
                                              letterSpacing: 1.5,
                                              color: theme.primaryColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        final fingerprint = _getIdentityFingerprint(publicKey);
                                        Clipboard.setData(
                                          ClipboardData(text: fingerprint),
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: const Row(
                                              children: [
                                                Icon(
                                                  Icons.check_circle,
                                                  color: Colors.white,
                                                ),
                                                SizedBox(width: 8),
                                                Text('تم نسخ البصمة'),
                                              ],
                                            ),
                                            backgroundColor: Colors.green,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: theme.primaryColor.withOpacity(
                                            0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.copy_rounded,
                                          size: 20,
                                          color: theme.primaryColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .animate()
                            .fadeIn(delay: 400.ms, duration: 400.ms)
                            .slideX(begin: -0.1, end: 0),

                        const SizedBox(height: 24),

                        // 3. Bio Section - Enhanced
                        _buildSectionHeader(context, 'النبذة'),
                        Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    theme.cardColor,
                                    theme.cardColor.withOpacity(0.8),
                                  ],
                                ),
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
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 20,
                                    color: theme.primaryColor.withOpacity(0.7),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      bio,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            height: 1.6,
                                            letterSpacing: 0.2,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .animate()
                            .fadeIn(delay: 500.ms, duration: 400.ms)
                            .slideX(begin: -0.1, end: 0),

                        const SizedBox(height: 24),

                        // 4. Quick Actions Grid
                        _buildSectionHeader(context, 'إجراءات سريعة'),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 4,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          children: [
                            _buildQuickAction(context, Icons.search, 'بحث', () {
                              Navigator.pop(context);
                              if (roomId != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        SearchMessagesScreen(roomId: roomId!),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('لا يمكن البحث هنا'),
                                  ),
                                );
                              }
                            }),
                            Consumer(
                              builder: (context, ref, _) {
                                // Watch mute status for real-time updates
                                final currentMyId = myId;
                                final currentRoomId = roomId;
                                if (currentMyId == null ||
                                    currentRoomId == null) {
                                  return _buildQuickAction(
                                    context,
                                    Icons.notifications_active,
                                    'تنبيهات',
                                    () {},
                                    color: theme.colorScheme.primary,
                                  );
                                }
                                // After null check, use non-null assertion
                                final String validMyId = currentMyId;
                                final String validRoomId = currentRoomId;
                                final currentIsMuted = ref
                                    .watch(localStorageServiceProvider)
                                    .isMuted(validMyId, validRoomId);
                                return _buildQuickAction(
                                  context,
                                  currentIsMuted
                                      ? Icons.notifications_off
                                      : Icons.notifications_active,
                                  currentIsMuted ? 'مكتوم' : 'تنبيهات',
                                  () async {
                                    await ref
                                        .read(chatRepositoryProvider)
                                        .toggleMute(
                                          validRoomId,
                                          !currentIsMuted,
                                        );
                                    // Show feedback
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          !currentIsMuted
                                              ? 'تم كتم الإشعارات'
                                              : 'تم تفعيل الإشعارات',
                                        ),
                                        backgroundColor: !currentIsMuted
                                            ? Colors.orange
                                            : theme.colorScheme.primary,
                                        duration: const Duration(seconds: 1),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  color: currentIsMuted
                                      ? Colors.orange
                                      : theme.colorScheme.primary,
                                );
                              },
                            ),
                            _buildQuickAction(
                              context,
                              Icons.delete_outline,
                              'مسح',
                              () {
                                _confirmClearChat(context, ref);
                              },
                              isDestructive: true,
                            ),
                            _buildQuickAction(
                              context,
                              Icons.person_outline,
                              'الملف',
                              () {
                                Navigator.pop(context); // Close sheet
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => UserProfileDetailsScreen(
                                      userId: userId,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // 4.5 Security Section (Restored)
                        if (roomId != null) ...[
                          _buildSectionHeader(
                            context,
                            'الحماية وتأمين المحادثة',
                          ),
                          StreamBuilder<ChatRoom?>(
                            stream: ref
                                .watch(chatRepositoryProvider)
                                .watchChatData(roomId!),
                            builder: (context, snapshot) {
                              final room = snapshot.data;
                              final isEnabled =
                                  room?.isOutgoingProtectionEnabled ?? false;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 24),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      theme.cardColor,
                                      theme.cardColor.withOpacity(0.8),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isEnabled
                                        ? Colors.red.withOpacity(0.3)
                                        : theme.dividerColor.withOpacity(0.1),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: SwitchListTile(
                                  secondary: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isEnabled
                                          ? Colors.red.withOpacity(0.1)
                                          : theme.primaryColor.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isEnabled
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: isEnabled
                                          ? Colors.red
                                          : theme.primaryColor,
                                    ),
                                  ),
                                  title: const Text(
                                    'منع لقطات الشاشة',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    isEnabled
                                        ? 'الطرف الآخر ممنوع من التصوير (وأنت أيضاً)'
                                        : 'السماح للطرف الآخر بتصوير الشاشة',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.textTheme.bodySmall?.color,
                                    ),
                                  ),
                                  value: isEnabled,
                                  onChanged: (val) async {
                                    await ref
                                        .read(chatRepositoryProvider)
                                        .requestPeerProtection(roomId!, val);
                                  },
                                  activeColor: Colors.red,
                                ),
                              );
                            },
                          ),
                        ],

                        // 5. Relationship Management
                        if (!isMe) ...[
                          _buildSectionHeader(context, 'إدارة العلاقة'),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.block, color: Colors.red),
                            ),
                            title: const Text(
                              'حظر المستخدم',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: const Text(
                              'لن تتلقى رسائل من هذا المستخدم',
                            ),
                            onTap: () =>
                                _confirmBlockUser(context, ref, displayName),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 4),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodySmall?.color,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isDestructive = false,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final finalColor =
        color ??
        (isDestructive ? theme.colorScheme.error : theme.colorScheme.primary);
    return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    finalColor.withOpacity(0.15),
                    finalColor.withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: finalColor.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: finalColor.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: finalColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: finalColor, size: 20),
                  ),
                  const SizedBox(height: 6),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: finalColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .animate()
        .scale(delay: 600.ms, duration: 300.ms, curve: Curves.easeOutBack)
        .fadeIn(delay: 600.ms, duration: 300.ms);
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

  String _getIdentityFingerprint(String? publicKey) {
    if (publicKey == null || publicKey.trim().isEmpty) {
      return 'غير متاح (لا يوجد مفتاح)';
    }

    // Canonicalization: Remove all whitespaces and newlines
    final canonicalKey = publicKey.replaceAll(RegExp(r'\s+'), '');

    var bytes = utf8.encode(canonicalKey);
    var digest = sha256.convert(bytes);
    var hex = digest.toString().toUpperCase().substring(0, 16);
    return '${hex.substring(0, 4)}-${hex.substring(4, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}';
  }

  void _confirmBlockUser(BuildContext context, WidgetRef ref, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حظر $name؟'),
        content: const Text(
          'لن تتمكن من استلام الرسائل أو المكالمات من هذا المستخدم.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(chatRepositoryProvider).blockUser(userId);
              Navigator.pop(context); // Close sheet
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('تم حظر $name')));
            },
            child: const Text('حظر', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmClearChat(BuildContext context, WidgetRef ref) {
    if (roomId == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مسح سجل المحادثة؟'),
        content: const Text(
          'سيتم حذف جميع الرسائل من جهازك فقط. لا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              Navigator.pop(ctx);
              // Call repository to delete chat
              await ref.read(chatRepositoryProvider).deleteChat(roomId!);
              Navigator.pop(context); // Close sheet
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم مسح السجل المحلي')),
              );
            },
            child: const Text('مسح', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
