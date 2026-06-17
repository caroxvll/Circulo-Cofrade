import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

abstract final class SupabaseBootstrap {
  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static Future<void> initialize() async {
    if (!SupabaseConfig.isConfigured) return;
    if (_initialized) return;

    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey, // ignore: deprecated_member_use
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        // Recupera sesión al volver desde el enlace del correo (web) u OAuth.
        detectSessionInUri: true,
        autoRefreshToken: true,
      ),
    );
    _initialized = true;
  }

  static SupabaseClient? get client {
    if (!_initialized) return null;
    return Supabase.instance.client;
  }
}
