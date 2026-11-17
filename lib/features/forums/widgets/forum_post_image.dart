import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../../../core/widgets/cofradeo_skeleton.dart';
import '../utils/published_media_ratio.dart';
import 'forum_post_image_viewer.dart';

/// Cartel o foto adjunta a una publicación oficial (vista previa en el hilo).
class ForumPostImage extends StatelessWidget {
  const ForumPostImage({
    super.key,
    required this.imageUrl,
    this.shareText,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.maxPreviewHeight = 420,
    this.showExpandHint = true,
    this.fit = BoxFit.contain,
    this.adaptiveOrientation = false,
  });

  final String imageUrl;
  final String? shareText;
  final BorderRadius borderRadius;
  final double maxPreviewHeight;
  final bool showExpandHint;
  final BoxFit fit;

  /// Muestra fotos verticales en vertical y horizontales en horizontal.
  final bool adaptiveOrientation;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    if (url.isEmpty) return const SizedBox.shrink();
    if (adaptiveOrientation) {
      return _AdaptiveForumPostImage(
        imageUrl: url,
        shareText: shareText,
        borderRadius: borderRadius,
        maxPreviewHeight: maxPreviewHeight,
        showExpandHint: showExpandHint,
      );
    }

    final width = MediaQuery.sizeOf(context).width;

    return Material(
      color: AppColors.backgroundElevated.withValues(alpha: 0.35),
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showForumPostImageViewer(
          context,
          imageUrl: url,
          shareText: shareText,
        ),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            SizedBox(
              width: double.infinity,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxPreviewHeight),
                child: CofradeoNetworkImage(
                  url: url,
                  fit: fit,
                  width: double.infinity,
                  cacheSize: width.clamp(320.0, 1080.0),
                  placeholder: const SizedBox(
                    height: 180,
                    child: CofradeoSkeletonBone(
                      height: 180,
                      borderRadius: 0,
                    ),
                  ),
                  errorWidget: _placeholder(),
                ),
              ),
            ),
            if (showExpandHint)
              Padding(
                padding: const EdgeInsets.all(8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.zoom_out_map,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Ver completa',
                          style: AppTypography.labelSmall(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder({Widget? child}) {
    return Container(
      height: 180,
      color: AppColors.backgroundElevated,
      alignment: Alignment.center,
      child: child ??
          Icon(
            Icons.image_not_supported_outlined,
            color: AppColors.textMuted.withValues(alpha: 0.7),
            size: 32,
          ),
    );
  }
}

class _AdaptiveForumPostImage extends StatefulWidget {
  const _AdaptiveForumPostImage({
    required this.imageUrl,
    required this.shareText,
    required this.borderRadius,
    required this.maxPreviewHeight,
    required this.showExpandHint,
  });

  final String imageUrl;
  final String? shareText;
  final BorderRadius borderRadius;
  final double maxPreviewHeight;
  final bool showExpandHint;

  @override
  State<_AdaptiveForumPostImage> createState() => _AdaptiveForumPostImageState();
}

class _AdaptiveForumPostImageState extends State<_AdaptiveForumPostImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  double _aspect = 16 / 9;

  @override
  void initState() {
    super.initState();
    _resolve(widget.imageUrl);
  }

  @override
  void didUpdateWidget(covariant _AdaptiveForumPostImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) _resolve(widget.imageUrl);
  }

  void _resolve(String url) {
    _stop();
    final stream = CachedNetworkImageProvider(url).resolve(
      const ImageConfiguration(),
    );
    final listener = ImageStreamListener((info, _) {
      final height = info.image.height.toDouble();
      if (!mounted || height <= 0) return;
      setState(() {
        _aspect = clampPublishedAspectRatio(info.image.width / height);
      });
    }, onError: (_, _) {});
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  void _stop() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final naturalHeight = width / _aspect;
        final aspect = naturalHeight > widget.maxPreviewHeight && width > 0
            ? width / widget.maxPreviewHeight
            : _aspect;
        return AspectRatio(
          aspectRatio: aspect,
          child: ForumPostImage(
            imageUrl: widget.imageUrl,
            shareText: widget.shareText,
            borderRadius: widget.borderRadius,
            maxPreviewHeight: widget.maxPreviewHeight,
            showExpandHint: widget.showExpandHint,
            fit: BoxFit.contain,
          ),
        );
      },
    );
  }
}
