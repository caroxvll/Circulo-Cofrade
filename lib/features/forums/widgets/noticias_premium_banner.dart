import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_decode_cache.dart';
import '../../../shared/models/forum.dart';
import '../data/mock_forums.dart';
import '../utils/forum_activity_badge.dart';
import 'forum_category_card.dart';

/// Card editorial de Noticias: crema a la izquierda + foto difuminada a la derecha.
class NoticiasPremiumBanner extends StatelessWidget {
  const NoticiasPremiumBanner({
    super.key,
    required this.forum,
    required this.onTap,
  });

  final ForumCategory forum;
  final VoidCallback onTap;

  static const height = 136.0;

  static const _shortDescription =
      'Última hora de la Semana Santa de Sevilla.';

  @override
  Widget build(BuildContext context) {
    final activity = forumActivityLevel(forum);
    final locked = forum.isLocked;
    final description = _editorialDescription(forum.description);
    final imageCache = ImageDecodeCache.px(
      context,
      MediaQuery.sizeOf(context).width * 0.75,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
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
                  // Foto a la derecha; máscara larga para que no se note el borde.
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
                  // Crema suave encima: texto legible + transición continua.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          AppColors.surfaceAlt,
                          AppColors.surfaceAlt,
                          Color(0xE6F5EFE8), // ~90%
                          Color(0x73F5EFE8), // ~45%
                          Color(0x00F5EFE8),
                        ],
                        stops: [0.0, 0.30, 0.48, 0.66, 0.86],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
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
                                  fontSize: 20,
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
                        const SizedBox(height: 4),
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
                        const SizedBox(height: 8),
                        // Descripción solo en zona crema segura.
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
                              fontSize: 13.5,
                              height: 1.28,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Spacer(),
                        FractionallySizedBox(
                          widthFactor: 0.62,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 13,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_shortCount(forum.messageCount)} mensajes',
                                style: AppTypography.labelSmall(
                                  color: AppColors.textMuted,
                                ).copyWith(fontSize: 11, height: 1.1),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Container(
                                  width: 1,
                                  height: 11,
                                  color: AppColors.border.withValues(alpha: 0.7),
                                ),
                              ),
                              Icon(
                                Icons.newspaper_outlined,
                                size: 13,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '${_shortCount(forum.topicCount)} ${_topicLabel(forum.topicCount)}',
                                  style: AppTypography.labelSmall(
                                    color: AppColors.textMuted,
                                  ).copyWith(fontSize: 11, height: 1.1),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
            ),
          ),
        ),
      ),
    );
  }

  /// Evita el texto largo de Junta aunque el pilar remoto aún lo tenga.
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
