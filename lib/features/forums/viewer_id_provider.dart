import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_provider.dart';

/// Identificador estable para contar visitas: `user.id` o `anon:…` por sesión.
final viewerIdProvider = Provider<String>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user != null) return user.id;
  return ref.watch(anonymousViewerIdProvider);
});

final anonymousViewerIdProvider =
    NotifierProvider<AnonymousViewerIdNotifier, String>(
  AnonymousViewerIdNotifier.new,
);

class AnonymousViewerIdNotifier extends Notifier<String> {
  @override
  String build() => 'anon-${_randomId()}';
}

String _randomId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
