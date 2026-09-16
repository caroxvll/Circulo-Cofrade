import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cofradeo_avatar.dart';
import '../../../shared/models/user_profile.dart';
import '../../forums/widgets/forums_beige_background.dart';
import '../../search/follows_provider.dart';
import '../profile_design.dart';
import 'profile_screen_header.dart';
import 'profile_section_header.dart';

/// Lista de cuentas que siguen al usuario actual.
class FollowersScreen extends ConsumerWidget {
  const FollowersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followersAsync = ref.watch(myFollowersDetailsProvider);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        image: forumsBeigeDecorationImage(context),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Seguidores'),
          backgroundColor: Colors.transparent,
        ),
        body: followersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No se pudieron cargar los seguidores.\n'
                '¿Ejecutaste follows_see_followers.sql?',
                style: AppTypography.bodyMedium(),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (followers) {
            if (followers.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(ProfileDesign.screenPadding),
                children: const [
                  ProfileEmptyState(
                    icon: Icons.group_outlined,
                    title: 'Aún no tienes seguidores',
                    subtitle:
                        'Cuando alguien te siga desde los foros, aparecerá aquí.',
                  ),
                ],
              );
            }

            return RefreshIndicator(
              color: AppColors.burgundy,
              onRefresh: () async {
                ref.invalidate(myFollowersDetailsProvider);
                await ref.read(myFollowersDetailsProvider.future);
              },
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  ProfileDesign.screenPadding,
                  12,
                  ProfileDesign.screenPadding,
                  28,
                ),
                itemCount: followers.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ProfileSectionHeader(
                        icon: Icons.group_outlined,
                        label: 'Te siguen',
                        count: followers.length,
                      ),
                    );
                  }
                  return _FollowerTile(profile: followers[index - 1]);
                },
              ),
            );
          },
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
    final isFollowing = followingIds.contains(profile.id);

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
                TextButton(
                  onPressed: () async {
                    await ref.read(profileFollowControllerProvider).toggle(
                          profileId: profile.id,
                          currentlyFollowing: isFollowing,
                        );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor:
                        isFollowing ? AppColors.textMuted : AppColors.burgundy,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(isFollowing ? 'Siguiendo' : 'Seguir'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
