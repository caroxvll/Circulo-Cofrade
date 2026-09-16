import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/user_profile.dart';
import '../../forums/widgets/profile_cofrade_rank_history.dart';
import '../profile_design.dart';
import 'info_card.dart';
import 'profile_screen_header.dart';
import 'profile_section_label.dart';

class ProfileInfoTab extends StatelessWidget {
  const ProfileInfoTab({
    super.key,
    required this.profile,
    required this.isAuthenticated,
  });

  final UserProfile profile;
  final bool isAuthenticated;

  @override
  Widget build(BuildContext context) {
    final dataItems = _dataItemsFromProfile(profile);
    final hasBio = profile.bio.trim().isNotEmpty;
    final hasContent = hasBio || dataItems.isNotEmpty;

    if (!hasContent && isAuthenticated) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(
          ProfileDesign.screenPadding,
          12,
          ProfileDesign.screenPadding,
          28,
        ),
        children: [
          ProfileCofradeRankHistory(profile: profile),
          if (profile.trophyPoints > 0) const SizedBox(height: 18),
          const ProfileEmptyState(
            icon: Icons.edit_outlined,
            title: 'Completa tu perfil',
            subtitle: 'Pulsa Editar en el menú (···) para añadir '
                'tu bio, dirección, fundación o sitio web.',
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ProfileDesign.screenPadding,
        12,
        ProfileDesign.screenPadding,
        28,
      ),
      children: [
        ProfileCofradeRankHistory(profile: profile),
        if (profile.trophyPoints > 0) const SizedBox(height: 18),
        const ProfileSectionLabel('Sobre mí'),
        const SizedBox(height: 8),
        _BioCard(bio: profile.bio),
        const SizedBox(height: 18),
        const ProfileSectionLabel('Datos generales'),
        const SizedBox(height: 8),
        if (dataItems.isEmpty)
          _PlaceholderCard(
            icon: Icons.info_outline_rounded,
            text: isAuthenticated
                ? 'Sin datos adicionales todavía.'
                : 'Sin información pública.',
          )
        else
          for (var i = 0; i < dataItems.length; i++) ...[
            if (i > 0) const SizedBox(height: ProfileDesign.cardGap),
            InfoCard(item: dataItems[i]),
          ],
      ],
    );
  }

  List<ProfileInfoItem> _dataItemsFromProfile(UserProfile profile) {
    final items = <ProfileInfoItem>[];
    if (profile.address.isNotEmpty) {
      items.add(ProfileInfoItem(
        icon: Icons.location_on_outlined,
        label: 'Dirección',
        value: profile.address,
      ));
    }
    if (profile.foundedLabel.isNotEmpty) {
      items.add(ProfileInfoItem(
        icon: Icons.calendar_today_outlined,
        label: 'Fundación',
        value: profile.foundedLabel,
      ));
    }
    if (profile.website.isNotEmpty) {
      items.add(ProfileInfoItem(
        icon: Icons.language_outlined,
        label: 'Sitio web',
        value: profile.website,
      ));
    }
    return items;
  }
}

class _BioCard extends StatelessWidget {
  const _BioCard({required this.bio});

  final String bio;

  @override
  Widget build(BuildContext context) {
    final trimmed = bio.trim();
    if (trimmed.isEmpty) {
      return _PlaceholderCard(
        icon: Icons.notes_outlined,
        text: 'Sin bio todavía.',
      );
    }

    return Container(
      width: double.infinity,
      decoration: ProfileDesign.cardDecoration(),
      padding: const EdgeInsets.all(14),
      child: Text(
        trimmed,
        style: AppTypography.bodyMedium(color: AppColors.textPrimary),
      ),
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: ProfileDesign.cardDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: ProfileDesign.meta(),
            ),
          ),
        ],
      ),
    );
  }
}
