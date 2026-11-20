import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/historia_reading_progress.dart';

class HistoriaReadingStore {
  static const _prefix = 'cronicon_reading_';

  String _key(String userId) => '$_prefix$userId';

  Future<Map<String, HistoriaReadingMark>> loadAll(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <String, HistoriaReadingMark>{};
      for (final entry in decoded.entries) {
        final mark = HistoriaReadingMark.tryParse(entry.key.toString(), entry.value);
        if (mark != null) out[mark.historiaId] = mark;
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<HistoriaReadingMark?> load(String userId, String historiaId) async {
    final all = await loadAll(userId);
    return all[historiaId];
  }

  Future<void> save(String userId, HistoriaReadingMark mark) async {
    final all = await loadAll(userId);
    if (mark.isInProgress) {
      all[mark.historiaId] = mark;
    } else {
      all.remove(mark.historiaId);
    }
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode({
      for (final entry in all.entries) entry.key: entry.value.toJson(),
    });
    await prefs.setString(_key(userId), encoded);
  }
}
