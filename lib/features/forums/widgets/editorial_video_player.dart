import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../utils/published_media_ratio.dart';

/// Reproductor inline para publicaciones oficiales (MP4 en R2).
///
/// En el feed conviene usar [EditorialVideoPoster] (sin inicializar el MP4).
/// Aquí el vídeo se carga una sola vez; la pantalla completa reutiliza el
/// mismo [VideoPlayerController] para no parar y volver a bufferizar.
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
  late VideoPlayerController _controller;
  var _alive = true;
  var _ready = false;
  var _failed = false;
  var _showControls = true;
  var _muted = false;
  // Con autoplay asumimos visible hasta que VisibilityDetector diga lo contrario.
  late var _visible = widget.autoPlay || !widget.pauseWhenOffscreen;
  var _userPaused = false;
  var _completed = false;
  var _wasPlaying = false;
  var _inFullscreen = false;

  @override
  void initState() {
    super.initState();
    _muted = widget.muted;
    _controller = _createController();
    unawaited(_initializePlayer());
  }

  VideoPlayerController _createController() {
    final url = widget.videoUrl.trim();
    final hls = url.contains('.m3u8') ||
        url.contains('videodelivery.net') ||
        url.contains('cloudflarestream.com');
    return VideoPlayerController.networkUrl(
      Uri.parse(url),
      formatHint: hls ? VideoFormat.hls : null,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )
      ..setLooping(false)
      ..addListener(_onVideoChanged);
  }

  Future<void> _recycleController() async {
    if (!_alive) return;
    final old = _controller;
    old.removeListener(_onVideoChanged);
    _controller = _createController();
    await old.dispose();
  }

  Future<void> _initializePlayer({bool retry = true}) async {
    if (!_alive) return;
    try {
      await _controller.initialize();
      if (!_alive) return;
      await _controller.setVolume(_muted ? 0 : 1);
      if (!_alive) return;
      setState(() {
        _ready = true;
        _failed = false;
      });
      await _playAutomaticallyIfAllowed();
    } catch (error) {
      debugPrint('Editorial video failed: $error ${widget.videoUrl}');
      if (retry && _alive) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (!_alive) return;
        await _recycleController();
        if (!_alive) return;
        await _initializePlayer(retry: false);
        return;
      }
      if (!_alive) return;
      setState(() => _failed = true);
    }
  }

  Future<void> _retryPlayback() async {
    if (!_alive) return;
    setState(() => _failed = false);
    await _recycleController();
    if (!_alive) return;
    await _initializePlayer();
  }

  @override
  void dispose() {
    _alive = false;
    _controller.removeListener(_onVideoChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onVideoChanged() {
    if (!mounted || !_ready || _inFullscreen) return;
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

  Future<void> _playAutomaticallyIfAllowed() async {
    if (!_ready ||
        _inFullscreen ||
        !widget.autoPlay ||
        _userPaused ||
        _completed ||
        (widget.pauseWhenOffscreen && !_visible)) {
      return;
    }
    try {
      await _controller.play();
    } catch (_) {
      // p.ej. política de autoplay del navegador
    }
    if (!mounted) return;

    // Si el navegador bloqueó autoplay con sonido, reintentar muteado.
    if (!_controller.value.isPlaying && !_muted) {
      _muted = true;
      await _controller.setVolume(0);
      try {
        await _controller.play();
      } catch (_) {}
      if (!mounted) return;
    }

    if (_controller.value.isPlaying) {
      setState(() => _showControls = false);
    } else {
      setState(() => _showControls = true);
    }
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

    final wasPlaying = _controller.value.isPlaying;
    // Solo un VideoPlayer por controller: quitar el inline antes del fullscreen.
    setState(() => _inFullscreen = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    await Navigator.of(context).push<void>(
      PageRouteBuilder(
        opaque: true,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: _EditorialFullscreenVideo(
              controller: _controller,
              muted: _muted,
              onMuteChanged: (muted) {
                _muted = muted;
                _controller.setVolume(muted ? 0 : 1);
              },
            ),
          );
        },
      ),
    );

    if (!mounted) return;
    setState(() {
      _inFullscreen = false;
      _wasPlaying = _controller.value.isPlaying;
      final duration = _controller.value.duration;
      _completed = duration > Duration.zero &&
          _controller.value.position >=
              duration - const Duration(milliseconds: 250) &&
          !_controller.value.isPlaying;
      _showControls = !_controller.value.isPlaying;
    });

    // Continuar desde donde quedó, sin reinicializar.
    if (wasPlaying && !_userPaused && !_completed) {
      await _controller.play();
      if (mounted) setState(() => _showControls = false);
    }
  }

  void _toggleMute() {
    if (!_ready) return;
    setState(() => _muted = !_muted);
    _controller.setVolume(_muted ? 0 : 1);
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (_inFullscreen) return;
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
              // Poster siempre debajo: se ve al instante mientras carga el MP4.
              if (poster != null && poster.isNotEmpty)
                CofradeoNetworkImage(
                  url: poster,
                  fit: BoxFit.cover,
                  cacheSize: 720,
                )
              else
                const ColoredBox(color: AppColors.backgroundElevated),
              if (_ready && !_inFullscreen)
                FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              if (_failed)
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      onTap: () => unawaited(_retryPlayback()),
                      borderRadius: BorderRadius.circular(999),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.replay_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Vídeo',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
              else if (!_inFullscreen)
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
                                widget.openFullscreenOnTap &&
                                        _controller.value.isPlaying
                                    ? Icons.fullscreen_rounded
                                    : _completed
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
                  child: _VideoBadge(
                    playing: _ready &&
                        !_inFullscreen &&
                        _controller.value.isPlaying,
                  ),
                ),
              if (_ready && !_inFullscreen)
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
    required this.controller,
    required this.muted,
    required this.onMuteChanged,
  });

  final VideoPlayerController controller;
  final bool muted;
  final ValueChanged<bool> onMuteChanged;

  @override
  State<_EditorialFullscreenVideo> createState() =>
      _EditorialFullscreenVideoState();
}

class _EditorialFullscreenVideoState extends State<_EditorialFullscreenVideo> {
  var _showControls = true;
  late var _muted = widget.muted;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onVideoChanged);
    // Misma instancia: sigue desde la posición actual sin rebufferizar.
    if (!widget.controller.value.isPlaying) {
      final value = widget.controller.value;
      final atEnd = value.duration > Duration.zero &&
          value.position >=
              value.duration - const Duration(milliseconds: 250);
      () async {
        if (atEnd) await widget.controller.seekTo(Duration.zero);
        await widget.controller.play();
        if (mounted) setState(() {});
      }();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onVideoChanged);
    super.dispose();
  }

  void _onVideoChanged() {
    if (!mounted) return;
    final value = widget.controller.value;
    if (value.duration > Duration.zero &&
        value.position >=
            value.duration - const Duration(milliseconds: 250) &&
        !value.isPlaying &&
        !_showControls) {
      setState(() => _showControls = true);
    } else {
      setState(() {});
    }
  }

  Future<void> _togglePlayback() async {
    final controller = widget.controller;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      final value = controller.value;
      if (value.duration > Duration.zero &&
          value.position >=
              value.duration - const Duration(milliseconds: 250)) {
        await controller.seekTo(Duration.zero);
      }
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _skip(Duration delta) async {
    final value = widget.controller.value;
    final target = value.position + delta;
    final clamped = target < Duration.zero
        ? Duration.zero
        : target > value.duration
            ? value.duration
            : target;
    await widget.controller.seekTo(clamped);
    if (mounted) setState(() {});
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    widget.controller.setVolume(_muted ? 0 : 1);
    widget.onMuteChanged(_muted);
  }

  void _close() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final ready = controller.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (ready)
              Center(
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio > 0
                      ? controller.value.aspectRatio
                      : 16 / 9,
                  child: VideoPlayer(controller),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            if (ready)
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
            if (_showControls)
              Positioned(
                right: 12,
                top: 8,
                child: IconButton.filledTonal(
                  onPressed: _toggleMute,
                  icon: Icon(
                    _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            if (ready && _showControls)
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
                        controller.value.isPlaying
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
            if (ready && _showControls)
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
                      valueListenable: controller,
                      builder: (context, value, _) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            VideoProgressIndicator(
                              controller,
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
  const _VideoBadge({required this.playing, this.label});

  final bool playing;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final text = label ?? (playing ? 'REPRODUCIENDO' : 'VÍDEO');
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
              label != null
                  ? Icons.hourglass_top_rounded
                  : playing
                      ? Icons.play_arrow_rounded
                      : Icons.videocam_rounded,
              color: Colors.white,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              text,
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

/// Poster con badge de play para cards del feed (sin autoplay / sin MP4).
class EditorialVideoPoster extends StatelessWidget {
  const EditorialVideoPoster({
    super.key,
    this.posterUrl,
    this.processing = false,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
  });

  final String? posterUrl;
  final bool processing;
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
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    processing
                        ? Icons.hourglass_top_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              top: 10,
              child: _VideoBadge(
                playing: false,
                label: processing ? 'OPTIMIZANDO' : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
