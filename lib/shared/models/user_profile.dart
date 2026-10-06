import 'package:flutter/material.dart';

import 'user_role.dart';

enum AccountType {
  cofrade,
  brotherhood;

  static AccountType fromDb(String? raw) => switch (raw) {
        'brotherhood' => AccountType.brotherhood,
        _ => AccountType.cofrade,
      };

  bool get isBrotherhood => this == AccountType.brotherhood;
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.handle,
    required this.bio,
    required this.publicationCount,
    required this.followerCount,
    required this.avatarIcon,
    required this.address,
    required this.foundedLabel,
    required this.website,
    this.avatarUrl,
    this.isVerified = false,
    this.role = UserRole.member,
    this.isSuspended = false,
    this.suspendedReason,
    this.trophyPoints = 0,
    this.isPrivate = false,
    this.coverImageUrl,
    this.accountType = AccountType.cofrade,
  });

  final String id;

  final String displayName;

  final String handle;

  final String bio;

  final int publicationCount;

  final int followerCount;

  final IconData avatarIcon;

  final String address;

  final String foundedLabel;

  final String website;

  final String? avatarUrl;
  final bool isVerified;
  final UserRole role;
  final bool isSuspended;
  final String? suspendedReason;

  /// Puntos de trofeo del foro (cache en Supabase).
  final int trophyPoints;

  /// Perfil privado: solo seguidores ven el contenido completo.
  final bool isPrivate;

  /// Portada del header. Null = asset por defecto.
  final String? coverImageUrl;

  final AccountType accountType;

  bool get isAdmin => role.isAdmin;

  /// Cuenta oficial de hermandad lista para avisos oficiales (live SS, etc.).
  bool get isOfficialHermandad =>
      accountType.isBrotherhood && isVerified && !isSuspended;
}

class ProfileInfoItem {
  const ProfileInfoItem({
    required this.icon,

    required this.label,

    required this.value,
  });

  final IconData icon;

  final String label;

  final String value;
}
