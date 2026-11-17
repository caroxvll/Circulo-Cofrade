import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../utils/published_media_ratio.dart';

/// Reproductor inline para publicaciones oficiales (MP4 en R2).
class EditorialVideoPlayer extends StatefulWidget {
  const EditorialVideoPlayer({
    super.key,
    required this.videoUrl,
    this.posterUrl,
    this.autoPlay = false,
    this.muted = false,
    this.pauseWhenOffscreen = false,
    this.showVideoLabel = false,
    this.openFullscreenOnTap = false,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
  });

  final String videoUrl;
  final String? posterUrl;
  final bool autoPlay;
  final bool muted;
  final bool pauseWhenOffscreen;
  final bool showVideoLabel;
  final bool openFullscreenOnTap;
  final BorderRadius borderRadius;

  @override
  State<EditorialVideoPlayer> createState() => _EditorialVideoPlayerState();
}

class _EditorialVideoPlayerState extends State<EditorialVideoPlayer> {
  late final VideoPlayerController _controller;
  var _ready = false;
  var _failed = false;
  var _showControls = true;
  var _muted = false;
  var _visible = false;
  var _userPaused = false;
  var _completed = false;
  var _wasPlaying = false;

  @override
  void initState() {
    super.initState();
    _muted = widget.muted;
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..setLooping(false)
      ..addListener(_onVideoChanged)
      ..initialize().then((_) {
        if (!mounted) return;
        _controller.setVolume(_muted ? 0 : 1);
        setState(() => _ready = true);
        _playAutomaticallyIfAllowed();
      }).catchError((_) {
        if (!mounted) return;
        setState(() => _failed = true);
      });
  }

  @override
  void dispose() {
    _controller.removeListener(_onVideoChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onVideoChanged() {
    if (!mounted || !_ready) return;
    final value = _controller.value;
    final duration = value.duration;
    final reachedEnd = duration > Duration.zero &&
        value.position >= duration - const Duration(milliseconds: 250) &&
        !value.isPlaying;
    if (value.isPlaying == _wasPlaying && reachedEnd == _completed) return;
    setState(() {
      _wasPlaying = value.isPlaying;
      if (reachedEnd) {
        _completed = true;
        _showControls = true;
      }
    });
  }

  void _playAutomaticallyIfAllowed() {
    if (!_ready ||
        !widget.autoPlay ||
        _userPaused ||
        _completed ||
        (widget.pauseWhenOffscreen && !_visible)) {
      return;
    }
    _controller.play();
    setState(() => _showControls = false);
  }

  Future<void> _toggle() async {
    if (!_ready) return;
    if (_controller.value.isPlaying) {
      await _controller.pause();
      if (!mounted) return;
      setState(() {
        _userPaused = true;
        _showControls = true;
      });
      return;
    }
    if (_completed) {
      await _controller.seekTo(Duration.zero);
    }
    await _controller.play();
    if (!mounted) return;
    setState(() {
        _completed = false;
        _userPaused = false;
        _showControls = false;
    });
  }

  Future<void> _handleVideoTap() async {
    if (!_ready) return;
    if (!widget.openFullscreenOnTap) {
      await _toggle();
      return;
    }

    await _controller.pause();
    if (!mounted) return;
    final position = await Navigator.of(context).push<Duration>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _EditorialFullscreenVideo(
          videoUrl: widget.videoUrl,
          initialPosition: _controller.value.position,
        ),
      ),
    );
    if (!mounted) return;
    if (position != null) {
      await _controller.seekTo(position);
      _completed = false;
    }
    _playAutomaticallyIfAllowed();
  }

  void _toggleMute() {
    if (!_ready) return;
    setState(() => _muted = !_muted);
    _controller.setVolume(_muted ? 0 : 1);
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final visible = info.visibleFraction >= 0.6;
    if (_visible == visible) return;
    _visible = visible;
    if (!_ready) return;
    if (!visible && _controller.value.isPlaying) {
      _controller.pause();
      return;
    }
    if (visible) _playAutomaticallyIfAllowed();
  }

  @override
  Widget build(BuildContext context) {
    final poster = widget.posterUrl?.trim();

    final player = ClipRRect(
      borderRadius: widget.borderRadius,
      child: ColoredBox(
        color: AppColors.backgroundElevated,
        child: AspectRatio(
          aspectRatio: clampPublishedAspectRatio(
            _ready ? _controller.value.aspectRatio : 16 / 9,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_ready)
                FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                )
              else if (poster != null && poster.isNotEmpty)
                CofradeoNetworkImage(
                  url: poster,
                  fit: BoxFit.contain,
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
                      onTap: _handleVideoTap,
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
                                _completed
                                    ? Icons.replay_rounded
                                    : _controller.value.isPlaying
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
              if (widget.showVideoLabel)
                Positioned(
                  left: 10,
                  top: 10,
                  child: _VideoBadge(playing: _ready && _controller.value.isPlaying),
                ),
              if (_ready)
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.52),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: _toggleMute,
                      customBorder: const CircleBorder(),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          _muted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          color: Colors.white,
                          size: 20,
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

    if (!widget.pauseWhenOffscreen) return player;
    return VisibilityDetector(
      key: ValueKey('editorial-video-${widget.videoUrl}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: player,
    );
  }
}

class _EditorialFullscreenVideo extends StatefulWidget {
  const _EditorialFullscreenVideo({
    required this.videoUrl,
    required this.initialPosition,
  });

  final String videoUrl;
  final Duration initialPosition;

  @override
  State<_EditorialFullscreenVideo> createState() =>
      _EditorialFullscreenVideoState();
}

class _EditorialFullscreenVideoState
    extends State<_EditorialFullscreenVideo> {
  late final VideoPlayerController _controller;
  var _ready = false;
  var _failed = false;
  var _showControls = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..setLooping(false)
      ..addListener(_onVideoChanged)
      ..initialize().then((_) async {
        final duration = _controller.value.duration;
        final startsAtEnd = duration > Duration.zero &&
            widget.initialPosition >=
                duration - const Duration(milliseconds: 250);
        await _controller.seekTo(
          startsAtEnd ? Duration.zero : widget.initialPosition,
        );
        await _controller.setVolume(1);
        await _controller.play();
        if (!mounted) return;
        setState(() => _ready = true);
      }).catchError((_) {
        if (!mounted) return;
        setState(() => _failed = true);
      });
  }

  @override
  void dispose() {
    _controller.removeListener(_onVideoChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onVideoChanged() {
    if (!mounted || !_ready) return;
    final value = _controller.value;
    if (value.duration > Duration.zero &&
        value.position >=
            value.duration - const Duration(milliseconds: 250) &&
        !value.isPlaying &&
        !_showControls) {
      setState(() => _showControls = true);
    }
  }

  Future<void> _togglePlayback() async {
    if (!_ready) return;
    if (_controller.value.isPlaying) {
      await _controller.pause();
    } else {
      final value = _controller.value;
      if (value.duration > Duration.zero &&
          value.position >=
              value.duration - const Duration(milliseconds: 250)) {
        await _controller.seekTo(Duration.zero);
      }
      await _controller.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _skip(Duration delta) async {
    if (!_ready) return;
    final value = _controller.value;
    final target = value.position + delta;
    final clamped = target < Duration.zero
        ? Duration.zero
        : target > value.duration
            ? value.duration
            : target;
    await _controller.seekTo(clamped);
    if (mounted) setState(() {});
  }

  void _close() {
    Navigator.of(context).pop(_controller.value.position);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_ready)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio > 0
                      ? _controller.value.aspectRatio
                      : 16 / 9,
                  child: VideoPlayer(_controller),
                ),
              )
            else if (_failed)
              const Center(
                child: Text(
                  'No se pudo reproducir el vídeo',
                  style: TextStyle(color: Colors.white70),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            if (_ready)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () =>
                      setState(() => _showControls = !_showControls),
                ),
              ),
            if (_showControls)
              Positioned(
                left: 12,
                top: 8,
                child: IconButton.filledTonal(
                  onPressed: _close,
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            if (_ready && _showControls)
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _skip(const Duration(seconds: -10)),
                      icon: const Icon(Icons.replay_10_rounded),
                      color: Colors.white,
                      iconSize: 36,
                    ),
                    const SizedBox(width: 22),
                    IconButton.filled(
                      onPressed: _togglePlayback,
                      icon: Icon(
                        _controller.value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                      ),
                      iconSize: 38,
                    ),
                    const SizedBox(width: 22),
                    IconButton(
                      onPressed: () => _skip(const Duration(seconds: 10)),
                      icon: const Icon(Icons.forward_10_rounded),
                      color: Colors.white,
                      iconSize: 36,
                    ),
                  ],
                ),
              ),
            if (_ready && _showControls)
              Positioned(
                left: 20,
                right: 20,
                bottom: 18,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.52),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                    child: ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: _controller,
                      builder: (context, value, _) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            VideoProgressIndicator(
                              _controller,
                              allowScrubbing: true,
                              colors: const VideoProgressColors(
                                playedColor: AppColors.burgundy,
                                bufferedColor: Colors.white38,
                                backgroundColor: Colors.white24,
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatVideoDuration(value.position),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  _formatVideoDuration(value.duration),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
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

String _formatVideoDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

class _VideoBadge extends StatelessWidget {
  const _VideoBadge({required this.playing});

  final bool playing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              playing ? Icons.play_arrow_rounded : Icons.videocam_rounded,
              color: Colors.white,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              playing ? 'REPRODUCIENDO' : 'VÍDEO',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
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
