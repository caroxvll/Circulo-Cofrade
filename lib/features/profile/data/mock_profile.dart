import 'package:flutter/material.dart';

import '../../../shared/models/user_profile.dart';

/// Perfil mock del usuario «logueado» en fases 0–7.
const mockCurrentProfile = UserProfile(
  id: 'hermandad-sevilla',
  displayName: 'Hermandad Sevilla',
  handle: '@hermandad_sevilla',
  bio: 'Bienvenidos a la cuenta oficial de la Hermandad. Paz y Misericordia.',
  publicationCount: 150,
  followerCount: 15200,
  avatarIcon: Icons.face_3,
  address: 'Calle Sierpes, 12, Sevilla',
  foundedLabel: 'Fundada en 1565',
  website: 'www.hermandadsevilla.es',
);

const mockProfileInfoItems = <ProfileInfoItem>[
  ProfileInfoItem(
    icon: Icons.location_on_outlined,
    label: 'Dirección',
    value: 'Calle Sierpes, 12, Sevilla',
  ),
  ProfileInfoItem(
    icon: Icons.calendar_today_outlined,
    label: 'Fundación',
    value: 'Fundada en 1565',
  ),
  ProfileInfoItem(
    icon: Icons.language_outlined,
    label: 'Sitio Web',
    value: 'www.hermandadsevilla.es',
  ),
];

String formatFollowerCount(int n) {
  if (n >= 10000) {
    return '${(n / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
  }
  if (n >= 1000) {
    return '${(n / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
  }
  return '$n';
}
