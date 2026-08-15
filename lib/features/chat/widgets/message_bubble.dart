import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message.dart';
import '../repositories/chat_repository.dart';
import 'linkable_message_text.dart';
import 'system_message_widget.dart';

class MessageBubble extends ConsumerWidget {
  final Message message;
  final bool isMe;
  final bool isGroup;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final Function(LongPressStartDetails) onLongPress;
  final VoidCallback? onSwipeReply;
  final Function(String url)? onImageTap;
  final Function(String url, String msgId)? onAudioPlay;
  final bool isAudioPlaying;
  final Duration audioPosition;
  final Duration audioDuration;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.isGroup = false,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    required this.onLongPress,
    this.onSwipeReply,
    this.onImageTap,
    this.onAudioPlay,
    this.isAudioPlaying = false,
    this.audioPosition = Duration.zero,
    this.audioDuration = Duration.zero,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Check for System Message
    if (message.isSystemMessage) {
      if (isMe) {
        return const SystemMessageWidget(
          message: 'انضممت إلى المجموعة',
          icon: Icons.person_add,
        );
      } else {
        return _SystemMessageLoader(userId: message.senderId);
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Enhanced dynamic corner radius
    const double rLarge = 18.0;
    const double rSmall = 4.0;

    final BorderRadius borderRadius = BorderRadius.only(
      topLeft: Radius.circular(
        isMe ? rLarge : (isFirstInGroup ? rLarge : rSmall),
      ),
      topRight: Radius.circular(
        isMe ? (isFirstInGroup ? rLarge : rSmall) : rLarge,
      ),
      bottomLeft: Radius.circular(
        isMe ? rLarge : (isLastInGroup ? rSmall : rLarge),
      ),
      bottomRight: Radius.circular(
        isMe ? (isLastInGroup ? rSmall : rLarge) : rLarge,
      ),
    );

    // Get decoration based on sender and theme
    final decoration = _getBubbleDecoration(context, borderRadius, isDark);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              // SENDER AVATAR (Left side if !isMe in Group)
              if (!isMe && isGroup && isFirstInGroup) ...[
                _UserAvatar(userId: message.senderId, size: 28),
                const SizedBox(width: 8),
              ] else if (!isMe && isGroup) ...[
                const SizedBox(width: 36), // Indent for subsequent messages
              ],

              GestureDetector(
                    onLongPressStart: onLongPress,
                    child: Container(
                      margin: EdgeInsets.only(
                        top: 2,
                        bottom: isLastInGroup ? 2 : 1, // Reduced bottom margin
                        left: 0, // Reset manual margins, handled by Row/Align
                        right: 0,
                      ),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      decoration: decoration,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Reply Preview
                                if (message.replyToId != null)
                                  _buildReplyPreview(context),

                                // Content
                                if (message.type == 'image')
                                  _buildImage(context, ref)
                                else if (message.type == 'audio')
                                  _buildAudio(context)
                                else if (message.type == 'file')
                                  _buildFile(context, ref)
                                else
                                  _buildText(context),

                                // Footer (Time & Status)
                                _buildFooter(context),
                              ],
                            ),
                          ),

                          // Reactions Overhead
                          if (message.reactions != null &&
                              message.reactions!.isNotEmpty)
                            Positioned(
                              bottom: -10,
                              right: isMe ? null : 0,
                              left: isMe ? 0 : null,
                              child: _buildReactionBadge(context),
                            ),
                        ],
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
            ],
          ),

          // READ RECEIPTS
          if (isMe && isLastInGroup && message.readBy.isNotEmpty)
            _buildReadReceipts(context, ref),
        ],
      ),
    );
  }

  BoxDecoration _getBubbleDecoration(
    BuildContext context,
    BorderRadius borderRadius,
    bool isDark,
  ) {
    if (isMe) {
      // My messages: gradient background
      final theme = Theme.of(context);
      return BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      );
    } else {
      // Other's messages: solid color based on theme
      final theme = Theme.of(context);
      return BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceVariant
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      );
    }
  }

  Widget _buildReadReceipts(BuildContext context, WidgetRef ref) {
    final readers = message.readBy.toSet().toList();
    if (readers.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 2, right: 4),
      child: SizedBox(
        height: 16,
        child: Stack(
          alignment: Alignment.centerRight,
          children: [
            for (int i = 0; i < readers.length && i < 5; i++)
              Positioned(
                right: i * 12.0,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: 1,
                    ),
                  ),
                  child: _UserAvatar(userId: readers[i], size: 14),
                ),
              ),
            if (readers.length > 5)
              Positioned(
                right: 5 * 12.0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '+',
                      style: TextStyle(
                        fontSize: 8,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreview(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isMe
        ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.7)
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final iconColor = isMe
        ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.6)
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.shadow.withOpacity(isDark ? 0.2 : 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMe
                ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.9)
                : Theme.of(context).colorScheme.primary,
            width: 3,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.reply, size: 12, color: iconColor),
          const SizedBox(width: 4),
          Text(
            'رد على رسالة',
            style: TextStyle(
              fontSize: 10,
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildText(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: LinkableMessageText(
        text: message.text,
        style: TextStyle(
          fontSize: 16,
          height: 1.3,
          color: isMe
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context, WidgetRef ref) {
    if (message.imageUrl != null) {
      print(
        'DEBUG: _buildImage - messageId=${message.id}, imageUrl=${message.imageUrl}',
      );
    } else {
      print('DEBUG: _buildImage - messageId=${message.id}, imageUrl is NULL!');
    }

    final isTransferring = message.status == MessageStatus.sending || 
                           message.status == MessageStatus.receiving;

    return GestureDetector(
      onTap: () => onImageTap?.call(message.imageUrl ?? ''),
      child: Hero(
        tag: message.imageUrl ?? message.id,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            alignment: Alignment.center,
            children: [
              _getImageWidget(context, message.imageUrl),
              if (isTransferring) _buildUploadOverlay(context, ref),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadOverlay(BuildContext context, WidgetRef ref) {
    final uploadStateAsync = ref.watch(uploadProgressProvider(message.id));

    return uploadStateAsync.when(
      data: (progress) {
        final pct = (progress.progress * 100).toInt();
        final isCancelled = progress.status.name == 'cancelled';
        final isFailed = progress.status.name == 'failed';
        final isCompressing = progress.status.name == 'compressing';
        
        if (progress.status.name == 'sent') return const SizedBox.shrink();

        return Container(
          color: Colors.black.withValues(alpha: 0.5),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCancelled || isFailed)
                  const Icon(Icons.error_outline, color: Colors.white, size: 40)
                else
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress.progress > 0 ? progress.progress : null,
                        color: Colors.white,
                      ),
                      if (isCompressing)
                        const Icon(Icons.compress, color: Colors.white, size: 20)
                      else
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 20),
                          onPressed: () {
                            ref.read(chatRepositoryProvider).cancelUpload(message.id);
                          },
                        ),
                    ],
                  ),
                const SizedBox(height: 8),
                Text(
                  isCancelled ? 'Cancelled' : 
                  isFailed ? 'Failed' : 
                  isCompressing ? 'Compressing...' : '$pct%',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ).animate().fadeIn(duration: 200.ms),
          ),
        );
      },
      loading: () => Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _getImageWidget(BuildContext context, String? url) {
    if (url == null || url.isEmpty) {
      print('DEBUG: _getImageWidget - url is null or empty');
      return const Icon(Icons.broken_image);
    }

    print('DEBUG: _getImageWidget - url=$url');

    Widget image;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      // Network image
      print('DEBUG: Loading network image');
      image = Image.network(
        url,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return SizedBox(
            width: 200,
            height: 200,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) {
          print('DEBUG: Network image error');
          return const Icon(Icons.broken_image);
        },
      );
    } else {
      // Local file path (handles Windows paths like C:\Users\...)
      // Remove file:// prefix if present
      final cleanPath = url.replaceFirst('file://', '');
      final file = File(cleanPath);

      print('DEBUG: Checking local file: $cleanPath');
      print('DEBUG: File exists: ${file.existsSync()}');

      if (file.existsSync()) {
        try {
          final fileSize = file.lengthSync();
          print('DEBUG: File size: ${(fileSize / 1024).toStringAsFixed(1)} KB');

          image = Image.file(
            file,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              print('DEBUG: Image.file error: $error');
              return const Icon(Icons.broken_image);
            },
          );
        } catch (e) {
          print('DEBUG: Error loading file image: $e');
          return _tryBase64Image(context, url);
        }
      } else {
        // File doesn't exist, try as Base64 fallback
        print('DEBUG: File does not exist, trying Base64');
        return _tryBase64Image(context, url);
      }
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 280, maxHeight: 400),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: image,
    );
  }

  Widget _tryBase64Image(BuildContext context, String url) {
    try {
      // Check if it looks like Base64 (long string, no spaces, valid chars)
      if (url.length > 50 &&
          !url.contains(' ') &&
          RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(url)) {
        final bytes = base64Decode(url);
        return Container(
          constraints: const BoxConstraints(maxWidth: 280, maxHeight: 400),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Image.memory(bytes, fit: BoxFit.contain),
        );
      }
    } catch (e) {
      // Not Base64, return error
    }
    return const Center(child: Icon(Icons.broken_image));
  }

  Widget _buildAudio(BuildContext context) {
    final durationText = _formatDuration(
      isAudioPlaying ? audioPosition : audioDuration,
    );

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final otherBgColor = isDark
        ? theme.colorScheme.surfaceVariant
        : theme.colorScheme.surfaceContainerHighest;
    final otherContentColor = theme.colorScheme.onSurfaceVariant;
    final otherWaveColor = theme.colorScheme.outline.withOpacity(0.5);

    return Container(
      constraints: const BoxConstraints(maxWidth: 280, minWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: isMe
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary.withOpacity(0.2),
                  theme.colorScheme.primary.withOpacity(0.1),
                ],
              )
            : null,
        color: isMe ? null : otherBgColor,
        borderRadius: BorderRadius.circular(16),
        border: isMe
            ? null
            : Border.all(
                color: theme.colorScheme.outline.withOpacity(0.2),
                width: 1,
              ),
        boxShadow: [
          BoxShadow(
            color: (isMe ? theme.colorScheme.primary : theme.colorScheme.shadow)
                .withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Play/Pause Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () =>
                  onAudioPlay?.call(message.audioUrl ?? '', message.id),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: isMe
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.colorScheme.surface,
                            theme.colorScheme.surface.withOpacity(0.8),
                          ],
                        )
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.primary.withOpacity(0.8),
                          ],
                        ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                          (isMe
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.primary)
                              .withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  isAudioPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: isMe
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onPrimary,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Waveform and Duration
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Waveform
                SizedBox(
                  height: 28,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(20, (index) {
                      final height = 8.0 + (index % 4) * 4.0;
                      final isActive = isAudioPlaying && (index % 3 == 0);
                      return Container(
                            width: 3,
                            height: isActive ? height * 1.3 : height,
                            margin: const EdgeInsets.symmetric(horizontal: 0.5),
                            decoration: BoxDecoration(
                              gradient: isMe
                                  ? LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        theme.colorScheme.onPrimary.withOpacity(
                                          0.9,
                                        ),
                                        theme.colorScheme.onPrimary.withOpacity(
                                          0.6,
                                        ),
                                      ],
                                    )
                                  : LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        theme.colorScheme.primary.withOpacity(
                                          0.8,
                                        ),
                                        theme.colorScheme.primary.withOpacity(
                                          0.5,
                                        ),
                                      ],
                                    ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          )
                          .animate(
                            target: isActive ? 1 : 0,
                            onPlay: (c) => c.repeat(reverse: true),
                          )
                          .scaleY(
                            begin: 1,
                            end: 1.2,
                            duration: 300.ms,
                            curve: Curves.easeInOut,
                          );
                    }),
                  ),
                ),
                const SizedBox(height: 6),
                // Duration
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (isMe
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surfaceContainerHighest)
                            .withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    durationText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: isMe
                          ? theme.colorScheme.onPrimary.withOpacity(0.9)
                          : otherContentColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 2, top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (message.isEdited)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                'معدلة',
                style: TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: isMe
                      ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.7)
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          Text(
            "${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}",
            style: TextStyle(
              fontSize: 10,
              color: isMe
                  ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.7)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (isMe) ...[const SizedBox(width: 4), _buildStatusIcon(context)],
        ],
      ),
    );
  }

  Widget _buildStatusIcon(BuildContext context) {
    IconData icon;
    Color color;

    final theme = Theme.of(context);
    switch (message.status) {
      case MessageStatus.sending:
        icon = Icons.access_time_rounded;
        color = theme.colorScheme.onPrimary.withOpacity(0.6);
        break;
      case MessageStatus.failed:
        icon = Icons.error_outline_rounded;
        color = theme.colorScheme.error;
        break;
      case MessageStatus.sent:
        icon = Icons.check_rounded;
        color = theme.colorScheme.onPrimary.withOpacity(0.6);
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all_rounded;
        color = theme.colorScheme.onPrimary.withOpacity(0.6);
        break;
      case MessageStatus.read:
        icon = Icons.done_all_rounded;
        color = theme.colorScheme.primary;
        break;
      case MessageStatus.receiving:
        icon = Icons.downloading_rounded;
        color = theme.colorScheme.primary;
        break;
    }

    if (message.isRead) {
      icon = Icons.done_all_rounded;
      color = theme.colorScheme.primary;
    }

    return Icon(icon, size: 14, color: color);
  }

  Widget _buildReactionBadge(BuildContext context) {
    if (message.reactions == null || message.reactions!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        message.reactions!.values.toSet().join(' '),
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d == Duration.zero) return "0:00";
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "${d.inMinutes}:$twoDigitSeconds";
  }

  Widget _buildFile(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isTransferring = message.status == MessageStatus.sending ||
                           message.status == MessageStatus.receiving;

    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe
            ? theme.colorScheme.primary.withOpacity(0.1)
            : (isDark
                  ? theme.colorScheme.surfaceVariant
                  : theme.colorScheme.surfaceContainerHighest),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.insert_drive_file,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.fileName ?? 'ملف',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isMe
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message.fileSize != null
                          ? '${(message.fileSize! / 1024).toStringAsFixed(1)} KB'
                          : 'ملف',
                      style: TextStyle(
                        fontSize: 10,
                        color: isMe
                            ? theme.colorScheme.onPrimary.withOpacity(0.7)
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isTransferring) ...[
            const SizedBox(height: 12),
            Consumer(
              builder: (context, ref, child) {
                final uploadStateAsync = ref.watch(uploadProgressProvider(message.id));
                return uploadStateAsync.when(
                  data: (progress) {
                    final pct = (progress.progress * 100).toInt();
                    final speedKB = progress.speed / 1024;
                    final isCancelled = progress.status.name == 'cancelled';
                    final isFailed = progress.status.name == 'failed';
                    
                    if (progress.status.name == 'sent') return const SizedBox.shrink();
                    
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: isCancelled || isFailed ? 0 : (progress.progress > 0 ? progress.progress : null),
                                  backgroundColor: theme.colorScheme.surface.withOpacity(0.3),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isCancelled || isFailed ? Colors.red :
                                    (isMe ? theme.colorScheme.onPrimary : theme.colorScheme.primary),
                                  ),
                                  minHeight: 4,
                                ),
                              ),
                            ),
                            if (!isCancelled && !isFailed)
                              IconButton(
                                icon: Icon(Icons.close, size: 16, color: isMe ? theme.colorScheme.onPrimary : theme.colorScheme.primary),
                                onPressed: () {
                                  ref.read(chatRepositoryProvider).cancelUpload(message.id);
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isCancelled ? 'Cancelled' :
                              isFailed ? 'Failed' :
                              message.status == MessageStatus.sending
                                  ? 'جاري الإرسال... (${speedKB.toStringAsFixed(1)} KB/s)'
                                  : 'جاري التحميل... (${speedKB.toStringAsFixed(1)} KB/s)',
                              style: TextStyle(fontSize: 10, color: isCancelled || isFailed ? Colors.red : null),
                            ),
                            if (!isCancelled && !isFailed && progress.progress > 0)
                              Text(
                                '$pct%',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                  loading: () => LinearProgressIndicator(
                    backgroundColor: theme.colorScheme.surface.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isMe ? theme.colorScheme.onPrimary : theme.colorScheme.primary,
                    ),
                  ),
                  error: (_, __) => const Text('Error', style: TextStyle(color: Colors.red)),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

// Stateful loader for system message user names
class _SystemMessageLoader extends ConsumerStatefulWidget {
  final String userId;

  const _SystemMessageLoader({
    required this.userId,
    // ref is managed by ConsumerState
  });

  @override
  ConsumerState<_SystemMessageLoader> createState() =>
      _SystemMessageLoaderState();
}

class _SystemMessageLoaderState extends ConsumerState<_SystemMessageLoader> {
  String userName = 'عضو جديد';

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  void _loadName() async {
    final user = await ref
        .read(chatRepositoryProvider)
        .getUserData(widget.userId);
    if (mounted && user != null && user.displayName.isNotEmpty) {
      setState(() {
        userName = user.displayName;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SystemMessageWidget(
      message: '$userName انضم للمجموعة',
      icon: Icons.person_add,
    );
  }
}

class _UserAvatar extends ConsumerStatefulWidget {
  final String userId;
  final double size;

  const _UserAvatar({required this.userId, required this.size});

  @override
  ConsumerState<_UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends ConsumerState<_UserAvatar> {
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _loadUser() async {
    final user = await ref
        .read(chatRepositoryProvider)
        .getUserData(widget.userId);
    if (mounted && user != null) {
      setState(() {
        _photoUrl = user.photoURL;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;
    if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      if (_photoUrl!.startsWith('http')) {
        imageProvider = NetworkImage(_photoUrl!);
      } else {
        try {
          imageProvider = MemoryImage(base64Decode(_photoUrl!));
        } catch (_) {}
      }
    }

    return CircleAvatar(
      radius: widget.size / 2,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      backgroundImage: imageProvider,
      child: imageProvider == null
          ? Icon(
              Icons.person,
              size: widget.size * 0.6,
              color: Theme.of(context).colorScheme.onSurface,
            )
          : null,
    );
  }
}
