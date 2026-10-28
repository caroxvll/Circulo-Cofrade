import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/forum.dart';
import '../../auth/auth_provider.dart';
import '../../calendar/calendar_contributors_provider.dart';
import '../../forums/forums_provider.dart';
import '../../forums/news_publishers_provider.dart';
import '../../forums/utils/topic_list_order.dart';
import '../../forums/utils/topic_permissions.dart';
import '../../forums/widgets/forum_compose_sheet_header.dart';
import '../../forums/widgets/forum_pillar_icon_mark.dart';
import '../../forums/widgets/topic_compose_sheet.dart';
import '../../permissions/permissions_provider.dart';
import '../profile_provider.dart';

/// Elige el foro y abre el compositor de tema.
Future<void> showProfileCreateTopicSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  if (ref.read(isCurrentUserSuspendedProvider)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tu cuenta está suspendida. No puedes crear temas.'),
      ),
    );
    return;
  }

  final forumId = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => const _CreateTopicForumSheet(),
  );
  if (forumId == null || !context.mounted) return;
  await showTopicComposeSheet(context, ref, forumId: forumId);
}

class _CreateTopicForumSheet extends ConsumerWidget {
  const _CreateTopicForumSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pillarsAsync = ref.watch(forumPillarsProvider);
    final modsAsync = ref.watch(moderatedForumIdsProvider);
    final userId = ref.watch(currentUserProvider)?.id;
    final newsAsync =
        userId == null ? null : ref.watch(isNewsPublisherProvider(userId));
    final calendarAsync = userId == null
        ? null
        : ref.watch(isCalendarContributorProvider(userId));

    final waiting = !pillarsAsync.hasValue ||
        !modsAsync.hasValue ||
        (newsAsync != null && !newsAsync.hasValue) ||
        (calendarAsync != null && !calendarAsync.hasValue);

    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 12 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ForumComposeSheetDragHandle(),
          Text(
            '¿Dónde lo abres?',
            style: AppTypography.displaySmall(
              color: AppColors.textPrimary,
            ).copyWith(fontSize: 20, height: 1.2),
          ),
          const SizedBox(height: 6),
          Text(
            'Elige el foro. El tema se publica ahí y también queda en tu perfil.',
            style: AppTypography.bodyMedium(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 13.5, height: 1.35),
          ),
          const SizedBox(height: 14),
          if (waiting)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.burgundy,
                  ),
                ),
              ),
            )
          else if (pillarsAsync.hasError && !pillarsAsync.hasValue)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No se pudieron cargar los foros.',
                style: AppTypography.bodyMedium(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            _ForumChoices(
              forums: _forumsWhereUserCanPost(
                pillars: pillarsAsync.value ?? const [],
                isAdmin: ref.watch(isAdminProvider),
                moderatedForumIds: modsAsync.value ?? const {},
                isNewsPublisher: newsAsync?.value ?? false,
                isCalendarContributor: calendarAsync?.value ?? false,
              ),
            ),
        ],
      ),
    );
  }
}

List<ForumCategory> _forumsWhereUserCanPost({
  required List<ForumCategory> pillars,
  required bool isAdmin,
  required Set<String> moderatedForumIds,
  required bool isNewsPublisher,
  required bool isCalendarContributor,
}) {
  return [
    for (final forum in visibleForumPillars(pillars))
      if (!forum.isLocked &&
          canCreateTopicInForum(
            forumId: forum.id,
            isAdmin: isAdmin,
            moderatedForumIds: moderatedForumIds,
            isNewsPublisher: isNewsPublisher,
            isCalendarContributor: isCalendarContributor,
          ))
        forum,
  ];
}

class _ForumChoices extends StatelessWidget {
  const _ForumChoices({required this.forums});

  final List<ForumCategory> forums;

  @override
  Widget build(BuildContext context) {
    if (forums.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Ahora mismo no hay foros abiertos para publicar.',
          style: AppTypography.bodyMedium(
            color: AppColors.textSecondary,
          ).copyWith(fontSize: 13.5, height: 1.35),
        ),
      );
    }

    final maxList = MediaQuery.sizeOf(context).height * 0.46;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxList),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: forums.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final forum = forums[index];
          return _ForumChoiceTile(
            forum: forum,
            onTap: () => Navigator.pop(context, forum.id),
          );
        },
      ),
    );
  }
}

class _ForumChoiceTile extends StatelessWidget {
  const _ForumChoiceTile({
    required this.forum,
    required this.onTap,
  });

  final ForumCategory forum;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: AppColors.burgundy.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
          child: Row(
            children: [
              ForumPillarIconMark(forum: forum, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      forum.name,
                      style: AppTypography.displaySmall(
                        color: AppColors.burgundyDark,
                      ).copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (forum.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        forum.description.trim(),
                        style: AppTypography.bodyMedium(
                          color: AppColors.textSecondary,
                        ).copyWith(fontSize: 12.5, height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                color: AppColors.burgundyDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
