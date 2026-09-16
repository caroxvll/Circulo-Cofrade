import 'package:cofradeo/features/profile/profile_onboarding.dart';
import 'package:cofradeo/shared/models/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

User _user({String email = 'juan@gmail.com'}) {
  return User(
    id: '00000000-0000-0000-0000-000000000001',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: DateTime.now().toIso8601String(),
    email: email,
  );
}

UserProfile _profile({
  String handle = '@cofradeo_juan',
  String displayName = 'Juan Pérez',
}) {
  return UserProfile(
    id: '00000000-0000-0000-0000-000000000001',
    displayName: displayName,
    handle: handle,
    bio: '',
    publicationCount: 0,
    followerCount: 0,
    avatarIcon: Icons.person,
    address: '',
    foundedLabel: '',
    website: '',
  );
}

void main() {
  test('Google con nombre real y handle del email pasa sin onboarding', () {
    final user = _user(email: 'juan.garcia@gmail.com');
    final profile = _profile(
      handle: '@juangarcia',
      displayName: 'Juan García',
    );

    expect(
      isProfileCompleteForOnboarding(user: user, profile: profile),
      isTrue,
    );
    expect(
      needsProfileOnboardingForProfile(user: user, profile: profile),
      isFalse,
    );
  });

  test('email genérico juan@gmail.com sigue pidiendo completar', () {
    final user = _user();
    final profile = _profile(handle: '@juan', displayName: 'Juan');

    expect(
      isProfileCompleteForOnboarding(user: user, profile: profile),
      isFalse,
    );
    expect(
      needsProfileOnboardingForProfile(user: user, profile: profile),
      isTrue,
    );
  });

  test('handle user_ siempre incompleto', () {
    final user = _user();
    final profile = _profile(
      handle: '@user_abc12345',
      displayName: 'Nombre bonito',
    );

    expect(
      isProfileCompleteForOnboarding(user: user, profile: profile),
      isFalse,
    );
  });

  test('registro con handle personalizado pasa aunque nombre corto', () {
    final user = _user(email: 'maria@test.com');
    final profile = _profile(handle: '@maria_ss', displayName: 'María');

    expect(
      isProfileCompleteForOnboarding(user: user, profile: profile),
      isTrue,
    );
  });

  test('copy explica handle genérico y nombre del email', () {
    final user = _user();
    final profile = _profile(handle: '@juan', displayName: 'Juan');
    final copy = buildProfileOnboardingCopy(user: user, profile: profile);

    expect(copy.intro, contains('perfil público'));
    expect(
      copy.hints.any((h) => h.contains('@handle coincide con el email')),
      isTrue,
    );
    expect(
      copy.hints.any((h) => h.contains('nombre visible')),
      isTrue,
    );
  });

  test('copy distingue OAuth en la intro', () {
    final user = User(
      id: '00000000-0000-0000-0000-000000000001',
      appMetadata: const {'provider': 'google'},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: 'juan@gmail.com',
    );
    final profile = _profile(handle: '@juan', displayName: 'Juan');
    final copy = buildProfileOnboardingCopy(user: user, profile: profile);

    expect(copy.intro, contains('Google'));
  });

  test('onboarding_completed en metadata evita pantalla', () {
    final user = User(
      id: '00000000-0000-0000-0000-000000000001',
      appMetadata: const {},
      userMetadata: const {'onboarding_completed': true},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: 'juan@gmail.com',
    );
    final profile = _profile(handle: '@juan', displayName: 'Juan');

    expect(
      needsProfileOnboardingForProfile(user: user, profile: profile),
      isFalse,
    );
  });
}
