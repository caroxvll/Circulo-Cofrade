import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import 'data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return createAuthRepository();
});

final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  return authState.maybeWhen(
    data: (state) => state.session?.user,
    orElse: () => ref.read(authRepositoryProvider).currentUser,
  );
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

final isEmailVerifiedProvider = Provider<bool>((ref) {
  if (!ref.watch(authRequiredProvider)) return true;
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  return user.emailConfirmedAt != null;
});

/// Publicar, seguir y acciones sociales requieren email verificado.
final canEngageProvider = Provider<bool>((ref) {
  if (!ref.watch(authRequiredProvider)) return true;
  if (!ref.watch(isAuthenticatedProvider)) return false;
  return ref.watch(isEmailVerifiedProvider);
});

final supabaseReadyProvider = Provider<bool>((ref) {
  return SupabaseConfig.isConfigured && SupabaseBootstrap.isInitialized;
});

/// Con Supabase conectado la app exige sesión; sin credenciales (tests/dev) permite invitado.
final authRequiredProvider = Provider<bool>((ref) {
  return ref.watch(supabaseReadyProvider);
});
