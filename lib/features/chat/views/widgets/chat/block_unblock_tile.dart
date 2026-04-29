// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/core/routers/app_navigator.dart';
import 'package:edumap_portfolio_project/features/app/views/screens/home_screen.dart';
import 'package:edumap_portfolio_project/features/chat/models/conversation_model.dart';
import 'package:edumap_portfolio_project/features/chat/repositories/chat_repository.dart';
import 'package:edumap_portfolio_project/features/chat/views/widgets/chat/compact_tile.dart';

class BlockUnblockTile extends StatefulWidget {
  const BlockUnblockTile({
    super.key,
    required this.currentUserId,
    required this.conversation,
    required this.chatRepository,
  });

  final String currentUserId;
  final ConversationModel conversation;
  final ChatRepository chatRepository;

  @override
  State<BlockUnblockTile> createState() => BlockUnblockTileState();
}

class BlockUnblockTileState extends State<BlockUnblockTile> {
  bool _isBlocked = false;
  String? _blockedRequestId;
  bool _loading = true;
  bool _userExists = true;

  String get _otherUserId => widget.conversation.participantIds.firstWhere(
    (id) => id != widget.currentUserId,
    orElse: () => '',
  );

  String get _otherUsername =>
      widget.conversation.participantUsernames[_otherUserId] ?? 'this user';

  @override
  void initState() {
    super.initState();
    _loadBlockState();
  }

  Future<void> _loadBlockState() async {
    if (_otherUserId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final exists = await widget.chatRepository.checkUserExists(_otherUserId);
    if (!exists) {
      if (mounted) {
        setState(() {
          _userExists = false;
          _loading = false;
        });
      }
      return;
    }

    final blocked = await widget.chatRepository.getBlockedRequest(
      widget.currentUserId,
      _otherUserId,
    );
    if (mounted) {
      setState(() {
        _isBlocked = blocked != null;
        _blockedRequestId = blocked?.id;
        _loading = false;
      });
    }
  }

  Future<void> _block(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Block $_otherUsername?'),
        content: Text(
          '$_otherUsername will no longer be able to message you and will be removed from your friends.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: cs.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await widget.chatRepository.blockUser(
      blockerId: widget.currentUserId,
      blockedId: _otherUserId,
    );
    await widget.chatRepository.deleteConversation(widget.conversation.id!);

    if (!mounted) return;
    AppNavigator(screen: HomeScreen()).navigate(context);
  }

  Future<void> _unblock(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Unblock $_otherUsername?'),
        content: Text(
          '$_otherUsername will be able to send you friend requests and messages again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: cs.primary),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (_blockedRequestId != null) {
      await widget.chatRepository.unblockUser(_blockedRequestId!);
    }

    if (mounted) {
      setState(() {
        _isBlocked = false;
        _blockedRequestId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_otherUsername has been unblocked.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!_userExists) return const SizedBox.shrink();

    if (_loading) {
      return const ListTile(
        dense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
        leading: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator.adaptive(strokeWidth: 2),
        ),
        title: Text(''),
      );
    }

    if (_isBlocked) {
      return CompactTile(
        icon: Icons.block_rounded,
        iconColor: cs.primary,
        label: 'Unblock user',
        onTap: () => _unblock(context),
      );
    }

    return CompactTile(
      icon: Icons.block_rounded,
      iconColor: Colors.orange,
      label: 'Block user',
      onTap: () => _block(context),
    );
  }
}
