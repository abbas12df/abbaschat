import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class TypingBubble extends StatelessWidget {
  const TypingBubble({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceVariant
            : theme.colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomRight: Radius.circular(18),
          bottomLeft: Radius.zero,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDot(context, 0),
          const SizedBox(width: 5),
          _buildDot(context, 150),
          const SizedBox(width: 5),
          _buildDot(context, 300),
        ],
      ),
    );
  }

  Widget _buildDot(BuildContext context, int delayMs) {
    return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
            shape: BoxShape.circle,
          ),
        )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scale(
          delay: Duration(milliseconds: delayMs),
          duration: 500.ms,
          begin: const Offset(0.8, 0.8),
          end: const Offset(1.3, 1.3),
          curve: Curves.easeInOut,
        )
        .moveY(
          delay: Duration(milliseconds: delayMs),
          duration: 500.ms,
          begin: 0,
          end: -4,
          curve: Curves.easeInOut,
        );
  }
}
