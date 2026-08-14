import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ChatListSkeleton extends StatelessWidget {
  final int itemCount;

  const ChatListSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmerColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.05);

    return ListView.builder(
      itemCount: itemCount,
      padding: const EdgeInsets.only(top: 8),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar skeleton
              Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: shimmerColor,
                      shape: BoxShape.circle,
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat())
                  .shimmer(
                    duration: 1500.ms,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.1),
                  ),
              const SizedBox(width: 12),
              // Content skeleton
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name skeleton
                    Container(
                          width: double.infinity,
                          height: 16,
                          decoration: BoxDecoration(
                            color: shimmerColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        )
                        .animate(onPlay: (c) => c.repeat())
                        .shimmer(
                          duration: 1500.ms,
                          delay: 100.ms,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.1),
                        ),
                    const SizedBox(height: 8),
                    // Message skeleton
                    Container(
                          width: MediaQuery.of(context).size.width * 0.6,
                          height: 14,
                          decoration: BoxDecoration(
                            color: shimmerColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        )
                        .animate(onPlay: (c) => c.repeat())
                        .shimmer(
                          duration: 1500.ms,
                          delay: 200.ms,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.1),
                        ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Timestamp skeleton
              Container(
                    width: 40,
                    height: 12,
                    decoration: BoxDecoration(
                      color: shimmerColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat())
                  .shimmer(
                    duration: 1500.ms,
                    delay: 300.ms,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.1),
                  ),
            ],
          ),
        );
      },
    );
  }
}
