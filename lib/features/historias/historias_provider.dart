import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import '../auth/auth_provider.dart';
import '../profile/profile_provider.dart';
import 'data/historias_repository.dart';
import 'models/historia.dart';

export 'data/historias_repository.dart' show historiasHubConfigKey;

final historiasRepositoryProvider = Provider<HistoriasRepository>((ref) {
  return HistoriasRepository(client: SupabaseBootstrap.client);
});

/// `on` muestra la pestaña Historias en Comunidad. Cualquier otro valor la oculta.
final historiasHubEnabledProvider = FutureProvider<bool>((ref) async {
  return ref.watch(historiasRepositoryProvider).isHubEnabled();
});

final publishedHistoriasProvider = FutureProvider<List<Historia>>((ref) {
  return ref.watch(historiasRepositoryProvider).fetchPublished();
});

final staffHistoriasProvider = FutureProvider<List<Historia>>((ref) {
  return ref.watch(historiasRepositoryProvider).fetchAllForStaff();
});

final historiaByIdProvider =
    FutureProvider.family<Historia?, String>((ref, id) {
  return ref.watch(historiasRepositoryProvider).fetchById(id);
});

final historiaCommentsProvider =
    FutureProvider.family<List<HistoriaComment>, String>((ref, historiaId) {
  return ref.watch(historiasRepositoryProvider).fetchComments(historiaId);
});

final canPublishHistoriasProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  final profile = ref.watch(currentUserProfileProvider).asData?.value;
  return profile?.isChronicler == true && profile?.isSuspended != true;
});
