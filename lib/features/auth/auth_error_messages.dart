import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Mensaje legible en español para errores de Supabase Auth.
String friendlyAuthErrorMessage(AuthException error) {
  final code = error.code?.trim().toLowerCase();
  if (code != null && code.isNotEmpty) {
    final byCode = _messageForAuthCode(code);
    if (byCode != null) return byCode;
  }
  return translateErrorMessage(error.message);
}

/// Traduce mensajes crudos de API (auth, PostgREST, red…) al español.
String translateErrorMessage(String? raw) {
  final text = _normalizeRawMessage(raw);
  if (text.isEmpty) {
    return 'No se pudo completar la operación. Inténtalo de nuevo.';
  }

  final lower = text.toLowerCase();

  if (lower.contains('error sending confirmation email') ||
      lower.contains('unexpected_failure')) {
    return 'No pudimos enviar el email de confirmación. '
        'Si usas Resend con onboarding@resend.dev, solo llega al email '
        'de tu cuenta Resend; verifica un dominio para enviar a cualquiera.';
  }

  if (lower.contains('error sending recovery email') ||
      lower.contains('error sending email')) {
    return 'No pudimos enviar el email. Revisa SMTP en Supabase y Resend.';
  }

  if (lower.contains('user already registered') ||
      lower.contains('user already exists') ||
      lower.contains('already been registered')) {
    return 'Ya existe una cuenta con ese email.';
  }

  if (lower.contains('email not confirmed') ||
      lower.contains('email_not_confirmed')) {
    return 'Confirma tu email antes de iniciar sesión.';
  }

  if (lower.contains('invalid login credentials') ||
      lower.contains('invalid_credentials') ||
      lower.contains('invalid email or password') ||
      lower.contains('user not found') ||
      lower.contains('no user found') ||
      lower.contains('email not found') ||
      lower.contains('account not found')) {
    return 'Email o contraseña incorrectos.';
  }

  if (lower.contains('unable to validate email') ||
      lower.contains('email address is invalid') ||
      lower.contains('invalid email') ||
      lower.contains('email_address_invalid')) {
    return 'Introduce un email válido.';
  }

  if (lower.contains('password should be at least') ||
      lower.contains('weak_password') ||
      lower.contains('password is too short')) {
    final match = RegExp(r'at least (\d+)').firstMatch(lower);
    final min = match?.group(1);
    if (min != null) {
      return 'La contraseña debe tener al menos $min caracteres.';
    }
    return 'La contraseña es demasiado corta.';
  }

  if (lower.contains('signup requires a valid password') ||
      lower.contains('password is known to be weak') ||
      lower.contains('easy to guess')) {
    return 'Elige una contraseña más segura (mínimo 8 caracteres).';
  }

  if (lower.contains('new password should be different') ||
      lower.contains('same_password')) {
    return 'La nueva contraseña debe ser distinta a la anterior.';
  }

  if (lower.contains('email link is invalid') ||
      lower.contains('has expired') ||
      lower.contains('otp_expired') ||
      lower.contains('token has expired') ||
      lower.contains('invalid otp') ||
      lower.contains('link is invalid')) {
    return 'El enlace ha expirado o no es válido. Solicita uno nuevo.';
  }

  if (lower.contains('for security purposes') ||
      lower.contains('rate limit') ||
      lower.contains('over_email_send_rate') ||
      lower.contains('over_request_rate') ||
      lower.contains('too many requests') ||
      lower.contains('email rate limit')) {
    return 'Demasiados intentos. Espera un momento y vuelve a probar.';
  }

  if (lower.contains('auth session missing') ||
      lower.contains('session_not_found') ||
      lower.contains('refresh token not found') ||
      lower.contains('refresh_token_not_found') ||
      lower.contains('invalid refresh token') ||
      lower.contains('jwt expired') ||
      lower.contains('access token expired')) {
    return 'Tu sesión ha caducado. Vuelve a iniciar sesión.';
  }

  if (lower.contains('database error saving new user') ||
      lower.contains('error saving user')) {
    return 'No se pudo crear el perfil. Prueba otro handle o inténtalo más tarde.';
  }

  if (lower.contains('duplicate key') ||
      lower.contains('unique constraint') ||
      lower.contains('profiles_handle') ||
      lower.contains('handle_key')) {
    return 'Ese handle ya está en uso. Elige otro.';
  }

  if (lower.contains('signups not allowed') ||
      lower.contains('signup_disabled')) {
    return 'El registro no está disponible en este momento.';
  }

  if (lower.contains('provider not enabled') ||
      lower.contains('provider_disabled') ||
      lower.contains('unsupported provider')) {
    return 'Este método de acceso no está habilitado.';
  }

  if (lower.contains('identity already exists') ||
      lower.contains('identity_already_exists')) {
    return 'Ya tienes una cuenta vinculada con ese proveedor.';
  }

  if (lower.contains('user is banned') || lower.contains('user_banned')) {
    return 'Tu cuenta está suspendida. Contacta con soporte.';
  }

  if (lower.contains('captcha')) {
    return 'No se pudo completar la verificación. Inténtalo de nuevo.';
  }

  if (lower.contains('anonymous sign-ins are disabled')) {
    return 'Inicia sesión con tu cuenta.';
  }

  if (lower.contains('network') ||
      lower.contains('socket') ||
      lower.contains('connection') ||
      lower.contains('failed host lookup')) {
    return 'Comprueba tu conexión e inténtalo de nuevo.';
  }

  if (lower.contains('row-level security') ||
      lower.contains('permission denied') ||
      lower.contains('not authorized')) {
    return 'No tienes permiso para esta acción.';
  }

  if (text.startsWith('{') && text.contains('"message"')) {
    return 'No se pudo completar la operación. Inténtalo de nuevo.';
  }

  // Si sigue en inglés típico de API, mensaje genérico en lugar del crudo.
  if (_looksLikeEnglishApiMessage(text)) {
    return 'No se pudo completar la operación. Inténtalo de nuevo.';
  }

  return text;
}

String? _messageForAuthCode(String code) {
  return switch (code) {
    'invalid_credentials' => 'Email o contraseña incorrectos.',
    'email_not_confirmed' => 'Confirma tu email antes de iniciar sesión.',
    'user_already_exists' || 'user_already_registered' =>
      'Ya existe una cuenta con ese email.',
    'email_address_invalid' || 'validation_failed' =>
      'Introduce un email válido.',
    'weak_password' => 'Elige una contraseña más segura (mínimo 8 caracteres).',
    'same_password' => 'La nueva contraseña debe ser distinta a la anterior.',
    'otp_expired' || 'flow_state_expired' || 'flow_state_not_found' =>
      'El enlace ha expirado o no es válido. Solicita uno nuevo.',
    'over_email_send_rate_limit' ||
    'over_request_rate_limit' ||
    'over_sms_send_rate_limit' =>
      'Demasiados intentos. Espera un momento y vuelve a probar.',
    'session_not_found' ||
    'refresh_token_not_found' ||
    'refresh_token_already_used' =>
      'Tu sesión ha caducado. Vuelve a iniciar sesión.',
    'signup_disabled' => 'El registro no está disponible en este momento.',
    'provider_disabled' => 'Este método de acceso no está habilitado.',
    'identity_already_exists' =>
      'Ya tienes una cuenta vinculada con ese proveedor.',
    'user_banned' => 'Tu cuenta está suspendida. Contacta con soporte.',
    'captcha_failed' => 'No se pudo completar la verificación. Inténtalo de nuevo.',
    _ => null,
  };
}

String _normalizeRawMessage(String? raw) {
  final trimmed = raw?.trim() ?? '';
  if (trimmed.isEmpty) return '';

  if (trimmed.startsWith('{')) {
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        for (final key in ['msg', 'message', 'error_description', 'error']) {
          final value = decoded[key];
          if (value is String && value.trim().isNotEmpty) {
            return value.trim();
          }
        }
        final code = decoded['error_code'];
        if (code is String) {
          final byCode = _messageForAuthCode(code.toLowerCase());
          if (byCode != null) return byCode;
        }
      }
    } catch (_) {
      // Mantener el texto original.
    }
  }

  return trimmed;
}

bool _looksLikeEnglishApiMessage(String text) {
  final lower = text.toLowerCase();
  const hints = [
    'invalid',
    'error',
    'failed',
    'not found',
    'unauthorized',
    'forbidden',
    'required',
    'must be',
    'cannot',
    "can't",
    'please',
    'wrong',
    'incorrect',
    'expired',
    'denied',
  ];
  return hints.any(lower.contains);
}
