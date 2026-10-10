import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_decode_cache.dart';
import '../../../core/widgets/cofradeo_asset_image.dart';
import '../../../core/widgets/cofradeo_avatar.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../../../core/widgets/verified_account_badge.dart';
import '../../../shared/models/user_profile.dart';
import '../../forums/widgets/forums_beige_background.dart';
import '../../permissions/permissions_provider.dart';
import '../../search/follows_provider.dart';
import '../../forums/widgets/profile_cofrade_rank_section.dart';
import '../profile_design.dart';
import '../profile_provider.dart';
import 'profile_fleur_divider.dart';
import 'profile_inline_stats.dart';

/// Dimensiones del hero; se compactan en pantallas bajas.
class _HeroMetrics {
  const _HeroMetrics({
    required this.peakHeight,
    required this.bannerHeight,
    required this.avatarSize,
  });

  final double peakHeight;
  final double bannerHeight;
  final double avatarSize;

  factory _HeroMetrics.of(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    // Prioriza espacio para los 2 temas (incl. Pro Max ~900+).
    if (h < 900) {
      return const _HeroMetrics(
        peakHeight: 28,
        bannerHeight: 92,
        avatarSize: 64,
      );
    }
    if (h < 980) {
      return const _HeroMetrics(
        peakHeight: 32,
        bannerHeight: 104,
        avatarSize: 72,
      );
    }
    return const _HeroMetrics(
      peakHeight: 36,
      bannerHeight: 116,
      avatarSize: 80,
    );
  }
}

class ProfileHeader extends ConsumerWidget {
  const ProfileHeader({
    super.key,
    required this.profile,
    this.showFollowingCount = false,
    this.followingCountOverride,
    this.onFollowersTap,
    this.onFollowingTap,
  });

  final UserProfile profile;
  final bool showFollowingCount;
  /// Si se pasa, sustituye el conteo de «Siguiendo» (p. ej. perfil ajeno).
  final int? followingCountOverride;
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

    final screenW = MediaQuery.sizeOf(context).width;
    final hero = _HeroMetrics.of(context);
    final screenH = MediaQuery.sizeOf(context).height;
    final compact = screenH < 980;

    // El avatar se centra en el vértice; el bloque corta justo bajo el círculo.
    final avatarBottom =
        hero.bannerHeight - hero.peakHeight + hero.avatarSize * 0.48;
    final heroHeight = avatarBottom + (compact ? 0 : 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: heroHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Portada
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: hero.bannerHeight,
                child: ClipRect(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _ProfileCoverImage(
                        coverUrl: profile.coverImageUrl,
                        screenWidth: screenW,
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.1),
                              Colors.black.withValues(alpha: 0.35),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Panel crema con pico (triángulo) que corta la foto
              Positioned(
                top: hero.bannerHeight - hero.peakHeight,
                left: 0,
                right: 0,
                bottom: 0,
                child: ClipPath(
                  clipper: ProfileHeroPeakClipper(peakHeight: hero.peakHeight),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      image: forumsBeigeDecorationImage(context),
                    ),
                  ),
                ),
              ),
              // Avatar anclado al vértice del pico
              Positioned(
                top: hero.bannerHeight -
                    hero.peakHeight -
                    hero.avatarSize * 0.52,
                left: 0,
                right: 0,
                child: Center(
                  child: _AvatarRing(profile: profile, size: hero.avatarSize),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: compact ? 0 : 2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      profile.displayName,
                      style: ProfileDesign.identityName().copyWith(
                        fontSize: compact ? 18 : 20,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (profile.isVerified || profile.isAdmin) ...[
                    const SizedBox(width: 5),
                    const VerifiedAccountIcon(size: 15),
                  ],
                ],
              ),
              SizedBox(height: compact ? 1 : 2),
              Text(
                profile.handle,
                style: ProfileDesign.identityHandle().copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                  fontSize: compact ? 12 : null,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: compact ? 3 : 5),
              AuthorCofradeRankLine(
                trophyPoints: profile.trophyPoints,
                compact: compact,
                emphasized: true,
              ),
              if (profile.isPrivate) ...[
                SizedBox(height: compact ? 4 : 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 12,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Cuenta privada',
                      style: ProfileDesign.meta().copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ],
              if (profile.address.isNotEmpty || roleChip != null) ...[
                SizedBox(height: compact ? 4 : 6),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (profile.address.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            profile.address,
                            style: ProfileDesign.meta().copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    if (roleChip != null) roleChip,
                  ],
                ),
              ],
              SizedBox(height: compact ? 6 : 10),
              if (!compact) ...[
                const ProfileFleurDivider(),
                const SizedBox(height: 8),
              ],
              ProfileInlineStats(
                topicCount: profile.publicationCount,
                followerCount: profile.followerCount,
                followingCount: showFollowingCount
                    ? (followingCountOverride ??
                        followingAsync?.maybeWhen(
                          data: (count) => count,
                          orElse: () => 0,
                        ))
                    : null,
                onFollowersTap: onFollowersTap ??
                    (isOwnProfile
                        ? () => context.push('/perfil/seguidores')
                        : null),
                onFollowingTap: onFollowingTap ??
                    (isOwnProfile
                        ? () => context.push('/perfil/siguiendo')
                        : null),
                flat: true,
              ),
            ],
          ),
        ),
      ],
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

class _ProfileCoverImage extends StatelessWidget {
  const _ProfileCoverImage({
    required this.coverUrl,
    required this.screenWidth,
  });

  final String? coverUrl;
  final double screenWidth;

  @override
  Widget build(BuildContext context) {
    final url = coverUrl?.trim();
    if (url != null && url.isNotEmpty && !url.startsWith('assets/')) {
      return CofradeoNetworkImage(
        url: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheSize: ImageDecodeCache.px(context, screenWidth).toDouble(),
      );
    }

    return CofradeoAssetImage(
      assetPath: AppAssets.profileHeaderCover,
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.15),
      cacheWidth: ImageDecodeCache.px(context, screenWidth),
      fadeDuration: const Duration(milliseconds: 320),
    );
  }
}

/// Recorta el panel inferior en forma de pico (△ invertido / tienda).
/// El crema “sale” del centro hacia la foto.
class ProfileHeroPeakClipper extends CustomClipper<Path> {
  const ProfileHeroPeakClipper({required this.peakHeight});

  final double peakHeight;

  @override
  Path getClip(Size size) {
    final peak = peakHeight.clamp(0.0, size.height);
    // Pico suave (no demasiado agudo) centrado.
    return Path()
      ..moveTo(0, peak)
      ..quadraticBezierTo(
        size.width * 0.22,
        peak * 0.22,
        size.width * 0.5,
        0,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        peak * 0.22,
        size.width,
        peak,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant ProfileHeroPeakClipper oldClipper) =>
      oldClipper.peakHeight != peakHeight;
}

class _AvatarRing extends StatelessWidget {
  const _AvatarRing({required this.profile, this.size = 88});

  final UserProfile profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    const ring = 3.0;

    return Container(
      padding: const EdgeInsets.all(ring),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.7),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.burgundyDark.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.goldPale.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: accent),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTypography.labelSmall(color: accent).copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
