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
    final raw = await client.rpc(
      'is_news_publisher',
      params: {'p_user_id': profileId},
    );
    return raw == true;
  } catch (_) {
    return false;
  }
});
