import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/chat/models/chat_message_model.dart';
import 'package:edumap_portfolio_project/features/chat/views/widgets/chat/file_message_content.dart';
import 'package:edumap_portfolio_project/features/chat/views/widgets/chat/status_icon.dart';
import 'package:edumap_portfolio_project/features/chat/views/widgets/shared/audio_message_bubble.dart';
import 'package:edumap_portfolio_project/features/chat/views/widgets/shared/image_message_bubble.dart';
import 'package:edumap_portfolio_project/features/chat/views/widgets/shared/video_message_bubble.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.msg,
    required this.isMe,
    required this.isFirst,
    required this.isLast,
    required this.showSenderLabel,
    required this.isGroup,
    required this.cs,
    required this.tt,
    required this.downloadingFiles,
    required this.onDelete,
    required this.onDownload,
    required this.onTapSender,
  });

  final ChatMessageModel msg;
  final bool isMe;
  final bool isFirst;
  final bool isLast;
  final bool showSenderLabel;
  final bool isGroup;
  final ColorScheme cs;
  final TextTheme tt;
  final Set<String> downloadingFiles;
  final VoidCallback onDelete;
  final VoidCallback onDownload;
  final VoidCallback onTapSender;

  static const _r = Radius.circular(22);
  static const _rSmall = Radius.circular(6);

  @override
  Widget build(BuildContext context) {
    final isDeleted = msg.isDeleted;
    final isMedia =
        msg.type == MessageType.image ||
        msg.type == MessageType.video ||
        msg.type == MessageType.audio;

    final bubbleColor = isDeleted
        ? cs.surfaceContainerLowest
        : isMe
        ? cs.primary
        : cs.surfaceContainerHigh;

    final textColor = isDeleted
        ? cs.onSurface.withOpacity(0.3)
        : isMe
        ? cs.onPrimary
        : cs.onSurface;

    final borderRadius = BorderRadius.only(
      topLeft: (!isMe && !isFirst) ? _rSmall : _r,
      topRight: (isMe && !isFirst) ? _rSmall : _r,
      bottomLeft: isMe ? _r : (isLast ? _r : _rSmall),
      bottomRight: isMe ? (isLast ? _r : _rSmall) : _r,
    );

    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 8 : 2, bottom: isLast ? 4 : 1),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && isGroup) ...[
            if (isLast)
              GestureDetector(
                onTap: onTapSender,
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    msg.senderUsername.isNotEmpty
                        ? msg.senderUsername[0].toUpperCase()
                        : '?',
                    style: tt.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(width: 28),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: isMe && !isDeleted ? onDelete : null,
              child: Container(
                margin: EdgeInsets.only(
                  left: isMe ? 72 : 0,
                  right: isMe ? 0 : 72,
                ),
                padding: isMedia
                    ? EdgeInsets.zero
                    : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: isMedia
                    ? null
                    : BoxDecoration(
                        color: bubbleColor,
                        borderRadius: borderRadius,
                      ),
                child: ClipRRect(
                  borderRadius: isMedia ? borderRadius : BorderRadius.zero,
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showSenderLabel && !isMedia)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: GestureDetector(
                            onTap: onTapSender,
                            child: Text(
                              msg.senderUsername,
                              style: tt.labelSmall?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      _buildContent(
                        isDeleted,
                        isMedia,
                        isMe,
                        bubbleColor,
                        borderRadius,
                        textColor,
                      ),
                      if (!isMedia)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatTime(msg.sentAt),
                                style: tt.labelSmall?.copyWith(
                                  fontSize: 10,
                                  color: isMe
                                      ? cs.onPrimary.withOpacity(0.55)
                                      : cs.onSurface.withOpacity(0.35),
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 3),
                                StatusIcon(status: msg.status, cs: cs),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    bool isDeleted,
    bool isMedia,
    bool isMe,
    Color bubbleColor,
    BorderRadius borderRadius,
    Color textColor,
  ) {
    if (isDeleted) {
      return Text(
        msg.content,
        style: tt.bodyMedium?.copyWith(
          color: textColor,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    switch (msg.type) {
      case MessageType.image:
        return ImageMessageBubble(message: msg, isMe: isMe);

      case MessageType.audio:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: borderRadius,
          ),
          child: AudioMessageBubble(message: msg, isMe: isMe),
        );

      case MessageType.video:
        return VideoMessageBubble(message: msg, isMe: isMe);

      case MessageType.file:
        return FileMessageContent(
          msg: msg,
          isMe: isMe,
          cs: cs,
          tt: tt,
          bubbleColor: bubbleColor,
          borderRadius: borderRadius,
          isDownloading: downloadingFiles.contains(
            msg.id ?? msg.mediaUrl ?? '',
          ),
          onDownload: onDownload,
        );

      default:
        return Text(
          msg.content,
          style: tt.bodyMedium?.copyWith(color: textColor),
        );
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
