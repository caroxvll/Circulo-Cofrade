import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cofradeo_avatar.dart';
import '../../../core/widgets/verified_account_badge.dart';
import '../../../shared/models/user_profile.dart';
import '../../permissions/permissions_provider.dart';
import '../../search/follows_provider.dart';
import '../../forums/widgets/profile_cofrade_rank_section.dart';
import '../profile_design.dart';
import '../profile_provider.dart';
import 'profile_inline_stats.dart';

class ProfileHeader extends ConsumerWidget {
  const ProfileHeader({
    super.key,
    required this.profile,
    this.showFollowingCount = false,
    this.onFollowersTap,
    this.onFollowingTap,
  });

  final UserProfile profile;
  final bool showFollowingCount;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isJunta = ref.watch(isJuntaMemberProvider);
    final currentProfile = ref.watch(currentUserProfileProvider).asData?.value;
    final isOwnProfile = currentProfile?.id == profile.id;
    final followingAsync =
        showFollowingCount ? ref.watch(followingCountProvider) : null;

    final roleChip = _roleChip(
      profile: profile,
      isJunta: isJunta,
      isOwnProfile: isOwnProfile,
    );

    return Container(
      decoration: ProfileDesign.heroCardDecoration(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _AvatarRing(profile: profile),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              profile.displayName,
                              style: ProfileDesign.identityName(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (profile.isVerified || profile.isAdmin) ...[
                            const SizedBox(width: 4),
                            const VerifiedAccountIcon(size: 15),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile.handle,
                        style: ProfileDesign.identityHandle(),
                      ),
                      const SizedBox(height: 2),
                      AuthorCofradeRankLine(
                        trophyPoints: profile.trophyPoints,
                      ),
                      if (profile.address.isNotEmpty || roleChip != null) ...[
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 6,
                          runSpacing: 5,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (profile.address.isNotEmpty)
                              _MetaChip(
                                icon: Icons.location_on_outlined,
                                label: profile.address,
                              ),
                            ?roleChip,
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(
              height: 1,
              color: AppColors.gold.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
            ProfileInlineStats(
              topicCount: profile.publicationCount,
              followerCount: profile.followerCount,
              followingCount: showFollowingCount
                  ? followingAsync?.maybeWhen(
                      data: (count) => count,
                      orElse: () => 0,
                    )
                  : null,
              onFollowersTap: onFollowersTap ??
                  (isOwnProfile
                      ? () => context.push('/perfil/seguidores')
                      : null),
              onFollowingTap: onFollowingTap,
            ),
          ],
        ),
      ),
    );
  }

  Widget? _roleChip({
    required UserProfile profile,
    required bool isJunta,
    required bool isOwnProfile,
  }) {
    if (profile.isVerified) {
      return const _RoleChip(
        label: 'Verificada',
        icon: Icons.verified,
        tone: _RoleChipTone.gold,
      );
    }
    if (profile.isAdmin) {
      return const _RoleChip(
        label: 'Admin',
        icon: Icons.verified,
        tone: _RoleChipTone.burgundy,
      );
    }
    if (isJunta && isOwnProfile) {
      return const _RoleChip(
        label: 'Moderador',
        icon: Icons.gavel_outlined,
        tone: _RoleChipTone.gold,
      );
    }
    return null;
  }
}

class _AvatarRing extends StatelessWidget {
  const _AvatarRing({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    const size = ProfileDesign.headerAvatarSize;
    const ring = ProfileDesign.headerAvatarRing;

    return Container(
      padding: const EdgeInsets.all(ring),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: CofradeoAvatar(
        imageUrl: profile.avatarUrl,
        icon: profile.avatarIcon,
        size: size - ring * 2,
        backgroundColor: AppColors.burgundyDark,
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.textMuted),
          const SizedBox(width: 3),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              label,
              style: ProfileDesign.meta().copyWith(fontSize: 10.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

enum _RoleChipTone { burgundy, gold }

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.icon,
    required this.tone,
  });

  final String label;
  final IconData icon;
  final _RoleChipTone tone;

  @override
  Widget build(BuildContext context) {
    final accent =
        tone == _RoleChipTone.burgundy ? AppColors.burgundy : AppColors.goldDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.goldPale.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: accent),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTypography.labelSmall(color: accent).copyWith(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
