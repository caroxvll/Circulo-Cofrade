import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/safe_redirect.dart';
import '../profile/profile_onboarding.dart';
import 'auth_provider.dart';

/// Tras login/registro: calendario, redirect o verificación de email pendiente.
Future<void> goAfterAuthenticated(
  BuildContext context,
  WidgetRef ref, {
  String? redirect,
}) async {
  if (ref.read(authRequiredProvider) && !ref.read(isEmailVerifiedProvider)) {
    final email = ref.read(currentUserProvider)?.email;
    final params = <String, String>{
      if (email != null && email.isNotEmpty) 'email': email,
      if (safeInternalLocation(redirect) != null) 'redirect': redirect!,
    };
    final query = params.isEmpty ? '' : '?${Uri(queryParameters: params).query}';
    context.go('/verificar-email$query');
    return;
  }

  if (!context.mounted) return;

  if (await needsProfileOnboardingWidget(ref)) {
    if (!context.mounted) return;
    final safe = safeInternalLocation(redirect);
    final query = safe != null ? '?redirect=${Uri.encodeComponent(safe)}' : '';
    context.go('/completar-perfil$query');
    return;
  }

  if (!context.mounted) return;
  final safe = safeInternalLocation(redirect);
  if (safe != null) {
    context.go(safe);
  } else {
    context.go('/calendario');
  }
}

String verifyEmailPathForUser(WidgetRef ref) {
  final email = ref.read(currentUserProvider)?.email;
  if (email == null) return '/verificar-email';
  return '/verificar-email?email=${Uri.encodeComponent(email)}';
}
