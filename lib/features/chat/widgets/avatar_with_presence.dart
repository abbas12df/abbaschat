import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_animate/flutter_animate.dart';

class AvatarWithPresence extends StatelessWidget {
  final String? imageUrl;
  final String fallbackText;
  final Color? backgroundColor;
  final bool isOnline;
  final bool isGroup;
  final double radius;

  const AvatarWithPresence({
    super.key,
    this.imageUrl,
    required this.fallbackText,
    this.backgroundColor,
    this.isOnline = false,
    this.isGroup = false,
    this.radius = 28,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(
                alpha: isDark ? 0.8 : 0.9,
              ),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(
                  alpha: isDark ? 0.35 : 0.12,
                ),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: radius,
            backgroundColor:
                backgroundColor ??
                (isGroup
                    ? theme.colorScheme.secondaryContainer
                    : theme.colorScheme.primaryContainer),
            backgroundImage: _getBackgroundImage(),
            child: _getBackgroundImage() == null
                ? _buildFallback(context)
                : null,
          ),
        ),
        if (isOnline && !isGroup)
          Positioned(
            bottom: 0,
            right: 0,
            child:
                Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF22C55E,
                            ).withValues(alpha: 0.4),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      begin: const Offset(1.0, 1.0),
                      end: const Offset(1.15, 1.15),
                      duration: 1500.ms,
                      curve: Curves.easeInOut,
                    ),
          ),
      ],
    );
  }

  ImageProvider? _getBackgroundImage() {
    if (imageUrl == null || imageUrl!.isEmpty) return null;

    if (imageUrl!.startsWith('http')) {
      return NetworkImage(imageUrl!);
    } else {
      try {
        return MemoryImage(base64Decode(imageUrl!));
      } catch (e) {
        return null;
      }
    }
  }

  Widget _buildFallback(BuildContext context) {
    final firstChar = fallbackText.isNotEmpty ? fallbackText[0] : '?';
    return Text(
      firstChar,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: radius * 0.6,
        color: isGroup ? Theme.of(context).colorScheme.primary : null,
      ),
    );
  }
}
