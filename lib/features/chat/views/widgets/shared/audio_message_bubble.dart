import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/chat/models/chat_message_model.dart';
import 'package:just_audio/just_audio.dart';

class AudioMessageBubble extends StatefulWidget {
  const AudioMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  final ChatMessageModel message;
  final bool isMe;

  @override
  State<AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends State<AudioMessageBubble> {
  final _player = AudioPlayer();
  bool _isPlaying = false;
  double _progress = 0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    if (widget.message.mediaUrl == null) return;
    try {
      await _player.setUrl(widget.message.mediaUrl!);
      _duration = _player.duration ?? Duration.zero;

      _player.positionStream.listen((pos) {
        if (!mounted) return;
        setState(() {
          _position = pos;
          _progress = _duration.inMilliseconds > 0
              ? pos.inMilliseconds / _duration.inMilliseconds
              : 0;
        });
      });

      _player.playerStateStream.listen((state) {
        if (!mounted) return;
        setState(() => _isPlaying = state.playing);
        if (state.processingState == ProcessingState.completed) {
          setState(() {
            _progress = 0;
            _position = Duration.zero;
            _isPlaying = false;
          });
          _player.seek(Duration.zero);
          _player.pause();
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async =>
      _isPlaying ? await _player.pause() : await _player.play();

  String _fmt(Duration d) =>
      '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SizedBox(
      width: 200,
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: widget.isMe
                    ? cs.onPrimary.withValues(alpha: 0.15)
                    : cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: widget.isMe ? cs.onPrimary : cs.onPrimaryContainer,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 4,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 8,
                    ),
                    activeTrackColor: widget.isMe ? cs.onPrimary : cs.primary,
                    inactiveTrackColor:
                        (widget.isMe ? cs.onPrimary : cs.primary).withValues(
                          alpha: 0.25,
                        ),
                    thumbColor: widget.isMe ? cs.onPrimary : cs.primary,
                    overlayColor: (widget.isMe ? cs.onPrimary : cs.primary)
                        .withValues(alpha: 0.15),
                  ),
                  child: Slider(
                    value: _progress.clamp(0.0, 1.0),
                    onChanged: (v) => _player.seek(
                      Duration(
                        milliseconds: (v * _duration.inMilliseconds).round(),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _fmt(_position),
                        style: tt.labelSmall?.copyWith(
                          fontSize: 9,
                          color: (widget.isMe ? cs.onPrimary : cs.onSurface)
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      Text(
                        _fmt(_duration),
                        style: tt.labelSmall?.copyWith(
                          fontSize: 9,
                          color: (widget.isMe ? cs.onPrimary : cs.onSurface)
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
