import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_provider.dart';

/// Bloquea acciones sociales si el email no está verificado.
Future<bool> ensureEmailVerifiedForEngage(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!ref.read(authRequiredProvider)) return true;
  if (!ref.read(isAuthenticatedProvider)) return false;
  if (ref.read(isEmailVerifiedProvider)) return true;

  if (!context.mounted) return false;
  await context.push('/verificar-email');
  return ref.read(isEmailVerifiedProvider);
}
