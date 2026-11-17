import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_bootstrap.dart';

/// `on` muestra el directorio de «Tu hermandad». Cualquier otro valor, o la
/// ausencia de la clave, lo deja en «Próximamente».
const profileHermandadFollowingConfigKey = 'profile_hermandad_following';

final hermandadFollowingEnabledProvider = FutureProvider<bool>((ref) async {
  final client = SupabaseBootstrap.client;
  if (client == null) return false;

  try {
    final row = await client
        .from('app_config')
        .select('value')
        .eq('key', profileHermandadFollowingConfigKey)
        .maybeSingle();
    return (row?['value'] as String?)?.trim() == 'on';
  } catch (_) {
    return false;
  }
});
