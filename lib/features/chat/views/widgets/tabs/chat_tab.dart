import 'package:flutter/material.dart';
import 'package:flutter_education_app/features/chat/models/chat_message_model.dart';
import 'package:flutter_education_app/features/chat/models/conversation_model.dart';
import 'package:flutter_education_app/features/chat/models/user_preference_model.dart';
import 'package:flutter_education_app/features/chat/repositories/chat_repository.dart';
import 'package:flutter_education_app/features/chat/views/widgets/shared/avatar.dart';
import 'package:flutter_education_app/features/chat/views/widgets/shared/empty_state.dart';
import 'package:flutter_education_app/features/chat/views/widgets/shared/unread_badge.dart';
import 'package:timeago/timeago.dart' as timeago;

class ChatsTab extends StatelessWidget {
  const ChatsTab({
    super.key,
    required this.currentUserId,
    required this.chatRepository,
    required this.onOpenChat,
  });

  final String currentUserId;
  final ChatRepository chatRepository;
  final void Function(ConversationModel) onOpenChat;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConversationModel>>(
      stream: chatRepository.watchConversations(currentUserId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        final conversations = snap.data ?? [];

        if (conversations.isEmpty) {
          return const EmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'No conversations yet',
            subtitle: 'Search for someone to start chatting',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 4, bottom: 120),
          itemCount: conversations.length,
          itemBuilder: (context, i) {
            final conv = conversations[i];
            final isGroup = conv.type == ConversationType.group;
            final otherUserId = isGroup
                ? ''
                : conv.participantIds.firstWhere(
                    (id) => id != currentUserId,
                    orElse: () => '',
                  );

            if (!isGroup && otherUserId.isNotEmpty) {
              return FutureBuilder<Map<String, dynamic>?>(
                future: chatRepository.getUserProfile(otherUserId),
                builder: (context, profileSnap) {
                  final profile = profileSnap.data;
                  final displayName =
                      (profile?['full_name'] as String?)?.isNotEmpty == true
                      ? profile!['full_name'] as String
                      : (conv.participantUsernames[otherUserId] ?? 'Unknown');
                  final photoUrl = profile?['profile_photo'] as String? ?? '';
                  final unread = conv.unreadCounts[currentUserId] ?? 0;

                  return StreamBuilder<UserPresenceModel>(
                    stream: chatRepository.watchPresence(otherUserId),
                    builder: (context, presSnap) {
                      final isOnline = presSnap.data?.isOnline ?? false;
                      return _ConversationTile(
                        displayName: displayName,
                        lastMessage: conv.lastMessage,
                        lastMessageAt: conv.lastMessageAt,
                        unread: unread,
                        isOnline: isOnline,
                        isGroup: false,
                        photoUrl: photoUrl.isNotEmpty ? photoUrl : null,
                        onTap: () => onOpenChat(conv),
                      );
                    },
                  );
                },
              );
            }

            final displayName = conv.groupName ?? 'Group';
            final unread = conv.unreadCounts[currentUserId] ?? 0;

            return _ConversationTile(
              displayName: displayName,
              lastMessage: conv.lastMessage,
              lastMessageAt: conv.lastMessageAt,
              unread: unread,
              isOnline: false,
              isGroup: true,
              photoUrl: conv.groupPhoto,
              onTap: () => onOpenChat(conv),
            );
          },
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.displayName,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unread,
    required this.isOnline,
    required this.isGroup,
    required this.photoUrl,
    required this.onTap,
  });

  final String displayName;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unread;
  final bool isOnline;
  final bool isGroup;
  final String? photoUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasUnread = unread > 0;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Avatar(
              displayName: displayName,
              photoUrl: photoUrl,
              isGroup: isGroup,
              isOnline: isOnline,
              showPresence: !isGroup,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight: hasUnread
                                ? FontWeight.w700
                                : FontWeight.w500,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                      if (lastMessageAt != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          timeago.format(lastMessageAt!),
                          style: textTheme.labelSmall?.copyWith(
                            color: hasUnread
                                ? colorScheme.primary
                                : colorScheme.onSurface.withValues(alpha: 0.4),
                            fontWeight: hasUnread
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage ?? 'No messages yet',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(
                              alpha: hasUnread ? 0.75 : 0.4,
                            ),
                            fontWeight: hasUnread
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        UnreadBadge(count: unread),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
