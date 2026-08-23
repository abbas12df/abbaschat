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
    final theme = Theme.of(context);
    final (displayText, icon) = _parseContent(content);
    final previewColor = theme.colorScheme.onSurfaceVariant;

    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: previewColor),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Text(
            displayText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
              color: isUnread ? theme.colorScheme.onSurface : previewColor,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  (String, IconData?) _parseContent(String content) {
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

    return (content, null);
  }
}
