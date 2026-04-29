import 'dart:io';

import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/chat/models/chat_message_model.dart';

class UploadingMediaBubble extends StatelessWidget {
  const UploadingMediaBubble({
    super.key,
    required this.file,
    required this.type,
    this.progress,
  });

  final File file;
  final MessageType type;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          if (type == MessageType.image)
            Image.file(file, width: 180, height: 130, fit: BoxFit.cover)
          else
            Container(
              width: 180,
              height: 60,
              color: cs.surfaceContainerHighest,
              child: Icon(
                type == MessageType.audio
                    ? Icons.audio_file_rounded
                    : Icons.video_file_rounded,
                color: cs.onSurfaceVariant,
                size: 28,
              ),
            ),
          Positioned.fill(
            child: Container(
              color: Colors.black38,
              child: Center(
                child: CircularProgressIndicator(
                  value: progress,
                  color: Colors.white,
                  strokeWidth: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
