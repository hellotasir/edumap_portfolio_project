import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/chat/models/chat_message_model.dart';

class FileMessageContent extends StatelessWidget {
  const FileMessageContent({
    super.key,
    required this.msg,
    required this.isMe,
    required this.cs,
    required this.tt,
    required this.bubbleColor,
    required this.borderRadius,
    required this.isDownloading,
    required this.onDownload,
  });

  final ChatMessageModel msg;
  final bool isMe;
  final ColorScheme cs;
  final TextTheme tt;
  final Color bubbleColor;
  final BorderRadius borderRadius;
  final bool isDownloading;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final name = msg.mediaFileName ?? 'File';
    final ext = name.contains('.')
        ? name.split('.').last.toUpperCase()
        : 'FILE';
    final size = msg.mediaFileSize != null
        ? _formatFileSize(msg.mediaFileSize!)
        : '';
    final hasUrl = msg.mediaUrl?.isNotEmpty ?? false;

    return GestureDetector(
      onTap: hasUrl && !isDownloading ? onDownload : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: borderRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.white.withOpacity(0.18)
                    : cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  ext,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: isMe ? Colors.white : cs.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: tt.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isMe ? cs.onPrimary : cs.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (size.isNotEmpty)
                    Text(
                      size,
                      style: tt.labelSmall?.copyWith(
                        color: isMe
                            ? cs.onPrimary.withOpacity(0.6)
                            : cs.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (hasUrl)
              SizedBox(
                width: 28,
                height: 28,
                child: isDownloading
                    ? Padding(
                        padding: const EdgeInsets.all(4),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isMe ? cs.onPrimary : cs.primary,
                        ),
                      )
                    : Icon(
                        Icons.download_rounded,
                        size: 22,
                        color: isMe
                            ? cs.onPrimary.withOpacity(0.8)
                            : cs.primary,
                      ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}
