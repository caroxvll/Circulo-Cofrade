import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_bootstrap.dart';

/// La junta ha dado a esta cuenta permiso para publicar noticias.
/// Si la tabla aún no está en Supabase, responde false.
final isNewsPublisherProvider =
    FutureProvider.family<bool, String>((ref, profileId) async {
  if (profileId.isEmpty) return false;
  final client = SupabaseBootstrap.client;
  if (client == null) return false;

  try {
    final row = await client
        .from('news_publishers')
        .select('profile_id')
        .eq('profile_id', profileId)
        .maybeSingle();
    return row != null;
  } catch (_) {
    return false;
  }
});
