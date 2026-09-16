import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cofradeo_avatar.dart';
import '../../../shared/models/followed_topic.dart';
import '../../../shared/models/user_profile.dart';
import '../../forums/utils/hermandad_board_display.dart';
import '../../forums/widgets/hermandad_follow_sections_sheet.dart';
import '../../search/follows_provider.dart';
import '../profile_design.dart';
import 'profile_following_filters.dart';
import 'profile_screen_header.dart';
import 'profile_section_header.dart';
import 'profile_section_label.dart';

class FollowingTab extends ConsumerStatefulWidget {
  const FollowingTab({super.key});

  @override
  ConsumerState<FollowingTab> createState() => _FollowingTabState();
}

class _FollowingTabState extends ConsumerState<FollowingTab> {
  FollowingSegment _segment = FollowingSegment.personas;

  @override
  Widget build(BuildContext context) {
    final profilesAsync = ref.watch(followedProfilesDetailsProvider);
    final hashtagsAsync = ref.watch(followedHashtagsProvider);
    final topicsAsync = ref.watch(followedTopicsDetailsProvider);

    return profilesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error al cargar seguimientos')),
      data: (profiles) {
        final hashtags = hashtagsAsync.asData?.value ?? {};
        final topics = topicsAsync.asData?.value ?? [];
        final hermandades =
            topics.where((topic) => topic.isHermandadBoard).toList();
        final hilos =
            topics.where((topic) => !topic.isHermandadBoard).toList();
        final forosCount = hermandades.length + hilos.length + hashtags.length;

        if (profiles.isEmpty && forosCount == 0) {
          return ListView(
            padding: const EdgeInsets.all(ProfileDesign.screenPadding),
            children: const [
              ProfileEmptyState(
                icon: Icons.person_add_outlined,
                title: 'Aún no sigues a nadie',
                subtitle: 'Sigue hermandades en sus tablones, hashtags en Buscar '
                    'o cuentas en los foros.',
              ),
            ],
          );
        }

        final showPersonas = _segment == FollowingSegment.personas;
        final personaEmpty = profiles.isEmpty;
        final forosEmpty = forosCount == 0;

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            ProfileDesign.screenPadding,
            12,
            ProfileDesign.screenPadding,
            28,
          ),
          children: [
            ProfileSectionHeader(
              icon: Icons.bookmark_outline_rounded,
              label: 'Siguiendo',
              count: profiles.length + forosCount,
            ),
            const SizedBox(height: 10),
            const ProfileSectionLabel('Ver por tipo'),
            const SizedBox(height: 8),
            ProfileFollowingFilters(
              segment: _segment,
              onSelected: (segment) => setState(() => _segment = segment),
            ),
            const SizedBox(height: 14),
            if (showPersonas) ...[
              if (personaEmpty)
                const _SegmentEmptyState(
                  icon: Icons.person_outline_rounded,
                  message: 'No sigues a ninguna cuenta todavía.',
                )
              else
                for (final profile in profiles)
                  _ProfileFollowTile(profile: profile),
            ] else ...[
              if (forosEmpty)
                const _SegmentEmptyState(
                  icon: Icons.forum_outlined,
                  message: 'No sigues foros, hilos ni hashtags.',
                )
              else ...[
                if (hermandades.isNotEmpty) ...[
                  _MiniSectionHeader(
                    icon: Icons.church_outlined,
                    label: 'Hermandades',
                    count: hermandades.length,
                  ),
                  const SizedBox(height: 8),
                  for (final topic in hermandades)
                    _HermandadFollowTile(topic: topic),
                  const SizedBox(height: 12),
                ],
                if (hilos.isNotEmpty) ...[
                  _MiniSectionHeader(
                    icon: Icons.forum_outlined,
                    label: 'Hilos',
                    count: hilos.length,
                  ),
                  const SizedBox(height: 8),
                  for (final topic in hilos) _TopicFollowTile(topic: topic),
                  const SizedBox(height: 12),
                ],
                if (hashtags.isNotEmpty) ...[
                  _MiniSectionHeader(
                    icon: Icons.tag_rounded,
                    label: 'Hashtags',
                    count: hashtags.length,
                  ),
                  const SizedBox(height: 8),
                  for (final tag in hashtags.toList()..sort())
                    _HashtagFollowTile(hashtag: tag),
                ],
              ],
            ],
          ],
        );
      },
    );
  }
}

class _MiniSectionHeader extends StatelessWidget {
  const _MiniSectionHeader({
    required this.icon,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.goldDark),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.labelSmall(
            color: AppColors.burgundy,
          ).copyWith(fontWeight: FontWeight.w700, fontSize: 12),
        ),
        const SizedBox(width: 6),
        Text(
          '($count)',
          style: ProfileDesign.meta().copyWith(fontSize: 11),
        ),
      ],
    );
  }
}

class _SegmentEmptyState extends StatelessWidget {
  const _SegmentEmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
      decoration: ProfileDesign.cardDecoration(),
      child: Column(
        children: [
          Icon(icon, size: 28, color: AppColors.textMuted),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTypography.bodyMedium(),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _HermandadFollowTile extends ConsumerWidget {
  const _HermandadFollowTile({required this.topic});

  final FollowedTopic topic;

  Future<void> _openNotifySheet(BuildContext context, WidgetRef ref) async {
    final outcome = await showHermandadFollowSectionsSheet(
      context,
      initialCategories: topic.notifyOfficialCategories,
      following: true,
    );
    if (!context.mounted || outcome == null) return;

    if (outcome.unfollow) {
      await ref.read(topicFollowControllerProvider).toggle(
            topicId: topic.topicId,
            currentlyFollowing: true,
          );
      return;
    }

    await ref.read(topicFollowControllerProvider).updateNotifyCategories(
          topicId: topic.topicId,
          notifyOfficialCategories: outcome.categories,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parsed = parseHermandadTopicTitle(topic.title);
    final notifyLabel =
        hermandadNotifyCategoriesLabel(topic.notifyOfficialCategories);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push(
            '/foros/${topic.forumId}/tema/${topic.topicId}',
          ),
          borderRadius: BorderRadius.circular(ProfileDesign.cardRadius),
          child: Ink(
            decoration: ProfileDesign.cardDecoration(highlighted: true),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _ForumIconBadge(icon: Icons.church_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (parsed.processionDay != null)
                            Text(
                              parsed.processionDay!,
                              style: AppTypography.labelSmall(
                                color: AppColors.goldDark,
                              ).copyWith(fontSize: 10),
                            ),
                          Text(
                            parsed.hermandadName,
                            style: AppTypography.titleLarge().copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Avisos: $notifyLabel',
                            style: ProfileDesign.meta().copyWith(fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _openNotifySheet(context, ref),
                      icon: const Icon(Icons.tune_outlined, size: 15),
                      label: const Text('Ajustar avisos'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.burgundy,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const Spacer(),
                    _UnfollowChip(
                      onTap: () => ref
                          .read(topicFollowControllerProvider)
                          .toggle(
                            topicId: topic.topicId,
                            currentlyFollowing: true,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopicFollowTile extends ConsumerWidget {
  const _TopicFollowTile({required this.topic});

  final FollowedTopic topic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push(
            '/foros/${topic.forumId}/tema/${topic.topicId}',
          ),
          borderRadius: BorderRadius.circular(ProfileDesign.cardRadius),
          child: Ink(
            decoration: ProfileDesign.cardDecoration(),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const _ForumIconBadge(icon: Icons.forum_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic.title,
                        style: AppTypography.titleLarge().copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (topic.preview.isNotEmpty)
                        Text(
                          topic.preview,
                          style: ProfileDesign.meta(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                _UnfollowChip(
                  onTap: () => ref.read(topicFollowControllerProvider).toggle(
                        topicId: topic.topicId,
                        currentlyFollowing: true,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HashtagFollowTile extends ConsumerWidget {
  const _HashtagFollowTile({required this.hashtag});

  final String hashtag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: ProfileDesign.cardDecoration(),
        child: Row(
          children: [
            const _ForumIconBadge(icon: Icons.tag_rounded),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hashtag,
                style: AppTypography.titleLarge().copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _UnfollowChip(
              onTap: () => ref.read(hashtagFollowControllerProvider).toggle(
                    hashtag: hashtag,
                    currentlyFollowing: true,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileFollowTile extends ConsumerWidget {
  const _ProfileFollowTile({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/perfil/usuario/${profile.id}'),
          borderRadius: BorderRadius.circular(ProfileDesign.cardRadius),
          child: Ink(
            decoration: ProfileDesign.cardDecoration(),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CofradeoAvatar(
                  imageUrl: profile.avatarUrl,
                  icon: profile.avatarIcon,
                  size: 42,
                  backgroundColor: AppColors.burgundyDark,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.displayName,
                        style: AppTypography.titleLarge().copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        profile.handle,
                        style: ProfileDesign.meta().copyWith(
                          color: AppColors.burgundy,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _UnfollowChip(
                  onTap: () => ref.read(profileFollowControllerProvider).toggle(
                        profileId: profile.id,
                        currentlyFollowing: true,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ForumIconBadge extends StatelessWidget {
  const _ForumIconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.goldPale.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Icon(icon, size: 20, color: AppColors.goldDark),
    );
  }
}

class _UnfollowChip extends StatelessWidget {
  const _UnfollowChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.85),
            ),
          ),
          child: Text(
            'Dejar',
            style: AppTypography.labelSmall(
              color: AppColors.textMuted,
            ).copyWith(fontWeight: FontWeight.w600, fontSize: 10),
          ),
        ),
      ),
    );
  }
}
