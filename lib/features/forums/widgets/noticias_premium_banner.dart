import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_decode_cache.dart';
import '../../../shared/models/forum.dart';
import '../data/mock_forums.dart';
import '../utils/forum_activity_badge.dart';
import 'forum_category_card.dart';

/// Card editorial de Noticias: descripción + spoiler de la última noticia.
class NoticiasPremiumBanner extends StatelessWidget {
  const NoticiasPremiumBanner({
    super.key,
    required this.forum,
    required this.onTap,
  });

  final ForumCategory forum;
  final VoidCallback onTap;

  static const height = 148.0;

  static const _shortDescription =
      'Última hora de la Semana Santa de Sevilla.';

  @override
  Widget build(BuildContext context) {
    final activity = forumActivityLevel(forum);
    final locked = forum.isLocked;
    final description = _editorialDescription(forum.description);
    final topicTitle = forum.lastTopicTitle?.trim();
    final topicId = forum.lastTopicId?.trim();
    final hasTopic =
        topicTitle != null &&
        topicTitle.isNotEmpty &&
        topicId != null &&
        topicId.isNotEmpty;
    final ago = forum.lastMessageAgo.trim();
    final imageCache = ImageDecodeCache.px(
      context,
      MediaQuery.sizeOf(context).width * 0.75,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(ForumCategoryCard.cardRadius),
        child: InkWell(
          onTap: locked ? null : onTap,
          borderRadius: BorderRadius.circular(ForumCategoryCard.cardRadius),
          splashColor: AppColors.burgundy.withValues(alpha: 0.06),
          highlightColor: AppColors.gold.withValues(alpha: 0.04),
          child: Ink(
            height: height,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(ForumCategoryCard.cardRadius),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.28),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ForumCategoryCard.cardRadius),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: 0.72,
                      heightFactor: 1,
                      child: Opacity(
                        opacity: locked ? 0.32 : 1,
                        child: ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (bounds) {
                            return const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Color(0x00000000),
                                Color(0x14000000),
                                Color(0x4D000000),
                                Color(0x99000000),
                                Color(0xE0000000),
                                Color(0xFF000000),
                              ],
                              stops: [0.0, 0.12, 0.28, 0.48, 0.72, 1.0],
                            ).createShader(bounds);
                          },
                          child: Image.asset(
                            AppAssets.noticiasCover,
                            fit: BoxFit.cover,
                            alignment: const Alignment(0.3, -0.05),
                            filterQuality: FilterQuality.medium,
                            height: height,
                            cacheWidth: imageCache,
                            gaplessPlayback: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          AppColors.surfaceAlt,
                          AppColors.surfaceAlt,
                          Color(0xE6F5EFE8),
                          Color(0x73F5EFE8),
                          Color(0x00F5EFE8),
                        ],
                        stops: [0.0, 0.30, 0.48, 0.66, 0.86],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                forum.name,
                                style: AppTypography.displaySmall(
                                  color: locked
                                      ? AppColors.textMuted
                                      : AppColors.burgundyDark,
                                ).copyWith(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w600,
                                  height: 1.05,
                                  letterSpacing: 0.12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _NoticiasActivityChip(
                              level: activity,
                              locked: locked,
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              locked
                                  ? Icons.lock_outline
                                  : Icons.chevron_right,
                              color: locked
                                  ? AppColors.textMuted
                                  : AppColors.burgundyDark,
                              size: 20,
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Container(
                          width: 44,
                          height: 1.5,
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(
                              alpha: locked ? 0.28 : 0.55,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(height: 6),
                        FractionallySizedBox(
                          widthFactor: 0.58,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            description,
                            style: AppTypography.bodyMedium(
                              color: locked
                                  ? AppColors.textMuted
                                  : AppColors.textPrimary,
                            ).copyWith(
                              fontSize: 13,
                              height: 1.25,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasTopic) ...[
                          const SizedBox(height: 10),
                          FractionallySizedBox(
                            widthFactor: 0.58,
                            alignment: Alignment.centerLeft,
                            child: Container(
                              height: 1,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.gold.withValues(alpha: 0.55),
                                    AppColors.gold.withValues(alpha: 0.12),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          FractionallySizedBox(
                            widthFactor: 0.68,
                            alignment: Alignment.centerLeft,
                            child: _LatestNewsSpoiler(
                              title: topicTitle,
                              ago: ago,
                              locked: locked,
                              onOpen: locked
                                  ? null
                                  : () => context.push(
                                        '/foros/${forum.id}/tema/$topicId',
                                      ),
                            ),
                          ),
                        ] else ...[
                          const Spacer(),
                          FractionallySizedBox(
                            widthFactor: 0.62,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${_shortCount(forum.topicCount)} ${_topicLabel(forum.topicCount)}',
                              style: AppTypography.labelSmall(
                                color: AppColors.textMuted,
                              ).copyWith(fontSize: 11, height: 1.1),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _editorialDescription(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return _shortDescription;
    final first = trimmed.split(RegExp(r'[\n.]')).first.trim();
    if (first.isEmpty) return _shortDescription;
    if (first.toLowerCase().contains('publica la junta')) {
      return _shortDescription;
    }
    return first.endsWith('.') ? first : '$first.';
  }

  static String _topicLabel(int count) => count == 1 ? 'noticia' : 'noticias';
}

/// Línea inferior del card: spoiler de la última noticia.
class _LatestNewsSpoiler extends StatelessWidget {
  const _LatestNewsSpoiler({
    required this.title,
    required this.ago,
    required this.locked,
    this.onOpen,
  });

  final String title;
  final String ago;
  final bool locked;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'ÚLTIMA NOTICIA',
          style: AppTypography.labelSmall(
            color: AppColors.burgundy,
          ).copyWith(
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.9,
            height: 1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          title,
          style: AppTypography.displaySmall(
            color: locked ? AppColors.textMuted : AppColors.burgundyDark,
          ).copyWith(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            height: 1.15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (ago.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            ago,
            style: AppTypography.labelSmall(
              color: AppColors.textMuted,
            ).copyWith(fontSize: 10.5, height: 1.1),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );

    if (onOpen == null) return content;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      child: content,
    );
  }
}

class _NoticiasActivityChip extends StatelessWidget {
  const _NoticiasActivityChip({
    required this.level,
    required this.locked,
  });

  final ForumActivityLevel level;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    if (locked) return const SizedBox.shrink();

    final active = level == ForumActivityLevel.active ||
        level == ForumActivityLevel.veryActive;
    final border = active
        ? AppColors.burgundy.withValues(alpha: 0.22)
        : AppColors.border.withValues(alpha: 0.7);
    final fg = active ? AppColors.burgundyDark : AppColors.textMuted;
    final dot = active ? AppColors.burgundy : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            forumActivityLabel(level),
            style: AppTypography.labelSmall(color: fg).copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.15,
            ),
          ),
        ],
      ),
    );
  }
}

String _shortCount(int value) {
  if (value >= 1000) {
    final short = value / 1000;
    return '${short.toStringAsFixed(short >= 10 ? 0 : 1)}k';
  }
  return formatCount(value);
}
