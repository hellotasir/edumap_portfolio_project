import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/chat/models/conversation_model.dart';
import 'package:edumap_portfolio_project/features/chat/repositories/chat_repository.dart';
import 'package:edumap_portfolio_project/features/chat/views/widgets/chat/compact_tile.dart';

class RemoveFriendTile extends StatefulWidget {
  const RemoveFriendTile({
    super.key,
    required this.currentUserId,
    required this.conversation,
    required this.chatRepository,
    required this.context,
  });

  final String currentUserId;
  final ConversationModel conversation;
  final ChatRepository chatRepository;
  final BuildContext context;

  @override
  State<RemoveFriendTile> createState() => RemoveFriendTileState();
}

class RemoveFriendTileState extends State<RemoveFriendTile> {
  bool _isFriend = false;
  String? _friendDocId;
  bool _userExists = true;

  @override
  void initState() {
    super.initState();
    _checkFriendship();
  }

  Future<void> _checkFriendship() async {
    final otherUserId = widget.conversation.participantIds.firstWhere(
      (id) => id != widget.currentUserId,
      orElse: () => '',
    );
    if (otherUserId.isEmpty) return;

    final exists = await widget.chatRepository.checkUserExists(otherUserId);
    if (!exists) {
      if (mounted) setState(() => _userExists = false);
      return;
    }

    final isFriend = await widget.chatRepository.areFriends(
      widget.currentUserId,
      otherUserId,
    );
    final friendDocId = isFriend
        ? await widget.chatRepository.getFriendDocId(
            widget.currentUserId,
            otherUserId,
          )
        : null;

    if (mounted) {
      setState(() {
        _isFriend = isFriend;
        _friendDocId = friendDocId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_userExists) return const SizedBox.shrink();
    if (!_isFriend) return const SizedBox.shrink();

    final otherUserId = widget.conversation.participantIds.firstWhere(
      (id) => id != widget.currentUserId,
      orElse: () => '',
    );
    final otherUsername =
        widget.conversation.participantUsernames[otherUserId] ?? 'this user';

    return CompactTile(
      icon: Icons.person_remove_outlined,
      iconColor: Colors.orange,
      label: 'Remove friend',
      onTap: () async {
        final cs = Theme.of(context).colorScheme;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Remove $otherUsername?'),
            content: const Text(
              'They will be removed from your friends list. '
              'Your chat history will remain.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: cs.error),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        );
        if (confirmed == true && _friendDocId != null) {
          await widget.chatRepository.removeFriend(_friendDocId!);
          if (context.mounted) setState(() => _isFriend = false);
        }
      },
    );
  }
}
