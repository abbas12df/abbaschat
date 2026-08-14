import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../repositories/chat_repository.dart';
import '../../../core/local/local_storage_service.dart';
import '../screens/chat_screen.dart';

/// Widget to display message text with clickable links and @handles
/// Similar to Telegram's link handling
class LinkableMessageText extends ConsumerWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  const LinkableMessageText({
    super.key,
    required this.text,
    this.style,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Professional link styling - different colors for light/dark mode
    final linkColor = theme.brightness == Brightness.dark
        ? const Color(0xFF64B5F6) // Light blue for dark mode
        : const Color(0xFF1976D2); // Darker blue for light mode

    return Linkify(
      onOpen: (link) => _handleLinkTap(context, ref, link.url),
      text: text,
      style: style,
      linkStyle:
          style?.copyWith(
            color: linkColor,
            decoration: TextDecoration.none,
            fontWeight: FontWeight.w600,
          ) ??
          TextStyle(
            color: linkColor,
            decoration: TextDecoration.none,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
      textAlign: textAlign ?? TextAlign.start,
      options: const LinkifyOptions(
        humanize: false,
        looseUrl: true,
        // Custom linkifiers for @handles
        defaultToHttps: true,
      ),
      linkifiers: [
        const UrlLinkifier(),
        const EmailLinkifier(),
        GroupHandleLinkifier(), // Custom linkifier for @handles
      ],
    );
  }

  /// Handle link/handle tap
  Future<void> _handleLinkTap(
    BuildContext context,
    WidgetRef ref,
    String url,
  ) async {
    // Check if it's a group handle (@handle)
    if (url.startsWith('@')) {
      await _handleGroupHandleTap(context, ref, url);
      return;
    }

    // Check if it's our app link (qqqq.app/join/@handle)
    if (url.contains('qqqq.app/join/')) {
      final handle = url.split('/').last.replaceAll('@', '');
      await _handleGroupHandleTap(context, ref, '@$handle');
      return;
    }

    // Regular URL - open in browser
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل فتح الرابط: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Handle group handle tap (@handle)
  Future<void> _handleGroupHandleTap(
    BuildContext context,
    WidgetRef ref,
    String handle,
  ) async {
    final cleanHandle = handle.replaceAll('@', '').toLowerCase();

    try {
      // Show loading
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('جاري التحميل...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      final chatRepo = ref.read(chatRepositoryProvider);

      // Try to get group info by handle
      final groupInfo = await chatRepo.getGroupInfoByHandle(cleanHandle);

      if (groupInfo == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('المجموعة غير موجودة'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final groupId = groupInfo['id'] as String;
      final isPublic = groupInfo['isPublic'] as bool? ?? false;
      final participants = List<String>.from(groupInfo['participants'] ?? []);
      final myId = chatRepo.currentUserId;

      // Check if already a member
      if (participants.contains(myId)) {
        // Already a member - navigate to chat directly
        if (context.mounted) {
          // Get local conversation to get group name
          final localStorage = ref.read(localStorageServiceProvider);
          final conversation = localStorage.getConversation(myId!, groupId);
          final groupName = conversation?['groupName'] as String? ?? 'مجموعة';

          // Navigate to the chat screen directly
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                userName: groupName,
                otherUserId: groupId,
                isGroup: true,
              ),
            ),
          );
        }
        return;
      }

      // Not a member - show join dialog
      if (context.mounted) {
        _showJoinDialog(
          context,
          ref,
          groupId: groupId,
          groupName: groupInfo['groupName'] as String? ?? 'مجموعة',
          handle: cleanHandle,
          isPublic: isPublic,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show join group dialog
  void _showJoinDialog(
    BuildContext context,
    WidgetRef ref, {
    required String groupId,
    required String groupName,
    required String handle,
    required bool isPublic,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الانضمام إلى المجموعة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              groupName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '@$handle',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isPublic
                  ? 'هل تريد الانضمام إلى هذه المجموعة؟'
                  : 'هذه مجموعة خاصة. سيتم إرسال طلب انضمام.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                await ref
                    .read(chatRepositoryProvider)
                    .joinGroupByHandle(handle);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isPublic
                            ? 'تم الانضمام بنجاح! افتح المجموعة من الشاشة الرئيسية'
                            : 'تم إرسال الطلب',
                      ),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('خطأ: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(isPublic ? 'انضم' : 'إرسال طلب'),
          ),
        ],
      ),
    );
  }
}

/// Custom linkifier for @handles
class GroupHandleLinkifier extends Linkifier {
  const GroupHandleLinkifier();

  @override
  List<LinkifyElement> parse(
    List<LinkifyElement> elements,
    LinkifyOptions options,
  ) {
    final list = <LinkifyElement>[];

    for (var element in elements) {
      if (element is TextElement) {
        final text = element.text;
        final matches = RegExp(r'@([a-zA-Z0-9_]{3,20})').allMatches(text);

        if (matches.isEmpty) {
          list.add(element);
        } else {
          var lastIndex = 0;
          for (var match in matches) {
            // Add text before match
            if (match.start > lastIndex) {
              list.add(TextElement(text.substring(lastIndex, match.start)));
            }

            // Add link element for @handle
            list.add(LinkableElement(match.group(0)!, match.group(0)!));

            lastIndex = match.end;
          }

          // Add remaining text
          if (lastIndex < text.length) {
            list.add(TextElement(text.substring(lastIndex)));
          }
        }
      } else {
        list.add(element);
      }
    }

    return list;
  }
}
