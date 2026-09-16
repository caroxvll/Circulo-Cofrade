import 'package:flutter/material.dart';

import 'user_role.dart';

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

  bool get isAdmin => role.isAdmin;
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
