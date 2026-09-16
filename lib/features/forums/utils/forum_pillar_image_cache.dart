import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/utils/image_decode_cache.dart';
import '../../../shared/models/forum.dart';

/// Precarga portadas, iconos, hero y textura beige en disco/memoria.
Future<void> precacheForumPillarImages(
  BuildContext context,
  List<ForumCategory> pillars, {
  String? heroUrl,
}) async {
  if (!context.mounted) return;

  final ratio = MediaQuery.devicePixelRatioOf(context);
  int px(double logical) => (logical * ratio).round();
  final screen = MediaQuery.sizeOf(context);

  final futures = <Future<void>>[];

  futures.add(
    precacheImage(
      ImageDecodeCache.screenSizedAsset(
        context,
        AppAssets.forumsBeigeBackground,
      ),
      context,
    ),
  );
  futures.add(
    precacheImage(
      ResizeImage(
        const AssetImage(AppAssets.heroProcesion),
        width: px(screen.width),
        policy: ResizeImagePolicy.fit,
        allowUpscaling: false,
      ),
      context,
    ),
  );

  final trimmedHero = heroUrl?.trim();
  if (trimmedHero != null && trimmedHero.isNotEmpty) {
    final heroPx = px(screen.width);
    futures.add(
      precacheImage(
        CachedNetworkImageProvider(
          trimmedHero,
          maxWidth: heroPx,
          maxHeight: heroPx,
        ),
        context,
      ),
    );
  }

  for (final forum in pillars) {
    final coverUrl = forum.coverImageUrl?.trim();
    if (coverUrl != null && coverUrl.isNotEmpty) {
      final coverPx = px(160);
      futures.add(
        precacheImage(
          CachedNetworkImageProvider(
            coverUrl,
            maxWidth: coverPx,
            maxHeight: coverPx,
          ),
          context,
        ),
      );
    }
  }

  if (futures.isEmpty) return;
  await Future.wait(futures);
}
