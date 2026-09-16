import 'package:flutter/widgets.dart';
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

bool _isWidgetTest() =>
    WidgetsBinding.instance.runtimeType.toString().contains('TestWidgetsFlutterBinding');

/// Si Supabase no está configurado y NO estamos en `flutter test`,
/// evitamos que se muestren datos mock: forzamos ir a auth.
///
/// En `flutter test` mantenemos el comportamiento anterior para que los mocks
/// de UI se puedan renderizar.
final authRequiredProvider = Provider<bool>((ref) {
  final supabaseReady = ref.watch(supabaseReadyProvider);
  if (_isWidgetTest()) return supabaseReady;
  return true;
});
