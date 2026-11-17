import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_bootstrap.dart';

/// La junta ha dejado que esta cuenta proponga eventos al calendario.
/// Si la tabla aún no está en Supabase, responde false.
final isCalendarContributorProvider =
    FutureProvider.family<bool, String>((ref, profileId) async {
  if (profileId.isEmpty) return false;
  final client = SupabaseBootstrap.client;
  if (client == null) return false;

  try {
    final raw = await client.rpc(
      'is_calendar_contributor',
      params: {'p_user_id': profileId},
    );
    return raw == true;
  } catch (_) {
    return false;
  }
});

/// Modera al menos un foro. La lectura de asignaciones es pública.
final moderatesAnyForumProvider =
    FutureProvider.family<bool, String>((ref, profileId) async {
  if (profileId.isEmpty) return false;
  final client = SupabaseBootstrap.client;
  if (client == null) return false;

  try {
    final row = await client
        .from('forum_moderators')
        .select('profile_id')
        .eq('profile_id', profileId)
        .limit(1)
        .maybeSingle();
    return row != null;
  } catch (_) {
    return false;
  }
});
