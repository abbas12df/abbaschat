import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Shimmer effect for profile loading
class ShimmerProfileCard extends StatelessWidget {
  const ShimmerProfileCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Avatar skeleton
          Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
              )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(
                duration: 1200.ms,
                color: Colors.grey.withValues(alpha: 0.2),
              ),
          const SizedBox(height: 16),
          // Name skeleton
          Container(
                height: 24,
                width: 150,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
              )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(
                duration: 1200.ms,
                color: Colors.grey.withValues(alpha: 0.2),
              ),
          const SizedBox(height: 8),
          // Username skeleton
          Container(
                height: 16,
                width: 100,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
              )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(
                duration: 1200.ms,
                color: Colors.grey.withValues(alpha: 0.2),
              ),
          const SizedBox(height: 24),
          // Bio skeleton
          Container(
                width: double.infinity,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
              )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(
                duration: 1200.ms,
                color: Colors.grey.withValues(alpha: 0.2),
              ),
        ],
      ),
    );
  }
}

/// Shimmer effect for user list (search results)
class ShimmerUserList extends StatelessWidget {
  final int itemCount;

  const ShimmerUserList({super.key, this.itemCount = 8});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: itemCount,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 16,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 12,
                          width: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
            .animate(onPlay: (c) => c.repeat())
            .shimmer(
              duration: 1200.ms,
              color: Colors.grey.withValues(alpha: 0.2),
            );
      },
    );
  }
}

/// Simple shimmer spinner for auth screens
class ShimmerLoadingScreen extends StatelessWidget {
  final String? message;

  const ShimmerLoadingScreen({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated logo or icon
            Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    size: 40,
                    color: Theme.of(context).primaryColor,
                  ),
                )
                .animate(onPlay: (c) => c.repeat())
                .fadeIn(duration: 800.ms)
                .then()
                .fadeOut(duration: 800.ms),
            const SizedBox(height: 24),
            if (message != null)
              Text(
                    message!,
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  )
                  .animate(onPlay: (c) => c.repeat())
                  .fadeIn(duration: 1000.ms)
                  .then()
                  .fadeOut(duration: 1000.ms),
          ],
        ),
      ),
    );
  }
}
