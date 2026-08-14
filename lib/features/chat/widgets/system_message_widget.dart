import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// System message widget for group events (joins, leaves, etc.)
/// Displayed in the center of the chat like Telegram
class SystemMessageWidget extends StatelessWidget {
  final String message;
  final IconData? icon;

  const SystemMessageWidget({super.key, required this.message, this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms)
        .scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1.0, 1.0),
          duration: 300.ms,
        );
  }
}
