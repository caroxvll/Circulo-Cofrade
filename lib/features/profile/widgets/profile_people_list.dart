import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cofradeo_avatar.dart';
import '../../../core/widgets/cofradeo_skeleton.dart';
import '../../../shared/models/user_profile.dart';
import '../../forums/utils/cofrade_gamification.dart';
import '../../search/follows_provider.dart';
import '../profile_design.dart';
import 'profile_people_mode.dart';
import 'profile_screen_header.dart';

/// Lista unificada Seguidores / Siguiendo con buscador.
/// Si [forUserId] es null → listas del usuario actual.
class ProfilePeopleList extends ConsumerStatefulWidget {
  const ProfilePeopleList({
    super.key,
    this.forUserId,
  });

  final String? forUserId;

  @override
  ConsumerState<ProfilePeopleList> createState() => _ProfilePeopleListState();
}

class _ProfilePeopleListState extends ConsumerState<ProfilePeopleList> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  bool get _isOwn => widget.forUserId == null;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh(ProfilePeopleMode mode) async {
    if (_isOwn) {
      if (mode == ProfilePeopleMode.seguidores) {
        ref.invalidate(myFollowersDetailsProvider);
        await ref.read(myFollowersDetailsProvider.future);
      } else {
        ref.invalidate(followedProfilesDetailsProvider);
        await ref.read(followedProfilesDetailsProvider.future);
      }
      return;
    }
    final id = widget.forUserId!;
    if (mode == ProfilePeopleMode.seguidores) {
      ref.invalidate(userFollowersDetailsProvider(id));
      await ref.read(userFollowersDetailsProvider(id).future);
    } else {
      ref.invalidate(userFollowingDetailsProvider(id));
      await ref.read(userFollowingDetailsProvider(id).future);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(profilePeopleModeProvider);
    final AsyncValue<List<UserProfile>> async;
    if (_isOwn) {
      async = mode == ProfilePeopleMode.seguidores
          ? ref.watch(myFollowersDetailsProvider)
          : ref.watch(followedProfilesDetailsProvider);
    } else {
      final id = widget.forUserId!;
      async = mode == ProfilePeopleMode.seguidores
          ? ref.watch(userFollowersDetailsProvider(id))
          : ref.watch(userFollowingDetailsProvider(id));
    }

    return async.when(
      skipLoadingOnReload: true,
      loading: () => const PeopleListSkeleton(),
      error: (_, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            mode == ProfilePeopleMode.seguidores
                ? 'No se pudieron cargar los seguidores.'
                : 'No se pudieron cargar las cuentas que sigue.',
            style: AppTypography.bodyMedium(),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (people) {
        final filtered = people
            .where(
              (p) => profileMatchesQuery(
                _query,
                name: p.displayName,
                handle: p.handle,
              ),
            )
            .toList();

        final title = mode == ProfilePeopleMode.seguidores
            ? (_isOwn ? 'Te siguen' : 'Le siguen')
            : (_isOwn ? 'Siguiendo' : 'Sigue');
        final emptyTitle = mode == ProfilePeopleMode.seguidores
            ? (_isOwn
                ? 'Aún no tienes seguidores'
                : 'Aún no tiene seguidores')
            : (_isOwn
                ? 'Aún no sigues a nadie'
                : 'Aún no sigue a nadie');
        final emptySubtitle = mode == ProfilePeopleMode.seguidores
            ? 'Cuando alguien le siga, aparecerá aquí.'
            : 'Las cuentas que sigue aparecerán aquí.';
        final searchHint = mode == ProfilePeopleMode.seguidores
            ? 'Buscar seguidores…'
            : 'Buscar a quien sigue…';

        return RefreshIndicator(
          color: AppColors.burgundy,
          onRefresh: () => _refresh(mode),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              ProfileDesign.screenPadding,
              12,
              ProfileDesign.screenPadding,
              28,
            ),
            children: [
              ProfilePeopleModeToggle(
                mode: mode,
                onSelected: (next) {
                  ref.read(profilePeopleModeProvider.notifier).setMode(next);
                  _searchCtrl.clear();
                  setState(() => _query = '');
                },
              ),
              const SizedBox(height: 12),
              ProfilePeopleSearchField(
                controller: _searchCtrl,
                hint: searchHint,
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 14),
              _PeopleSectionTitle(
                label: title,
                count: people.length,
              ),
              const SizedBox(height: 10),
              if (people.isEmpty)
                ProfileEmptyState(
                  icon: mode == ProfilePeopleMode.seguidores
                      ? Icons.group_outlined
                      : Icons.person_add_outlined,
                  title: emptyTitle,
                  subtitle: emptySubtitle,
                )
              else if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      'Ningún resultado para «${_query.trim()}».',
                      style: AppTypography.bodyMedium(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                for (final profile in filtered)
                  mode == ProfilePeopleMode.seguidores
                      ? _FollowerTile(profile: profile)
                      : _FollowingTile(
                          profile: profile,
                          canUnfollow: _isOwn,
                        ),
            ],
          ),
        );
      },
    );
  }
}

class _PeopleSectionTitle extends StatelessWidget {
  const _PeopleSectionTitle({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: ProfileDesign.sectionTitle()),
        ),
        if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.backgroundElevated,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.7),
              ),
            ),
            child: Text(
              '$count',
              style: ProfileDesign.meta().copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.burgundy,
              ),
            ),
          ),
      ],
    );
  }
}

class _FollowingTile extends ConsumerWidget {
  const _FollowingTile({
    required this.profile,
    this.canUnfollow = true,
  });

  final UserProfile profile;
  final bool canUnfollow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followingIds =
        ref.watch(followedProfilesProvider).asData?.value ?? {};
    final pendingIds =
        ref.watch(pendingOutgoingFollowRequestsProvider).asData?.value ?? {};
    final isFollowing = followingIds.contains(profile.id);
    final isRequested = !isFollowing && pendingIds.contains(profile.id);
    final rank = cofradeRankTitleForPoints(profile.trophyPoints);

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
                      if (rank.isNotEmpty)
                        Text(
                          rank,
                          style: AppTypography.rankTitle(
                            color: AppColors.textMuted,
                          ).copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (canUnfollow)
                  _ActionChip(
                    label: 'Dejar',
                    muted: true,
                    onTap: () =>
                        ref.read(profileFollowControllerProvider).toggle(
                              profileId: profile.id,
                              currentlyFollowing: true,
                            ),
                  )
                else
                  _ActionChip(
                    label: isFollowing
                        ? 'Siguiendo'
                        : isRequested
                            ? 'Solicitado'
                            : 'Seguir',
                    muted: isFollowing || isRequested,
                    onTap: () =>
                        ref.read(profileFollowControllerProvider).toggle(
                              profileId: profile.id,
                              currentlyFollowing: isFollowing,
                              currentlyRequested: isRequested,
                              isPrivate: profile.isPrivate,
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

class _FollowerTile extends ConsumerWidget {
  const _FollowerTile({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followingIds =
        ref.watch(followedProfilesProvider).asData?.value ?? {};
    final pendingIds =
        ref.watch(pendingOutgoingFollowRequestsProvider).asData?.value ?? {};
    final isFollowing = followingIds.contains(profile.id);
    final isRequested = !isFollowing && pendingIds.contains(profile.id);
    final rank = cofradeRankTitleForPoints(profile.trophyPoints);

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
                      if (rank.isNotEmpty)
                        Text(
                          rank,
                          style: AppTypography.rankTitle(
                            color: AppColors.textMuted,
                          ).copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                _ActionChip(
                  label: isFollowing
                      ? 'Siguiendo'
                      : isRequested
                          ? 'Solicitado'
                          : 'Seguir',
                  muted: isFollowing || isRequested,
                  onTap: () => ref.read(profileFollowControllerProvider).toggle(
                        profileId: profile.id,
                        currentlyFollowing: isFollowing,
                        currentlyRequested: isRequested,
                        isPrivate: profile.isPrivate,
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

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.onTap,
    this.muted = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool muted;

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
              color: muted
                  ? AppColors.border.withValues(alpha: 0.85)
                  : AppColors.burgundy.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            label,
            style: AppTypography.labelSmall(
              color: muted ? AppColors.textMuted : AppColors.burgundy,
            ).copyWith(fontWeight: FontWeight.w600, fontSize: 10),
          ),
        ),
      ),
    );
  }
}
