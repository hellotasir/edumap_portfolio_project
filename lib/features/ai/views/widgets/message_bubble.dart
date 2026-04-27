import 'package:flutter/material.dart';
import 'package:flutter_education_app/core/services/cloud/ai_chat_service.dart';
import 'package:flutter_education_app/features/ai/views/widgets/typing_Indicator.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final AiChatMessage message;

  bool get _isUser => message.role == MessageRole.user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final bubbleColor = message.isError
        ? cs.errorContainer
        : _isUser
        ? cs.primaryContainer
        : cs.surfaceContainerHighest;

    final textColor = message.isError
        ? cs.onErrorContainer
        : _isUser
        ? cs.onPrimaryContainer
        : cs.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: _isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!_isUser) ...[const AiAvatar(), const SizedBox(width: 8)],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(_isUser ? 16 : 4),
                  bottomRight: Radius.circular(_isUser ? 4 : 16),
                ),
              ),
              child: Text(
                message.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  height: 1.45,
                ),
              ),
            ),
          ),
          if (_isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
