/// Reacción rápida bajo un comentario (emoji + etiqueta clara).
class QuickReplyReaction {
  const QuickReplyReaction(this.emoji, this.label);

  final String emoji;
  final String label;
}

/// Catálogo completo (ids legacy + emojis antiguos).
class ReplyReactionOption {
  const ReplyReactionOption(this.id, this.emoji, this.label);

  final String id;
  final String emoji;
  final String label;
}

const replyReactionOptions = [
  ReplyReactionOption('heart', '❤️', 'Me gusta'),
  ReplyReactionOption('clap', '👏', 'Aplauso'),
  ReplyReactionOption('thanks', '🤗', 'Gracias'),
  ReplyReactionOption('pray', '🙏', 'Apoyo'),
  ReplyReactionOption('moved', '😢', 'Emoción'),
  ReplyReactionOption('dislike', '👎', 'No me gusta'),
  // Legacy
  ReplyReactionOption('cross', '✝️', 'Recuerdo'),
  ReplyReactionOption('candle', '🕯️', 'Recuerdo'),
  ReplyReactionOption('amen', '✨', 'Amén'),
];

/// Cinco reacciones intuitivas (estilo redes sociales + tono cofrade).
const quickReplyReactions = [
  QuickReplyReaction('❤️', 'Me gusta'),
  QuickReplyReaction('👏', 'Aplauso'),
  QuickReplyReaction('🤗', 'Gracias'),
  QuickReplyReaction('😢', 'Emoción'),
  QuickReplyReaction('👎', 'No me gusta'),
];

ReplyReactionOption? replyReactionById(String? id) {
  if (id == null) return null;
  for (final option in replyReactionOptions) {
    if (option.id == id) return option;
  }
  return null;
}

ReplyReactionOption? replyReactionByEmoji(String emoji) {
  for (final quick in quickReplyReactions) {
    if (quick.emoji == emoji) {
      return ReplyReactionOption(emoji, emoji, quick.label);
    }
  }
  for (final option in replyReactionOptions) {
    if (option.emoji == emoji) return option;
  }
  return null;
}

String reactionLabel(String? value) {
  if (value == null || value.isEmpty) return '';
  return replyReactionById(value)?.label ??
      replyReactionByEmoji(value)?.label ??
      value;
}

/// Normaliza emojis legacy / poco soportados al icono visible actual.
String canonicalReactionEmoji(String emoji) {
  return switch (emoji) {
    '🫶' => '🤗',
    _ => emoji,
  };
}

/// Emoji visible para un valor guardado (id legacy o emoji).
String replyReactionDisplay(String? value) {
  if (value == null || value.isEmpty) return '🙂';
  final resolved = replyReactionById(value)?.emoji ?? value;
  return canonicalReactionEmoji(resolved);
}

bool reactionsEqual(String? a, String? b) {
  if (a == null || b == null) return a == b;
  return replyReactionDisplay(a) == replyReactionDisplay(b);
}

Map<String, int> normalizeReactionCounts(Map<String, int> raw) {
  final out = <String, int>{};
  for (final entry in raw.entries) {
    if (entry.value <= 0) continue;
    final key = replyReactionDisplay(entry.key);
    out[key] = (out[key] ?? 0) + entry.value;
  }
  return out;
}

int totalReactionCount(Map<String, int> counts) {
  return counts.values.fold(0, (sum, n) => sum + n);
}

/// Fusiona contadores de varias respuestas (desglose del tablón).
Map<String, int> mergeReactionCounts(Iterable<Map<String, int>> sources) {
  final out = <String, int>{};
  for (final source in sources) {
    for (final entry in normalizeReactionCounts(source).entries) {
      out[entry.key] = (out[entry.key] ?? 0) + entry.value;
    }
  }
  return out;
}

/// Suma reacciones de varias respuestas (p. ej. tablón oficial).
int sumReplyReactionTotals(
  Map<String, Map<String, int>> countsByReplyId,
  Iterable<String> replyIds,
) {
  return totalReactionCount(
    mergeReactionCounts(
      replyIds.map((id) => countsByReplyId[id.toLowerCase()] ?? const {}),
    ),
  );
}

List<MapEntry<String, int>> sortedReactionCounts(Map<String, int> counts) {
  final order = quickReplyReactions.map((r) => r.emoji).toList();
  final entries = counts.entries.where((e) => e.value > 0).toList();
  entries.sort((a, b) {
    final byCount = b.value.compareTo(a.value);
    if (byCount != 0) return byCount;
    final ai = order.indexOf(a.key);
    final bi = order.indexOf(b.key);
    if (ai >= 0 && bi >= 0) return ai.compareTo(bi);
    return a.key.compareTo(b.key);
  });
  return entries;
}
