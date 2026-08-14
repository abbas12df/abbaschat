import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDot(context, 0),
              const SizedBox(width: 4),
              _buildDot(context, 150),
              const SizedBox(width: 4),
              _buildDot(context, 300),
              const SizedBox(width: 8),
              Text(
                'يكتب...',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 200.ms)
        .slideX(begin: -0.1, end: 0, duration: 200.ms, curve: Curves.easeOut);
  }

  Widget _buildDot(BuildContext context, int delay) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dotColor = isDark ? Colors.grey[500]! : Colors.grey[600]!;

    return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scale(
          duration: 600.ms,
          delay: delay.ms,
          begin: const Offset(1, 1),
          end: const Offset(1.3, 1.3),
          curve: Curves.easeInOut,
        );
  }
}
