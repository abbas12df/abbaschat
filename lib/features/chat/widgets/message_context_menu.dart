import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import '../models/message.dart';

class MessageContextMenu extends StatelessWidget {
  final Message message;
  final bool isMe;
  final Offset tapPosition;
  final Function(String emoji) onReaction;
  final VoidCallback onReply;
  final VoidCallback onDeleteForMe;
  final VoidCallback? onDeleteForEveryone;
  final VoidCallback? onSave; // New: Save Image/Audio
  final VoidCallback? onEdit; // New: Edit Message
  final VoidCallback? onTestDeleteLocal; // New

  const MessageContextMenu({
    super.key,
    required this.message,
    required this.isMe,
    required this.tapPosition,
    required this.onReaction,
    required this.onReply,
    required this.onDeleteForMe,
    this.onDeleteForEveryone,
    this.onSave,
    this.onEdit,
    this.onTestDeleteLocal,
  });

  static Future<void> show(
    BuildContext context, {
    required Message message,
    required bool isMe,
    required Offset tapPosition,
    required Function(String emoji) onReaction,
    required VoidCallback onReply,
    required VoidCallback onDeleteForMe,
    VoidCallback? onDeleteForEveryone,
    VoidCallback? onSave,
    VoidCallback? onEdit,
    VoidCallback? onTestDeleteLocal,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        pageBuilder: (context, animation, secondaryAnimation) {
          return MessageContextMenu(
            message: message,
            isMe: isMe,
            tapPosition: tapPosition,
            onReaction: onReaction,
            onReply: onReply,
            onDeleteForMe: onDeleteForMe,
            onDeleteForEveryone: onDeleteForEveryone,
            onSave: onSave,
            onEdit: onEdit,
            onTestDeleteLocal: onTestDeleteLocal,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Calculate position: try to show near the tap, but keep on screen
    // Default: show below the tap
    double top = tapPosition.dy;
    double left = isMe
        ? (size.width - 250 - 20)
        : 20; // Align with bubble roughly

    // Adjust if too close to bottom
    if (top > size.height - 300) {
      top = tapPosition.dy - 300; // Show above
    }

    // Adjust horizontal to be near the tap/message
    // message bubble width is dynamic, but menu width is fixed ~200-250
    // Simplified: Centered horizontally or aligned to side?
    // User wants "Near the message".
    // If isMe (Right), align Right. If other (Left), align Left.

    if (isMe) {
      left = size.width - 220; // 20 padding
    } else {
      left = 20;
    }

    return Stack(
      children: [
        // Backdrop (handled by PageRoute barrier, but we can handle tap to close here too if needed)
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(color: Colors.transparent),
          ),
        ),

        Positioned(
          top: top,
          left: left,
          child: Material(
            color: Colors.transparent,
            child:
                Container(
                      width: 200,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Reactions Section
                              _buildReactionsBar(context),
                              const Divider(height: 1),
                              // Actions
                              _buildActionItem(
                                context,
                                icon: Icons.reply_rounded,
                                label: 'الرد على الرسالة',
                                onTap: onReply,
                              ),
                              if (message.type == 'text')
                                _buildActionItem(
                                  context,
                                  icon: Icons.copy_rounded,
                                  label: 'نسخ النص',
                                  onTap: () {
                                    Clipboard.setData(
                                      ClipboardData(text: message.text),
                                    );
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('تم نسخ النص'),
                                      ),
                                    );
                                  },
                                ),
                              if (message.type == 'image' ||
                                  message.type == 'audio' ||
                                  message.type == 'file')
                                _buildActionItem(
                                  context,
                                  icon: Icons.save_alt_rounded,
                                  label: message.type == 'image'
                                      ? 'حفظ الصورة'
                                      : (message.type == 'audio' ? 'حفظ الملف الصوتي' : 'حفظ الملف'),
                                  onTap: () {
                                    if (onSave != null) {
                                      onSave!();
                                      // Navigator.pop(context); // REMOVED: Managed by _buildActionItem
                                    }
                                  },
                                ),
                              if (isMe && message.type == 'text')
                                _buildActionItem(
                                  context,
                                  icon: Icons.edit_rounded,
                                  label: 'تعديل الرسالة',
                                  onTap: () {
                                    if (onEdit != null) {
                                      onEdit!(); // This sets state in parent
                                      // Navigator.pop(context); // REMOVED: Managed by _buildActionItem
                                    }
                                  },
                                ),
                                const Divider(height: 1),
                              if (onTestDeleteLocal != null)
                                _buildActionItem(
                                  context,
                                  icon: Icons.bug_report_rounded,
                                  label: 'حذف الملف محلياً (للتجربة)',
                                  color: Colors.orange,
                                  onTap: onTestDeleteLocal!,
                                ),
                              _buildActionItem(
                                context,
                                icon: Icons.delete_outline_rounded,
                                label: 'الحذف من عندي',
                                color: Colors.red,
                                onTap: onDeleteForMe,
                              ),
                              if (onDeleteForEveryone != null)
                                _buildActionItem(
                                  context,
                                  icon: Icons.delete_forever_rounded,
                                  label: 'الحذف لدى الجميع',
                                  color: Colors.red,
                                  onTap: onDeleteForEveryone!,
                                ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .animate()
                    .scale(
                      duration: 200.ms,
                      curve: Curves.easeOutBack,
                      alignment: isMe ? Alignment.topRight : Alignment.topLeft,
                    )
                    .fadeIn(duration: 150.ms),
          ),
        ),
      ],
    );
  }

  Widget _buildReactionsBar(BuildContext context) {
    final reactions = ['❤️', '👍', '😂', '😮', '😢', '🙏'];
    return Container(
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: reactions.length,
        itemBuilder: (context, index) {
          final emoji = reactions[index];
          return GestureDetector(
            onTap: () {
              Navigator.pop(context);
              onReaction(emoji);
            },
            child: Container(
              width: 38,
              height: 38,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ).animate().scale(delay: (index * 30).ms, duration: 200.ms),
          );
        },
      ),
    );
  }

  Widget _buildActionItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final textColor = color ?? theme.textTheme.bodyMedium?.color;

    return InkWell(
      onTap: () {
        Navigator.pop(context); // Close menu first
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: textColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
