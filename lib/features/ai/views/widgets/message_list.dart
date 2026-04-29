import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/core/services/cloud/ai_chat_service.dart';
import 'package:edumap_portfolio_project/features/ai/views/widgets/message_bubble.dart';
import 'package:edumap_portfolio_project/features/ai/views/widgets/typing_Indicator.dart';

class MessageList extends StatelessWidget {
  const MessageList({
    super.key,
    required this.messages,
    required this.isLoading,
    required this.scrollController,
  });

  final List<AiChatMessage> messages;
  final bool isLoading;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final itemCount = messages.length + (isLoading ? 1 : 0);
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: itemCount,
      itemBuilder: (ctx, i) {
        if (isLoading && i == itemCount - 1) return const TypingIndicator();
        return MessageBubble(message: messages[i]);
      },
    );
  }
}
