import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class UnreadBadge extends StatelessWidget {
  final int count;
  final bool isMuted;

  const UnreadBadge({super.key, required this.count, this.isMuted = false});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    final displayCount = count > 99 ? '99+' : count.toString();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
          constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            gradient: isMuted
                ? null
                : LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: isMuted ? Colors.grey.shade400 : null,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isMuted
                ? null
                : [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Text(
            displayCount,
            style: TextStyle(
              color: isMuted
                  ? (isDark ? Colors.grey.shade800 : Colors.white)
                  : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
        )
        .animate()
        .scale(duration: 200.ms, curve: Curves.easeOutBack)
        .fadeIn(duration: 150.ms);
  }
}
