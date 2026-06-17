import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_branding.dart';
import '../../../shared/models/user_profile.dart';

UserProfile userProfileFromAuth(User user) {
  final meta = user.userMetadata ?? {};
  final handleRaw = meta['handle'] as String? ?? _handleFromEmail(user.email);
  final handle = handleRaw.startsWith('@') ? handleRaw : '@$handleRaw';

  return UserProfile(
    id: user.id,
    displayName: meta['display_name'] as String? ??
        user.email?.split('@').first ??
        'Cofrade',
    handle: handle,
    bio: meta['bio'] as String? ??
        AppBranding.defaultBio,
    publicationCount: (meta['publication_count'] as int?) ?? 0,
    followerCount: (meta['follower_count'] as int?) ?? 0,
    avatarIcon: Icons.face_3,
    address: meta['address'] as String? ?? '',
    foundedLabel: meta['founded_label'] as String? ?? '',
    website: meta['website'] as String? ?? '',
  );
}

String _handleFromEmail(String? email) {
  if (email == null || !email.contains('@')) return 'cofrade';
  return email.split('@').first.toLowerCase();
}
