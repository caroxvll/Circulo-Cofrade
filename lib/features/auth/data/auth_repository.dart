import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';

class AuthUnavailableException implements Exception {
  const AuthUnavailableException([
    this.message = 'Supabase no está configurado. Añade env.json.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  bool get isAvailable => _client != null;

  Stream<AuthState> get authStateChanges {
    if (_client == null) {
      return Stream.value(
        AuthState(AuthChangeEvent.initialSession, null),
      );
    }
    return _client.auth.onAuthStateChange;
  }

  User? get currentUser => _client?.auth.currentUser;

  Session? get currentSession => _client?.auth.currentSession;

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _ensureAvailable();
    await _client!.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    // Tras confirmar el enlace, el JWT inicial puede no traer email_confirmed_at.
    await syncAuthUser();
    return AuthResponse(
      user: _client!.auth.currentUser,
      session: _client!.auth.currentSession,
    );
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    required String handle,
  }) async {
    _ensureAvailable();
    final normalizedHandle = _normalizeHandle(handle);
    return _client!.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: _emailConfirmationRedirectUrl,
      data: {
        'display_name': displayName.trim(),
        'handle': normalizedHandle,
      },
    );
  }

  Future<void> signInWithGoogle() async {
    _ensureAvailable();
    await _client!.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _oauthRedirectUrl,
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
  }

  Future<void> signInWithApple() async {
    _ensureAvailable();
    await _client!.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: _oauthRedirectUrl,
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
  }

  Future<void> signOut() async {
    if (_client == null) return;
    await _client.auth.signOut();
  }

  Future<void> requestPasswordReset({required String email}) async {
    _ensureAvailable();
    await _client!.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: _passwordRecoveryRedirectUrl,
    );
  }

  Future<void> updatePassword({required String newPassword}) async {
    _ensureAvailable();
    await _client!.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  Future<void> resendSignupConfirmation({required String email}) async {
    _ensureAvailable();
    await _client!.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
      emailRedirectTo: _emailConfirmationRedirectUrl,
    );
  }

  Future<AuthResponse> refreshSession() async {
    _ensureAvailable();
    await _client!.auth.refreshSession();
    await syncAuthUser();
    return AuthResponse(
      user: _client!.auth.currentUser,
      session: _client!.auth.currentSession,
    );
  }

  /// Lee el usuario en el servidor (p. ej. tras confirmar email en otro dispositivo).
  Future<UserResponse> syncAuthUser() async {
    _ensureAvailable();
    return _client!.auth.getUser();
  }

  bool get isEmailVerified {
    final user = currentUser;
    if (user == null) return false;
    return user.emailConfirmedAt != null;
  }

  String get _emailConfirmationRedirectUrl {
    if (kIsWeb) {
      final base = Uri.base;
      return '${base.origin}${base.path}#/verificar-email';
    }
    return 'cofradeo://login-callback';
  }

  String get _passwordRecoveryRedirectUrl {
    if (kIsWeb) {
      final base = Uri.base;
      return '${base.origin}${base.path}#/nueva-contrasena';
    }
    return 'cofradeo://reset-password';
  }

  String _normalizeHandle(String handle) {
    var value = handle.trim().toLowerCase();
    if (value.startsWith('@')) value = value.substring(1);
    return value.replaceAll(RegExp(r'[^a-z0-9_]'), '');
  }

  String? get _oauthRedirectUrl {
    if (kIsWeb) return null;
    return 'cofradeo://login-callback';
  }

  void _ensureAvailable() {
    if (_client == null) throw const AuthUnavailableException();
  }
}

AuthRepository createAuthRepository() {
  return AuthRepository(client: SupabaseBootstrap.client);
}
