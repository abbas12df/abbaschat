import 'package:flutter/material.dart';

class MessagePreview extends StatelessWidget {
  final String content;
  final bool isUnread;

  const MessagePreview({
    super.key,
    required this.content,
    this.isUnread = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (displayText, icon) = _parseContent(content);

    return Row(
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 16,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Text(
            displayText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isUnread ? FontWeight.w500 : FontWeight.w400,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  (String, IconData?) _parseContent(String content) {
    // Check for media indicators
    if (content.contains('[صورة]') || content.toLowerCase().contains('photo')) {
      return ('صورة', Icons.image_outlined);
    }
    if (content.contains('[صوت]') ||
        content.toLowerCase().contains('voice') ||
        content.toLowerCase().contains('audio')) {
      return ('رسالة صوتية', Icons.mic_outlined);
    }
    if (content.contains('[ملف]') || content.toLowerCase().contains('file')) {
      return ('ملف', Icons.attach_file_outlined);
    }
    if (content.contains('تم حذف') ||
        content.toLowerCase().contains('deleted')) {
      return ('تم حذف هذه الرسالة', Icons.block_outlined);
    }

    // Regular text message
    return (content, null);
  }
}
