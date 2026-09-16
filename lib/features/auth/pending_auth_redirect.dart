import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ruta a la que volver tras OAuth (Google/Apple) en móvil.
final pendingAuthRedirectProvider =
    NotifierProvider<PendingAuthRedirectNotifier, String?>(
  PendingAuthRedirectNotifier.new,
);

class PendingAuthRedirectNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? redirect) => state = redirect;

  String? take() {
    final value = state;
    state = null;
    return value;
  }
}
