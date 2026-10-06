import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/user_profile.dart';
import '../../forums/utils/cofrade_gamification.dart';
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
    final hasTrayectoria = _hasTrayectoria(profile);
    final hasContent = hasBio || dataItems.isNotEmpty || hasTrayectoria;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight;
        if (!maxH.isFinite || maxH <= 0) {
          return const SizedBox.shrink();
        }

        if (!hasContent && isAuthenticated) {
          return SizedBox(
            height: maxH,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                ProfileDesign.screenPadding,
                8,
                ProfileDesign.screenPadding,
                8,
              ),
              child: Column(
                children: [
                  if (hasTrayectoria) ...[
                    Expanded(
                      flex: 3,
                      child: ProfileCofradeRankHistory(
                        profile: profile,
                        compact: true,
                        fillHeight: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const Expanded(
                    child: Center(
                      child: ProfileEmptyState(
                        icon: Icons.edit_outlined,
                        title: 'Completa tu perfil',
                        subtitle:
                            'Pulsa Editar en el menú (···) para añadir '
                            'tu bio, dirección, fundación o sitio web.',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SizedBox(
          height: maxH,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              ProfileDesign.screenPadding,
              6,
              ProfileDesign.screenPadding,
              6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasTrayectoria) ...[
                  Expanded(
                    flex: 5,
                    child: ProfileCofradeRankHistory(
                      profile: profile,
                      compact: true,
                      fillHeight: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const ProfileSectionLabel('Sobre mí'),
                const SizedBox(height: 4),
                _BioCard(bio: profile.bio, compact: true),
                const SizedBox(height: 8),
                const ProfileSectionLabel('Datos generales'),
                const SizedBox(height: 4),
                if (dataItems.isEmpty)
                  _PlaceholderCard(
                    icon: Icons.info_outline_rounded,
                    text: isAuthenticated
                        ? 'Sin datos adicionales todavía.'
                        : 'Sin información pública.',
                    compact: true,
                  )
                else
                  _CompactDataRow(items: dataItems),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _hasTrayectoria(UserProfile profile) {
    if (profile.trophyPoints <= 0) return false;
    return achievedCofradeRanks(profile.trophyPoints).length > 1;
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

/// Datos en fila compacta (2–3) para caber sin scroll.
class _CompactDataRow extends StatelessWidget {
  const _CompactDataRow({required this.items});

  final List<ProfileInfoItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.length == 1) {
      return InfoCard(item: items.first, compact: true);
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: InfoCard(item: items[i], compact: true)),
          ],
        ],
      ),
    );
  }
}

class _BioCard extends StatelessWidget {
  const _BioCard({required this.bio, this.compact = false});

  final String bio;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final trimmed = bio.trim();
    if (trimmed.isEmpty) {
      return _PlaceholderCard(
        icon: Icons.notes_outlined,
        text: 'Sin bio todavía.',
        compact: compact,
      );
    }

    return Container(
      width: double.infinity,
      decoration: ProfileDesign.cardDecoration(),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 10 : 14,
      ),
      child: Text(
        trimmed,
        style: AppTypography.bodyMedium(color: AppColors.textPrimary).copyWith(
          fontSize: compact ? 13 : null,
          height: 1.3,
        ),
        maxLines: compact ? 3 : null,
        overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
      ),
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard({
    required this.icon,
    required this.text,
    this.compact = false,
  });

  final IconData icon;
  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: ProfileDesign.cardDecoration(),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 12 : 18,
      ),
      child: Row(
        children: [
          Icon(icon, size: compact ? 16 : 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: ProfileDesign.meta().copyWith(fontSize: compact ? 12 : null),
            ),
          ),
        ],
      ),
    );
  }
}
