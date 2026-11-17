import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/forum.dart';
import '../../admin/admin_provider.dart';
import '../forums_provider.dart';
import '../utils/noticias_forum.dart';

Future<void> showUnifyNoticiaSheet(
  BuildContext context,
  WidgetRef ref, {
  required ForumTopic topic,
}) async {
  final cached =
      ref.read(forumTopicsProvider(noticiasForumId)).asData?.value;
  final topics = cached ??
      await ref.read(forumTopicsProvider(noticiasForumId).future) ??
      const <ForumTopic>[];
  if (!context.mounted) return;

  final others = [
    for (final candidate in topics)
      if (candidate.id != topic.id &&
          candidate.isPublished &&
          candidate.isListed)
        candidate,
  ]..sort((a, b) => b.sortTimestamp.compareTo(a.sortTimestamp));

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Unir con otra noticia', style: AppTypography.displaySmall()),
              const SizedBox(height: 4),
              Text(
                'Las dos quedan en un carrusel, cada una con su cuenta. '
                'La que se publicó antes va la primera.',
                style: AppTypography.bodyMedium(color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              if (others.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No hay otra noticia publicada para unir.',
                    style: AppTypography.bodyMedium(color: AppColors.textMuted),
                  ),
                )
              else
                SizedBox(
                  height: MediaQuery.sizeOf(ctx).height * 0.5,
                  child: ListView.separated(
                    itemCount: others.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final other = others[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          other.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${other.authorHandle} · ${other.timeAgo}',
                          style: AppTypography.bodyMedium(
                            color: AppColors.textMuted,
                          ),
                        ),
                        onTap: () async {
                          final messenger = ScaffoldMessenger.maybeOf(context);
                          Navigator.pop(ctx);
                          try {
                            await ref.read(adminRepositoryProvider).unifyNoticias(
                                  topicId: topic.id,
                                  otherTopicId: other.id,
                                );
                            invalidateTopicData(
                              ref,
                              forumId: noticiasForumId,
                              topicId: topic.id,
                            );
                            ref.invalidate(
                              forumTopicProvider(
                                ForumTopicKey(
                                  forumId: noticiasForumId,
                                  topicId: other.id,
                                ),
                              ),
                            );
                            if (context.mounted) Navigator.pop(context);
                            messenger?.showSnackBar(
                              const SnackBar(
                                content: Text('Noticias unidas en un carrusel'),
                              ),
                            );
                          } catch (_) {
                            messenger?.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No se pudo unir. ¿Ejecutaste news_publishers.sql?',
                                ),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
