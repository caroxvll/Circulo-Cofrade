import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'forum_post_image_viewer.dart';

/// Montón de fotos: la primera delante y hasta dos asomando detrás.
class EditorialPhotoStack extends StatelessWidget {
  const EditorialPhotoStack({
    super.key,
    required this.providers,
    this.onTap,
  });

  factory EditorialPhotoStack.network({
    Key? key,
    required List<String> urls,
    VoidCallback? onTap,
  }) {
    return EditorialPhotoStack(
      key: key,
      onTap: onTap,
      providers: [
        for (final url in urls)
          if (url.trim().isNotEmpty) CachedNetworkImageProvider(url.trim()),
      ],
    );
  }

  factory EditorialPhotoStack.memory({
    Key? key,
    required List<Uint8List> images,
  }) {
    return EditorialPhotoStack(
      key: key,
      providers: [for (final bytes in images) MemoryImage(bytes)],
    );
  }

  /// De delante hacia atrás.
  final List<ImageProvider> providers;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (providers.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardW = width * 0.72;
        final cardH = cardW * 1.18;
        final shown = providers.length > 3 ? 3 : providers.length;
        final fan = width * 0.05;
        final pile = SizedBox(
          height: cardH + 36,
          width: width,
          child: Center(
            child: SizedBox(
              width: cardW + fan * 2,
              height: cardH + 20,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  if (shown >= 3)
                    _placed(
                      providers[2],
                      cardW: cardW,
                      cardH: cardH,
                      angle: -0.07,
                      offset: Offset(-fan, 6),
                    ),
                  if (shown >= 2)
                    _placed(
                      providers[1],
                      cardW: cardW,
                      cardH: cardH,
                      angle: 0.08,
                      offset: Offset(fan, -6),
                    ),
                  _placed(
                    providers[0],
                    cardW: cardW,
                    cardH: cardH,
                    angle: -0.01,
                    offset: Offset.zero,
                  ),
                  if (providers.length > 1)
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: _CountBadge(count: providers.length),
                    ),
                ],
              ),
            ),
          ),
        );

        return Semantics(
          button: onTap != null,
          label: providers.length > 1 ? '${providers.length} fotos' : 'Foto',
          child: Material(
            color: Colors.transparent,
            child: onTap == null
                ? pile
                : InkWell(
                    onTap: onTap,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    child: pile,
                  ),
          ),
        );
      },
    );
  }

  Widget _placed(
    ImageProvider provider, {
    required double cardW,
    required double cardH,
    required double angle,
    required Offset offset,
  }) {
    return Transform.translate(
      offset: offset,
      child: Transform.rotate(
        angle: angle,
        child: _PhotoCard(
          provider: provider,
          width: cardW,
          height: cardH,
        ),
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.provider,
    required this.width,
    required this.height,
  });

  final ImageProvider provider;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF241F1C).withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Image(
          image: provider,
          width: width - 6,
          height: height - 6,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) =>
              const ColoredBox(color: Color(0xFFE7DFD6)),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF241F1C).withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.photo_library_outlined,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void openEditorialPhotoGallery(
  BuildContext context,
  List<String> urls, {
  String? shareText,
}) {
  final clean = [
    for (final url in urls)
      if (url.trim().isNotEmpty) url.trim(),
  ];
  if (clean.isEmpty) return;
  showForumPostImageViewer(
    context,
    imageUrl: clean.first,
    imageUrls: clean,
    shareText: shareText,
  );
}
