import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_provider.dart';

const _anonViewerPrefsKey = 'cofradeo_anon_viewer_id';

/// Semilla cargada en [main] antes de [runApp] para no regenerar el anónimo.
String? _seededAnonymousViewerId;

/// Persiste / restaura el viewer anónimo (dedupe de impresiones y clics).
Future<void> ensureAnonymousViewerIdReady() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_anonViewerPrefsKey)?.trim();
  if (saved != null && saved.isNotEmpty) {
    _seededAnonymousViewerId = saved;
    return;
  }
  final created = 'anon-${_randomId()}';
  await prefs.setString(_anonViewerPrefsKey, created);
  _seededAnonymousViewerId = created;
}

/// Identificador estable para contar visitas: `user.id` o `anon:…` persistido.
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
  String build() {
    final seeded = _seededAnonymousViewerId;
    if (seeded != null && seeded.isNotEmpty) return seeded;

    final created = 'anon-${_randomId()}';
    Future(() async {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_anonViewerPrefsKey)?.trim();
      if (saved != null && saved.isNotEmpty) {
        _seededAnonymousViewerId = saved;
        state = saved;
        return;
      }
      await prefs.setString(_anonViewerPrefsKey, created);
      _seededAnonymousViewerId = created;
    });
    return created;
  }
}

String _randomId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
