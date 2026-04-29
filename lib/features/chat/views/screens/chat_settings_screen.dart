import 'package:edumap_portfolio_project/features/app/views/widgets/others/network_widget.dart';
import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/app/views/screens/home_screen.dart';
import 'package:edumap_portfolio_project/features/chat/models/chat_message_model.dart';
import 'package:edumap_portfolio_project/features/chat/models/conversation_model.dart';
import 'package:edumap_portfolio_project/features/chat/models/user_preference_model.dart';
import 'package:edumap_portfolio_project/features/chat/repositories/chat_repository.dart';
import 'package:edumap_portfolio_project/core/routers/app_navigator.dart';
import 'package:edumap_portfolio_project/features/chat/views/widgets/chat/block_unblock_tile.dart';
import 'package:edumap_portfolio_project/features/chat/views/widgets/chat/compact_tile.dart';
import 'package:edumap_portfolio_project/features/chat/views/widgets/chat/group_header.dart';
import 'package:edumap_portfolio_project/features/chat/views/widgets/chat/remove_friend_tile.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'user_search_screen.dart';

class ChatSettingsScreen extends StatelessWidget {
  const ChatSettingsScreen({
    super.key,
    required this.conversation,
    required this.currentUserId,
    required this.currentUsername,
    required this.currentProfilePhoto,
    required this.chatRepository,
  });

  final ConversationModel conversation;
  final String currentUserId;
  final String currentUsername;
  final String currentProfilePhoto;
  final ChatRepository chatRepository;

  bool get _isGroup => conversation.type == ConversationType.group;
  bool get _isGroupAdmin => conversation.createdBy == currentUserId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return NetworkWidget(
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            _isGroup ? 'Group info' : 'Chat settings',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        body: ListView(
          children: [
            _buildHeader(context, cs, tt),
            const SizedBox(height: 8),
            _buildSectionLabel('Participants', cs, tt),
            ..._buildParticipants(context, cs, tt),
            if (_isGroup && _isGroupAdmin) ...[
              const SizedBox(height: 4),
              _buildSectionLabel('Members', cs, tt),
              CompactTile(
                icon: Icons.person_add_outlined,
                iconColor: cs.primary,
                label: 'Add members',
                onTap: () => _openAddMembers(context),
              ),
            ],
            const SizedBox(height: 4),
            _buildSectionLabel('Actions', cs, tt),
            if (!_isGroup)
              RemoveFriendTile(
                currentUserId: currentUserId,
                conversation: conversation,
                chatRepository: chatRepository,
                context: context,
              ),
            if (_isGroup && _isGroupAdmin)
              CompactTile(
                icon: Icons.delete_outline_rounded,
                iconColor: cs.error,
                label: 'Delete group',
                onTap: () => _confirmAction(
                  context,
                  title: 'Delete group?',
                  body:
                      'This will permanently delete the group and all messages.',
                  confirmLabel: 'Delete',
                  onConfirm: () async {
                    await chatRepository.deleteConversation(conversation.id!);
                    if (context.mounted) {
                      AppNavigator(screen: HomeScreen()).navigate(context);
                    }
                  },
                ),
              ),
            if (_isGroup && !_isGroupAdmin)
              CompactTile(
                icon: Icons.exit_to_app_rounded,
                iconColor: Colors.orange,
                label: 'Leave group',
                onTap: () => _confirmAction(
                  context,
                  title: 'Leave group?',
                  body: 'You will stop receiving messages from this group.',
                  confirmLabel: 'Leave',
                  onConfirm: () async {
                    await chatRepository.removeMemberFromGroup(
                      conversationId: conversation.id!,
                      userId: currentUserId,
                    );
                    if (context.mounted) {
                      AppNavigator(screen: HomeScreen()).navigate(context);
                    }
                  },
                ),
              ),
            if (!_isGroup)
              CompactTile(
                icon: Icons.delete_outline_rounded,
                iconColor: cs.error,
                label: 'Delete conversation',
                onTap: () => _confirmAction(
                  context,
                  title: 'Delete conversation?',
                  body:
                      'This conversation and all messages will be permanently deleted.',
                  confirmLabel: 'Delete',
                  onConfirm: () async {
                    await chatRepository.deleteConversation(conversation.id!);
                    if (context.mounted) {
                      AppNavigator(screen: HomeScreen()).navigate(context);
                    }
                  },
                ),
              ),
            if (!_isGroup)
              BlockUnblockTile(
                currentUserId: currentUserId,
                conversation: conversation,
                chatRepository: chatRepository,
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme cs, TextTheme tt) {
    if (_isGroup) {
      return GroupHeader(
        conversation: conversation,
        colorScheme: cs,
        textTheme: tt,
      );
    }

    final otherUserId = conversation.participantIds.firstWhere(
      (e) => e != currentUserId,
      orElse: () => '',
    );

    return FutureBuilder<Map<String, dynamic>?>(
      future: chatRepository.getUserProfile(otherUserId),
      builder: (context, snap) {
        final profile = snap.data;
        final fullName = profile?['full_name'] as String? ?? '';
        final photoUrl = profile?['profile_photo'] as String? ?? '';
        final username =
            conversation.participantUsernames[otherUserId] ?? 'User';
        final displayName = fullName.isNotEmpty ? fullName : username;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: cs.surfaceContainerHighest,
                backgroundImage: photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl.isEmpty
                    ? Icon(
                        Icons.person_rounded,
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
                    displayName,
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (fullName.isNotEmpty)
                    Text(
                      '@$username',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionLabel(String label, ColorScheme cs, TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        label,
        style: tt.labelSmall?.copyWith(
          color: cs.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  List<Widget> _buildParticipants(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt,
  ) {
    return conversation.participantIds.map((userId) {
      final username = conversation.participantUsernames[userId] ?? 'Unknown';
      final isMe = userId == currentUserId;
      final isCreator = userId == conversation.createdBy;

      return FutureBuilder<Map<String, dynamic>?>(
        future: chatRepository.getUserProfile(userId),
        builder: (context, profileSnap) {
          final profile = profileSnap.data;
          final fullName = profile?['full_name'] as String? ?? '';
          final photoUrl = profile?['profile_photo'] as String? ?? '';
          final displayName = fullName.isNotEmpty ? fullName : username;

          return StreamBuilder<UserPresenceModel>(
            stream: chatRepository.watchPresence(userId),
            builder: (context, snap) {
              final isOnline = snap.data?.isOnline ?? false;
              final lastSeen = snap.data?.lastSeen;

              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 0,
                ),
                leading: Stack(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: cs.surfaceContainerHighest,
                      backgroundImage: photoUrl.isNotEmpty
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl.isEmpty
                          ? Text(
                              displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
                                  : '?',
                              style: tt.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: isOnline
                              ? const Color(0xFF4CAF50)
                              : cs.onSurface.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: cs.surface, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
                title: Row(
                  children: [
                    Text(
                      isMe ? '$displayName (You)' : displayName,
                      style: tt.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isCreator) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Admin',
                          style: tt.labelSmall?.copyWith(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  isOnline
                      ? 'Online'
                      : lastSeen != null
                      ? 'Last seen ${timeago.format(lastSeen)}'
                      : 'Offline',
                  style: tt.labelSmall?.copyWith(
                    fontSize: 10,
                    color: isOnline
                        ? const Color(0xFF4CAF50)
                        : cs.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                trailing: (_isGroup && _isGroupAdmin && !isMe)
                    ? IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 18),
                        color: cs.error,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _confirmAction(
                          context,
                          title: 'Remove $displayName?',
                          body: '$displayName will be removed from this group.',
                          confirmLabel: 'Remove',
                          onConfirm: () => chatRepository.removeMemberFromGroup(
                            conversationId: conversation.id!,
                            userId: userId,
                          ),
                        ),
                      )
                    : null,
              );
            },
          );
        },
      );
    }).toList();
  }

  void _openAddMembers(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserSearchScreen(
          currentUserId: currentUserId,
          currentUsername: currentUsername,
          currentProfilePhoto: currentProfilePhoto,
          chatRepository: chatRepository,
          groupConversationId: conversation.id,
          existingMemberIds: conversation.participantIds,
        ),
      ),
    );
  }

  Future<void> _confirmAction(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
    required Future<void> Function() onConfirm,
  }) async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: cs.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    if (confirmed == true) await onConfirm();
  }
}





