import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class FullscreenVideoPlayer extends StatefulWidget {
  const FullscreenVideoPlayer({super.key, required this.url});
  final String url;

  @override
  State<FullscreenVideoPlayer> createState() => FullscreenVideoPlayerState();
}

class FullscreenVideoPlayerState extends State<FullscreenVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller.initialize().then((_) {
      if (mounted) {
        _controller.setLooping(false);
        setState(() => _initialized = true);
        _controller.play();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: _initialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_controller),
                    GestureDetector(
                      onTap: () {
                        // ✅ controller called outside setState
                        _controller.value.isPlaying
                            ? _controller.pause()
                            : _controller.play();
                        setState(() {});
                      },
                      child: Container(
                        color: Colors.transparent,
                        child: _controller.value.isPlaying
                            ? null
                            : const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 52,
                              ),
                      ),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
      bottomNavigationBar: _initialized
          ? VideoProgressIndicator(
              _controller,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Colors.white,
                backgroundColor: Colors.white24,
              ),
            )
          : null,
    );
  }
}
