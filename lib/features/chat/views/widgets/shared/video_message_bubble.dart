import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/chat/models/chat_message_model.dart';
import 'package:edumap_portfolio_project/features/chat/views/widgets/shared/full_screen_video_player.dart';
import 'package:video_player/video_player.dart';

class VideoMessageBubble extends StatefulWidget {
  const VideoMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  final ChatMessageModel message;
  final bool isMe;

  @override
  State<VideoMessageBubble> createState() => _VideoMessageBubbleState();
}

class _VideoMessageBubbleState extends State<VideoMessageBubble> {
  VideoPlayerController? _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    if (widget.message.mediaUrl == null) return;
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.message.mediaUrl!),
    );
    await _controller!.initialize();
    if (mounted) setState(() => _initialized = true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _openPlayer(BuildContext context) {
    if (widget.message.mediaUrl == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullscreenVideoPlayer(url: widget.message.mediaUrl!),
        fullscreenDialog: true,
      ),
    );
  }

  String _fmtDuration(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _openPlayer(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.message.mediaThumbnailUrl != null)
              Image.network(
                widget.message.mediaThumbnailUrl!,
                width: 180,
                height: 130,
                fit: BoxFit.cover,
              )
            else if (_initialized && _controller != null)
              SizedBox(
                width: 180,
                height: 130,
                child: VideoPlayer(_controller!),
              )
            else
              Container(
                width: 180,
                height: 130,
                color: cs.surfaceContainerHighest,
                child: Icon(
                  Icons.play_circle_outline,
                  color: cs.onSurfaceVariant,
                  size: 36,
                ),
              ),
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            if (widget.message.mediaDurationSeconds != null)
              Positioned(
                bottom: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _fmtDuration(widget.message.mediaDurationSeconds!),
                    style: const TextStyle(color: Colors.white, fontSize: 9),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
