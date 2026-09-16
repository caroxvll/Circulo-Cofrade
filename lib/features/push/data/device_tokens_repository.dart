import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';

class DeviceTokensRepository {
  DeviceTokensRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  bool get isAvailable => _client != null;

  Future<void> upsert({
    required String userId,
    required String fcmToken,
    required String platform,
  }) async {
    if (_client == null) return;

    try {
      // Un token = un usuario (quita el mismo FCM de otras cuentas).
      await _client!.rpc(
        'claim_device_token',
        params: {
          'p_fcm_token': fcmToken,
          'p_platform': platform,
        },
      );
      return;
    } catch (_) {
      // Fallback si aún no ejecutaron device_tokens_unique.sql
    }

    await _client!
        .from('device_tokens')
        .delete()
        .eq('user_id', userId)
        .eq('platform', platform);

    await _client!.from('device_tokens').upsert({
      'user_id': userId,
      'fcm_token': fcmToken,
      'platform': platform,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,fcm_token');
  }

  Future<void> delete({
    required String userId,
    required String fcmToken,
  }) async {
    if (_client == null) return;

    await _client!
        .from('device_tokens')
        .delete()
        .eq('user_id', userId)
        .eq('fcm_token', fcmToken);
  }
}

DeviceTokensRepository createDeviceTokensRepository() {
  return DeviceTokensRepository(client: SupabaseBootstrap.client);
}
