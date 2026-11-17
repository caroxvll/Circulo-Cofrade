import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';

class AppleSignInCancelled implements Exception {
  const AppleSignInCancelled();
}

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

  /// Se ejecuta con la sesión todavía abierta. PushScope lo usa para
  /// borrar el token FCM de este dispositivo antes de invalidar el JWT.
  Future<void> Function(String? userId)? beforeSignOut;

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
        'onboarding_completed': true,
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

  /// Hoja nativa de Apple. La sesión queda en la app, sin pasar por el navegador.
  Future<void> signInWithApple() async {
    _ensureAvailable();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      throw const AuthUnavailableException(
        'Continuar con Apple solo está disponible en el iPhone.',
      );
    }

    final rawNonce = _client!.auth.generateRawNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw const AppleSignInCancelled();
      }
      throw AuthException('No se pudo continuar con Apple.');
    }

    final idToken = credential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('Apple no devolvió la sesión.');
    }

    await _client!.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );

    final given = credential.givenName?.trim() ?? '';
    final family = credential.familyName?.trim() ?? '';
    final fullName = [given, family].where((part) => part.isNotEmpty).join(' ');
    if (fullName.length >= 2) {
      final display = fullName.length > 40 ? fullName.substring(0, 40) : fullName;
      try {
        await _client!.auth.updateUser(
          UserAttributes(data: {'display_name': display}),
        );
      } catch (_) {}
    }
  }

  Future<void> signOut() async {
    if (_client == null) return;
    final userId = _client.auth.currentUser?.id;
    final hook = beforeSignOut;
    if (hook != null) {
      try {
        await hook(userId);
      } catch (error, stack) {
        debugPrint(
          'No se pudo desvincular el dispositivo antes de salir: $error\n$stack',
        );
      }
    }
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

  Future<void> markOnboardingCompleted() async {
    _ensureAvailable();
    await _client!.auth.updateUser(
      UserAttributes(
        data: {'onboarding_completed': true},
      ),
    );
    await syncAuthUser();
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

  String get _oauthRedirectUrl {
    if (kIsWeb) {
      final base = Uri.base;
      // PKCE: Supabase devuelve ?code= en la raíz donde corre la app web.
      final path = base.path;
      if (path.isEmpty || path == '/') return base.origin;
      return '${base.origin}$path';
    }
    return 'cofradeo://login-callback';
  }

  void _ensureAvailable() {
    if (_client == null) throw const AuthUnavailableException();
  }
}

AuthRepository createAuthRepository() {
  return AuthRepository(client: SupabaseBootstrap.client);
}
