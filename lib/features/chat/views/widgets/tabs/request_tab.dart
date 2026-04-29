import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/chat/models/chat_message_model.dart';
import 'package:edumap_portfolio_project/features/chat/models/friend_request_model.dart';
import 'package:edumap_portfolio_project/features/chat/repositories/chat_repository.dart';
import 'package:edumap_portfolio_project/features/chat/views/widgets/shared/avatar.dart';
import 'package:edumap_portfolio_project/features/chat/views/widgets/shared/empty_state.dart';
import 'package:timeago/timeago.dart' as timeago;

class RequestsTab extends StatelessWidget {
  const RequestsTab({
    super.key,
    required this.currentUserId,
    required this.chatRepository,
  });

  final String currentUserId;
  final ChatRepository chatRepository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FriendRequestModel>>(
      stream: chatRepository.watchIncomingRequests(currentUserId),
      builder: (context, snap) {
        // Show loader while waiting OR while stream is active but data hasn't
        // arrived yet (Firestore cold-start gives active + null before first emit)
        if (snap.connectionState == ConnectionState.waiting ||
            (snap.connectionState == ConnectionState.active &&
                !snap.hasData &&
                snap.error == null)) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        if (snap.hasError) {
          debugPrint('[RequestsTab] stream error: ${snap.error}');
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Could not load requests. Please check your connection.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final requests = snap.data ?? [];

        if (requests.isEmpty) {
          return const EmptyState(
            icon: Icons.person_add_alt_1_outlined,
            title: 'No pending requests',
            subtitle: 'Requests from others will appear here',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 4, bottom: 96),
          itemCount: requests.length,
          itemBuilder: (context, i) {
            return _RequestTile(
              request: requests[i],
              chatRepository: chatRepository,
            );
          },
        );
      },
    );
  }
}

class _RequestTile extends StatefulWidget {
  const _RequestTile({required this.request, required this.chatRepository});

  final FriendRequestModel request;
  final ChatRepository chatRepository;

  @override
  State<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends State<_RequestTile> {
  bool _responding = false;

  Future<void> _respond(FriendRequestStatus status) async {
    final requestId = widget.request.id;
    if (_responding || requestId == null) return;
    setState(() => _responding = true);
    try {
      await widget.chatRepository.respondToFriendRequest(requestId, status);
    } catch (e) {
      debugPrint('[RequestsTab] respond error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _responding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Avatar(
            displayName: widget.request.fromUsername,
            photoUrl: widget.request.fromProfilePhoto.isNotEmpty
                ? widget.request.fromProfilePhoto
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.request.fromFullName.isNotEmpty
                      ? widget.request.fromFullName
                      : widget.request.fromUsername,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
                if (widget.request.fromFullName.isNotEmpty)
                  Text(
                    '@${widget.request.fromUsername}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  timeago.format(widget.request.sentAt),
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (_responding)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton(
                  onPressed: () => _respond(FriendRequestStatus.accepted),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Accept'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _respond(FriendRequestStatus.rejected),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Decline'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
