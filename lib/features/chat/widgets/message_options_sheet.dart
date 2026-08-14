import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/message.dart';

class MessageOptionsSheet extends StatelessWidget {
  final Message message;
  final bool isMe;
  final Function(String emoji) onReaction;
  final VoidCallback onReply;
  final VoidCallback onDeleteForMe;
  final VoidCallback? onDeleteForEveryone;
  final VoidCallback? onSave;
  final VoidCallback? onEdit; // Added callback

  const MessageOptionsSheet({
    super.key,
    required this.message,
    required this.isMe,
    required this.onReaction,
    required this.onReply,
    required this.onDeleteForMe,
    this.onDeleteForEveryone,
    this.onSave,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Quick Reactions Bar - Professional messaging style
    final reactions = ['❤️', '👍', '😂', '😮', '😢', '🙏'];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reactions Row
          SizedBox(
            height: 60,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: reactions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 15),
              itemBuilder: (context, index) {
                final emoji = reactions[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    onReaction(emoji);
                  },
                  child:
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ).animate().scale(
                        delay: (index * 50).ms,
                        curve: Curves.easeOutBack,
                      ),
                );
              },
            ),
          ),

          const Divider(height: 30),

          // Action List
          if (message.type == 'text')
            _buildOption(
              icon: Icons.copy_rounded,
              label: 'نسخ النص',
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.text));
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('تم نسخ النص')));
              },
            ),

          if (isMe && message.type == 'text' && onEdit != null)
            _buildOption(
              icon: Icons.edit_rounded,
              label: 'تعديل',
              onTap: () {
                Navigator.pop(context);
                onEdit!();
              },
            ),

          _buildOption(
            icon: Icons.reply_rounded,
            label: 'رد',
            onTap: () {
              Navigator.pop(context);
              onReply();
            },
          ),

          if (message.type == 'image' || message.type == 'audio')
            _buildOption(
              icon: Icons.save_alt_rounded,
              label: 'حفظ',
              onTap: () {
                Navigator.pop(context);
                onSave?.call();
              },
            ),

          const Divider(),

          _buildOption(
            icon: Icons.delete_outline_rounded,
            label: 'حذف من عندي',
            color: Colors.red,
            onTap: () {
              Navigator.pop(context);
              onDeleteForMe();
            },
          ),

          if (isMe && onDeleteForEveryone != null)
            _buildOption(
              icon: Icons.delete_forever_rounded,
              label: 'حذف لدى الجميع',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                onDeleteForEveryone!();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (color ?? Colors.grey).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color ?? Colors.grey[700]),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: color != null ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: onTap,
    );
  }
}
