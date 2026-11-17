import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cofradeo_network_image.dart';

/// Reproductor inline para publicaciones oficiales (MP4 en R2).
class EditorialVideoPlayer extends StatefulWidget {
  const EditorialVideoPlayer({
    super.key,
    required this.videoUrl,
    this.posterUrl,
    this.autoPlay = false,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
  });

  final String videoUrl;
  final String? posterUrl;
  final bool autoPlay;
  final BorderRadius borderRadius;

  @override
  State<EditorialVideoPlayer> createState() => _EditorialVideoPlayerState();
}

class _EditorialVideoPlayerState extends State<EditorialVideoPlayer> {
  late final VideoPlayerController _controller;
  var _ready = false;
  var _failed = false;
  var _showControls = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..setLooping(true)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        if (widget.autoPlay) {
          _controller.play();
          _showControls = false;
        }
      }).catchError((_) {
        if (!mounted) return;
        setState(() => _failed = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!_ready) return;
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _showControls = true;
      } else {
        _controller.play();
        _showControls = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final poster = widget.posterUrl?.trim();

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: ColoredBox(
        color: AppColors.backgroundElevated,
        child: AspectRatio(
          aspectRatio: _ready && _controller.value.aspectRatio > 0
              ? _controller.value.aspectRatio
              : 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_ready)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                )
              else if (poster != null && poster.isNotEmpty)
                CofradeoNetworkImage(
                  url: poster,
                  fit: BoxFit.cover,
                  cacheSize: 720,
                )
              else
                const ColoredBox(color: AppColors.backgroundElevated),
              if (_failed)
                const Center(
                  child: Icon(
                    Icons.error_outline,
                    color: AppColors.textMuted,
                  ),
                )
              else if (!_ready)
                const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _toggle,
                      child: AnimatedOpacity(
                        opacity: _showControls || !_controller.value.isPlaying
                            ? 1
                            : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Icon(
                                _controller.value.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Poster con badge de play para cards del feed (sin autoplay).
class EditorialVideoPoster extends StatelessWidget {
  const EditorialVideoPoster({
    super.key,
    this.posterUrl,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
  });

  final String? posterUrl;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final poster = posterUrl?.trim();
    return ClipRRect(
      borderRadius: borderRadius,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (poster != null && poster.isNotEmpty)
              CofradeoNetworkImage(
                url: poster,
                fit: BoxFit.cover,
                cacheSize: 360,
              )
            else
              const ColoredBox(color: AppColors.backgroundElevated),
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
