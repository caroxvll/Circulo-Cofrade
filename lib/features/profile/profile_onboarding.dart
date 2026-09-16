import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_branding.dart';
import '../auth/auth_provider.dart';
import '../../shared/models/user_profile.dart';
import 'profile_provider.dart';

final _handleRegex = RegExp(r'^[a-z0-9_]{3,20}$');

bool isProfileOnboardingDone(User? user) {
  return user?.userMetadata?['onboarding_completed'] == true;
}

String normalizeProfileHandle(String raw) {
  return raw.replaceFirst('@', '').trim().toLowerCase();
}

String _alphanumericLower(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

/// Handle autogenerado (trigger/email) sin personalizar.
bool isGenericProfileHandle({
  required String handle,
  required String? emailLocal,
}) {
  if (handle.startsWith('user_')) return true;
  final handleNorm = _alphanumericLower(handle);
  final emailNorm = emailLocal == null ? '' : _alphanumericLower(emailLocal);
  return emailNorm.isNotEmpty && handleNorm == emailNorm;
}

/// Nombre que sigue siendo el email o el handle sin elegir.
bool isGenericProfileDisplayName({
  required String displayName,
  required String handle,
  required String? emailLocal,
}) {
  final display = displayName.trim().toLowerCase();
  if (display.isEmpty) return true;

  final handleNorm = _alphanumericLower(handle);
  final emailNorm = emailLocal == null ? '' : _alphanumericLower(emailLocal);

  if (emailLocal != null && display == emailLocal.toLowerCase()) return true;
  if (display == handle) return true;
  if (emailNorm.isNotEmpty && display == emailNorm) return true;
  if (handleNorm.isNotEmpty && display == handleNorm) return true;
  return false;
}

/// Perfil listo para usar la app sin pasar por «Completar perfil».
bool isProfileCompleteForOnboarding({
  required User? user,
  required UserProfile? profile,
}) {
  if (user == null || profile == null) return false;

  final handle = normalizeProfileHandle(profile.handle);
  final display = profile.displayName.trim();
  final emailLocal = user.email?.split('@').first.toLowerCase();

  if (!_handleRegex.hasMatch(handle)) return false;
  if (handle.startsWith('user_')) return false;
  if (display.length < 2 || display.length > 40) return false;

  final genericHandle = isGenericProfileHandle(
    handle: handle,
    emailLocal: emailLocal,
  );
  final genericDisplay = isGenericProfileDisplayName(
    displayName: display,
    handle: handle,
    emailLocal: emailLocal,
  );

  // Basta con que handle o nombre estén claramente personalizados.
  return !genericHandle || !genericDisplay;
}

/// Textos para explicar en pantalla por qué hace falta completar el perfil.
ProfileOnboardingCopy buildProfileOnboardingCopy({
  required User? user,
  required UserProfile? profile,
}) {
  if (user == null || profile == null) {
    return const ProfileOnboardingCopy(
      intro:
          'Antes de entrar, confirma cómo quieres aparecer en la comunidad.',
      hints: [],
    );
  }

  final handle = normalizeProfileHandle(profile.handle);
  final display = profile.displayName.trim();
  final emailLocal = user.email?.split('@').first.toLowerCase();
  final oauth = _isOAuthSignup(user);

  final genericHandle = isGenericProfileHandle(
    handle: handle,
    emailLocal: emailLocal,
  );
  final genericDisplay = isGenericProfileDisplayName(
    displayName: display,
    handle: handle,
    emailLocal: emailLocal,
  );
  final invalidHandle =
      !_handleRegex.hasMatch(handle) || handle.startsWith('user_');
  final invalidDisplay = display.length < 2 || display.length > 40;

  final hints = <String>[];

  if (invalidHandle || genericHandle) {
    if (handle.startsWith('user_')) {
      hints.add(
        'Tu @handle es temporal. Elige uno único (3–20 caracteres) para '
        'menciones, búsquedas y tu perfil público.',
      );
    } else if (!_handleRegex.hasMatch(handle)) {
      hints.add(
        'Tu @handle debe tener entre 3 y 20 caracteres (solo a-z, 0-9 y _).',
      );
    } else {
      hints.add(
        'Tu @handle coincide con el email. Elige otro para que te encuentren '
        'en foros sin confundirte con el correo.',
      );
    }
  }

  if (invalidDisplay || genericDisplay) {
    hints.add(
      'El nombre visible es cómo te verán en publicaciones y comentarios. '
      'Evita dejar solo la parte del email.',
    );
  }

  if (hints.isEmpty) {
    hints.add(
      'Revisa que nombre y @handle te representen antes de participar.',
    );
  }

  hints.add(
    'La bio es opcional; puedes completarla ahora o más tarde en tu perfil.',
  );

  final intro = oauth
      ? 'Hemos traído datos de tu cuenta de Google o Apple. '
          'Solo falta ajustar lo que aún está genérico para usar ${AppBranding.name}.'
      : 'Tu cuenta está creada, pero el perfil público aún no está listo. '
          'Personaliza nombre y @handle para participar en foros y que te reconozcan.';

  return ProfileOnboardingCopy(intro: intro, hints: hints);
}

bool _isOAuthSignup(User user) {
  final provider = user.appMetadata['provider'];
  if (provider == 'google' || provider == 'apple') return true;
  return user.identities?.any(
        (identity) =>
            identity.provider == 'google' || identity.provider == 'apple',
      ) ??
      false;
}

class ProfileOnboardingCopy {
  const ProfileOnboardingCopy({
    required this.intro,
    required this.hints,
  });

  final String intro;
  final List<String> hints;
}

bool needsProfileOnboardingForProfile({
  required User? user,
  required UserProfile? profile,
}) {
  if (user == null || profile == null) return false;
  if (isProfileOnboardingDone(user)) return false;
  return !isProfileCompleteForOnboarding(user: user, profile: profile);
}

Future<void> syncProfileOnboardingCompletedIfNeeded(Ref ref) async {
  if (!ref.read(authRequiredProvider)) return;

  final user = ref.read(currentUserProvider);
  if (user == null || isProfileOnboardingDone(user)) return;

  final profile = ref.read(currentUserProfileProvider).asData?.value ??
      await ref.read(currentUserProfileProvider.future);

  if (!isProfileCompleteForOnboarding(user: user, profile: profile)) return;

  await ref.read(authRepositoryProvider).markOnboardingCompleted();
}

Future<void> syncProfileOnboardingCompletedIfNeededWidget(WidgetRef ref) async {
  if (!ref.read(authRequiredProvider)) return;

  final user = ref.read(currentUserProvider);
  if (user == null || isProfileOnboardingDone(user)) return;

  final profile = ref.read(currentUserProfileProvider).asData?.value ??
      await ref.read(currentUserProfileProvider.future);

  if (!isProfileCompleteForOnboarding(user: user, profile: profile)) return;

  await ref.read(authRepositoryProvider).markOnboardingCompleted();
}

/// Perfil pendiente de revisión (p. ej. primer login con Google).
Future<bool> needsProfileOnboarding(Ref ref) async {
  if (!ref.read(authRequiredProvider)) return false;

  final user = ref.read(currentUserProvider);
  if (user == null) return false;

  final profile = ref.read(currentUserProfileProvider).asData?.value ??
      await ref.read(currentUserProfileProvider.future);

  if (isProfileOnboardingDone(user)) return false;

  if (isProfileCompleteForOnboarding(user: user, profile: profile)) {
    await syncProfileOnboardingCompletedIfNeeded(ref);
    return false;
  }

  return true;
}

/// Variante para pantallas con [WidgetRef].
Future<bool> needsProfileOnboardingWidget(WidgetRef ref) async {
  if (!ref.read(authRequiredProvider)) return false;

  final user = ref.read(currentUserProvider);
  if (user == null) return false;

  final profile = ref.read(currentUserProfileProvider).asData?.value ??
      await ref.read(currentUserProfileProvider.future);

  if (isProfileOnboardingDone(user)) return false;

  if (isProfileCompleteForOnboarding(user: user, profile: profile)) {
    await syncProfileOnboardingCompletedIfNeededWidget(ref);
    return false;
  }

  return true;
}
