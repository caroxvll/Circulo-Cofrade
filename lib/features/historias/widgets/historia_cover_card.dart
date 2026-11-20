import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../cronicon_brand.dart';
import '../models/historia.dart';

class HistoriaCoverCard extends StatelessWidget {
  const HistoriaCoverCard({
    super.key,
    required this.historia,
    this.width,
    this.showMeta = true,
    this.showAuthor = true,
  });

  static const metaHeight = 44.0;

  final Historia historia;
  final double? width;
  final bool showMeta;
  final bool showAuthor;

  static int columnsFor(double width) {
    if (width >= 1100) return 4;
    if (width >= 720) return 3;
    return 2;
  }

  static SliverGridDelegate gridDelegateFor(
    double width, {
    double horizontalPadding = 32,
  }) {
    const spacing = 16.0;
    final columns = columnsFor(width);
    final cellW =
        (width - horizontalPadding - spacing * (columns - 1)) / columns;
    final safeW = cellW.isFinite && cellW > 80 ? cellW : 160.0;
    final aspect = safeW / (safeW * 4 / 3 + metaHeight);
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      mainAxisSpacing: 20,
      crossAxisSpacing: spacing,
      childAspectRatio: aspect.clamp(0.52, 0.72),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plate = _CoverPlate(historia: historia);
    final meta = showMeta
        ? SizedBox(
            height: metaHeight,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    historia.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.hermandadName().copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    showAuthor
                        ? '${historia.kind.label} · ${historia.authorDisplayName}'
                        : historia.kind.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall(color: AppColors.goldDark)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          )
        : null;

    Widget card;
    if (width != null) {
      card = SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(aspectRatio: 3 / 4, child: plate),
            ?meta,
          ],
        ),
      );
    } else {
      card = ClipRect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: plate),
            ?meta,
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => context.push('/historias/${historia.id}'),
      borderRadius: BorderRadius.circular(4),
      child: card,
    );
  }
}

class _CoverPlate extends StatelessWidget {
  const _CoverPlate({required this.historia});

  final Historia historia;

  @override
  Widget build(BuildContext context) {
    final cover = historia.coverImageUrl?.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: AppColors.burgundyDark.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(3, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: cover != null && cover.isNotEmpty
            ? LayoutBuilder(
                builder: (context, constraints) {
                  final side = constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : 180.0;
                  return CofradeoNetworkImage(
                    url: cover,
                    fit: BoxFit.cover,
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    cacheSize: side,
                  );
                },
              )
            : _GeneratedCover(historia: historia),
      ),
    );
  }
}

class _GeneratedCover extends StatelessWidget {
  const _GeneratedCover({required this.historia});

  final Historia historia;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF3A1A16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              CroniconBrand.imprintLine,
              style: AppTypography.labelSmall(color: AppColors.gold).copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                fontSize: 8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              historia.kind.label.toUpperCase(),
              style: AppTypography.labelSmall(color: AppColors.goldPale)
                  .copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                fontSize: 10,
              ),
            ),
            const Spacer(),
            Text(
              historia.title,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.hermandadName(color: AppColors.textOnDark)
                  .copyWith(fontSize: 18, height: 1.15),
            ),
            const SizedBox(height: 8),
            Text(
              historia.authorDisplayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSmall(color: AppColors.goldPale),
            ),
          ],
        ),
      ),
    );
  }
}
