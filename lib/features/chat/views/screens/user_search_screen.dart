import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_education_app/features/chat/models/chat_message_model.dart';
import 'package:flutter_education_app/features/chat/models/conversation_model.dart';
import 'package:flutter_education_app/features/chat/models/friend_request_model.dart';
import 'package:flutter_education_app/features/chat/repositories/chat_repository.dart';
import 'chat_screen.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({
    super.key,
    required this.currentUserId,
    required this.currentUsername,
    required this.currentProfilePhoto,
    required this.chatRepository,
    this.groupConversationId,
    this.existingMemberIds = const [],
  });

  final String currentUserId;
  final String currentUsername;
  final String currentProfilePhoto;
  final ChatRepository chatRepository;
  final String? groupConversationId;
  final List<String> existingMemberIds;

  bool get isGroupAddMode => groupConversationId != null;

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final results = await widget.chatRepository.searchUsersByUsername(query);
      setState(() {
        _results = results.where((r) {
          final id = r['user_id'] as String? ?? r['id'] as String? ?? '';
          if (id == widget.currentUserId) return false;
          if (widget.isGroupAddMode && widget.existingMemberIds.contains(id)) {
            return false;
          }
          return true;
        }).toList();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleUserTap(Map<String, dynamic> user) async {
    if (widget.isGroupAddMode) {
      await _addToGroup(user);
    } else {
      await _openOrCreateDM(user);
    }
  }

  Future<void> _addToGroup(Map<String, dynamic> user) async {
    final id = user['user_id'] as String? ?? user['id'] as String? ?? '';
    final username = user['username'] as String? ?? '';

    await widget.chatRepository.addMembersToGroup(
      conversationId: widget.groupConversationId!,
      newMembers: {id: username},
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$username added to group'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _openOrCreateDM(Map<String, dynamic> user) async {
    final otherUserId =
        user['user_id'] as String? ?? user['id'] as String? ?? '';
    final otherUsername = user['username'] as String? ?? '';

    ConversationModel? conversation = await widget.chatRepository
        .getIndividualConversation(widget.currentUserId, otherUserId);

    conversation ??= await widget.chatRepository.createIndividualConversation(
      currentUserId: widget.currentUserId,
      currentUsername: widget.currentUsername,
      otherUserId: otherUserId,
      otherUsername: otherUsername,
    );

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversation: conversation!,
          currentUserId: widget.currentUserId,
          currentUsername: widget.currentUsername,
          currentProfilePhoto: widget.currentProfilePhoto,
          chatRepository: widget.chatRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(28),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    autofocus: true,
                    style: textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: widget.isGroupAddMode
                          ? 'Search users to add…'
                          : 'Search by username…',
                      hintStyle: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                      isDense: true,
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _results = []);
                    },
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(colorScheme, textTheme),
    );
  }

  Widget _buildBody(ColorScheme colorScheme, TextTheme textTheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (_searchController.text.isEmpty) {
      return _EmptyState(
        icon: Icons.person_search_rounded,
        title: 'Find people',
        subtitle: widget.isGroupAddMode
            ? 'Search for someone to add to the group'
            : 'Search for someone by their exact username',
        colorScheme: colorScheme,
        textTheme: textTheme,
      );
    }

    if (_results.isEmpty) {
      return _EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No results',
        subtitle: 'No user found with username "${_searchController.text}"',
        colorScheme: colorScheme,
        textTheme: textTheme,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 32),
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final user = _results[i];
        return _UserResultTile(
          user: user,
          currentUserId: widget.currentUserId,
          currentUsername: widget.currentUsername,
          currentProfilePhoto: widget.currentProfilePhoto,
          chatRepository: widget.chatRepository,
          isGroupAddMode: widget.isGroupAddMode,
          onTap: () => _handleUserTap(user),
        );
      },
    );
  }
}

class _UserResultTile extends StatefulWidget {
  const _UserResultTile({
    required this.user,
    required this.currentUserId,
    required this.currentUsername,
    required this.currentProfilePhoto,
    required this.chatRepository,
    required this.isGroupAddMode,
    required this.onTap,
  });

  final Map<String, dynamic> user;
  final String currentUserId;
  final String currentUsername;
  final String currentProfilePhoto;
  final ChatRepository chatRepository;
  final bool isGroupAddMode;
  final VoidCallback onTap;

  @override
  State<_UserResultTile> createState() => _UserResultTileState();
}

class _UserResultTileState extends State<_UserResultTile> {
  _FriendStatus _status = _FriendStatus.none;
  bool _loading = true;

  String get _otherUserId =>
      widget.user['user_id'] as String? ?? widget.user['id'] as String? ?? '';

  @override
  void initState() {
    super.initState();
    _checkFriendStatus();
  }

  Future<void> _checkFriendStatus() async {
    final results = await Future.wait([
      widget.chatRepository.areFriends(widget.currentUserId, _otherUserId),
      widget.chatRepository.getRequestBetween(
        widget.currentUserId,
        _otherUserId,
      ),
    ]);

    final isFriend = results[0] as bool;
    final request = results[1] as FriendRequestModel?;

    if (!mounted) return;

    _FriendStatus status;
    if (isFriend) {
      status = _FriendStatus.friends;
    } else if (request != null &&
        request.status == FriendRequestStatus.pending) {
      if (request.fromUserId == widget.currentUserId) {
        status = _FriendStatus.requestSent;
      } else {
        status = _FriendStatus.requestReceived;
      }
    } else {
      status = _FriendStatus.none;
    }

    setState(() {
      _status = status;
      _loading = false;
    });
  }

  Future<void> _sendRequest() async {
    final username = widget.user['username'] as String? ?? '';
    try {
      await widget.chatRepository.sendFriendRequest(
        fromUserId: widget.currentUserId,
        fromUsername: widget.currentUsername,
        fromProfilePhoto: widget.currentProfilePhoto,
        toUserId: _otherUserId,
        toUsername: username,
      );
      if (mounted) setState(() => _status = _FriendStatus.requestSent);
    } on DuplicateFriendRequestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      await _checkFriendStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final username = widget.user['username'] as String? ?? 'Unknown';
    final fullName = widget.user['full_name'] as String? ?? '';
    final photoUrl = widget.user['profile_photo'] as String? ?? '';

    return InkWell(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: colorScheme.surfaceContainerHighest,
              backgroundImage: photoUrl.isNotEmpty
                  ? NetworkImage(photoUrl)
                  : null,
              child: photoUrl.isEmpty
                  ? Text(
                      username.isNotEmpty ? username[0].toUpperCase() : '?',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                  if (fullName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (widget.isGroupAddMode)
              Icon(
                Icons.add_circle_outline,
                color: colorScheme.primary,
                size: 24,
              )
            else if (_loading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator.adaptive(strokeWidth: 2),
              )
            else
              _buildTrailingAction(colorScheme, textTheme),
          ],
        ),
      ),
    );
  }

  Widget _buildTrailingAction(ColorScheme colorScheme, TextTheme textTheme) {
    switch (_status) {
      case _FriendStatus.friends:
        return _StatusChip(
          label: 'Friends',
          colorScheme: colorScheme,
          textTheme: textTheme,
          isMuted: false,
        );
      case _FriendStatus.requestSent:
        return _StatusChip(
          label: 'Requested',
          colorScheme: colorScheme,
          textTheme: textTheme,
          isMuted: true,
        );
      case _FriendStatus.requestReceived:
        return _StatusChip(
          label: 'Respond',
          colorScheme: colorScheme,
          textTheme: textTheme,
          isMuted: false,
        );
      case _FriendStatus.none:
        return FilledButton(
          onPressed: _sendRequest,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Add'),
        );
    }
  }
}

enum _FriendStatus { none, requestSent, requestReceived, friends }

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.colorScheme,
    required this.textTheme,
    required this.isMuted,
  });

  final String label;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final bool isMuted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isMuted
            ? colorScheme.surfaceContainerHighest
            : colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: isMuted
              ? colorScheme.onSurface.withValues(alpha: 0.4)
              : colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colorScheme,
    required this.textTheme,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.4),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
