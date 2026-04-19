import 'package:flutter/material.dart';
import 'package:flutter_education_app/features/chat/models/conversation_model.dart';
import 'package:flutter_education_app/features/chat/models/user_preference_model.dart';
import 'package:flutter_education_app/features/chat/repositories/chat_repository.dart';
import 'package:flutter_education_app/features/chat/views/widgets/shared/avatar.dart';
import 'package:flutter_education_app/features/chat/views/widgets/shared/empty_state.dart';

class FriendsTab extends StatefulWidget {
  const FriendsTab({
    super.key,
    required this.currentUserId,
    required this.currentUsername,
    required this.currentProfilePhoto,
    required this.chatRepository,
    required this.onOpenChat,
  });

  final String currentUserId;
  final String currentUsername;
  final String currentProfilePhoto;
  final ChatRepository chatRepository;
  final void Function(ConversationModel) onOpenChat;

  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> {
  late Future<List<Map<String, dynamic>>> _friendsFuture;

  @override
  void initState() {
    super.initState();
    _friendsFuture = widget.chatRepository.getFriendsList(widget.currentUserId);
  }

  void _reloadFriends() {
    setState(() {
      _friendsFuture = widget.chatRepository.getFriendsList(
        widget.currentUserId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _friendsFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        final friends = snap.data ?? [];

        if (friends.isEmpty) {
          return const EmptyState(
            icon: Icons.people_outline_rounded,
            title: 'No friends yet',
            subtitle: 'Search for people and send friend requests',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 4, bottom: 120),
          itemCount: friends.length,
          itemBuilder: (context, i) {
            final friend = friends[i];
            final friendId =
                friend['user_id'] as String? ?? friend['id'] as String? ?? '';
            final username = friend['username'] as String? ?? 'Unknown';
            final fullName = friend['full_name'] as String? ?? '';
            final photoUrl = friend['profile_photo'] as String? ?? '';
            final friendDocId = friend['friend_doc_id'] as String? ?? '';

            final displayName = fullName.isNotEmpty ? fullName : username;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 4,
              ),
              leading: StreamBuilder<UserPresenceModel>(
                stream: widget.chatRepository.watchPresence(friendId),
                builder: (context, presSnap) {
                  final isOnline = presSnap.data?.isOnline ?? false;
                  return Avatar(
                    displayName: displayName,
                    photoUrl: photoUrl.isNotEmpty ? photoUrl : null,
                    isOnline: isOnline,
                    showPresence: true,
                  );
                },
              ),
              title: Text(
                displayName,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
              subtitle: fullName.isNotEmpty
                  ? Text(
                      '@$username',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    )
                  : null,
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (value) async {
                  if (value == 'message') {
                    ConversationModel? conv = await widget.chatRepository
                        .getIndividualConversation(
                          widget.currentUserId,
                          friendId,
                        );
                    conv ??= await widget.chatRepository
                        .createIndividualConversation(
                          currentUserId: widget.currentUserId,
                          currentUsername: widget.currentUsername,
                          otherUserId: friendId,
                          otherUsername: username,
                        );
                    if (context.mounted) widget.onOpenChat(conv);
                  } else if (value == 'remove') {
                    await _confirmRemoveFriend(
                      context,
                      friendDocId: friendDocId,
                      name: displayName,
                    );
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'message',
                    child: Row(
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 18),
                        SizedBox(width: 10),
                        Text('Message'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_remove_outlined,
                          size: 18,
                          color: colorScheme.error,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Remove Friend',
                          style: TextStyle(color: colorScheme.error),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              onTap: () async {
                ConversationModel? conv = await widget.chatRepository
                    .getIndividualConversation(widget.currentUserId, friendId);
                conv ??= await widget.chatRepository
                    .createIndividualConversation(
                      currentUserId: widget.currentUserId,
                      currentUsername: widget.currentUsername,
                      otherUserId: friendId,
                      otherUsername: username,
                    );
                if (context.mounted) widget.onOpenChat(conv);
              },
            );
          },
        );
      },
    );
  }

  Future<void> _confirmRemoveFriend(
    BuildContext context, {
    required String friendDocId,
    required String name,
  }) async {
    final colorScheme = Theme.of(context).colorScheme;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove $name?'),
        content: const Text(
          'They will be removed from your friends list. You can still message each other.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            onPressed: () async {
              if (friendDocId.isEmpty) return;
              await widget.chatRepository.removeFriend(friendDocId);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              _reloadFriends();
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
