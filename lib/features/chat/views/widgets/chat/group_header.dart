import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/chat/models/conversation_model.dart';

class GroupHeader extends StatelessWidget {
  const GroupHeader({
    super.key,
    required this.conversation,
    required this.colorScheme,
    required this.textTheme,
  });

  final ConversationModel conversation;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final tt = textTheme;
    final hasPhoto = conversation.groupPhoto?.isNotEmpty ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: cs.surfaceContainerHighest,
            backgroundImage: hasPhoto
                ? NetworkImage(conversation.groupPhoto!)
                : null,
            child: !hasPhoto
                ? Icon(
                    Icons.group_rounded,
                    color: cs.onSurface.withValues(alpha: 0.4),
                    size: 28,
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                conversation.groupName ?? 'Group',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '${conversation.participantIds.length} members',
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
