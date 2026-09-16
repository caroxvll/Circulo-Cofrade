import 'package:cofradeo/features/forums/utils/reply_reactions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('replyReactionDisplay convierte ids legacy', () {
    expect(replyReactionDisplay('heart'), '❤️');
    expect(replyReactionDisplay('thanks'), '🤗');
    expect(replyReactionDisplay('🫶'), '🤗');
    expect(replyReactionDisplay('🙏'), '🙏');
  });

  test('normalizeReactionCounts agrupa ids y emoji', () {
    expect(
      normalizeReactionCounts({'heart': 1, '❤️': 2, 'pray': 1}),
      {'❤️': 3, '🙏': 1},
    );
  });

  test('quickReplyReactions son intuitivas y etiquetadas', () {
    expect(
      quickReplyReactions.map((r) => r.emoji).toList(),
      ['❤️', '👏', '🤗', '😢', '👎'],
    );
    expect(reactionLabel('❤️'), 'Me gusta');
    expect(reactionLabel('🤗'), 'Gracias');
    expect(reactionLabel('👎'), 'No me gusta');
  });

  test('sumReplyReactionTotals agrega reacciones del tablón', () {
    expect(
      sumReplyReactionTotals(
        {
          'a': {'❤️': 2},
          'b': {'👏': 1, '🤗': 1},
        },
        ['a', 'b'],
      ),
      4,
    );
  });

  test('mergeReactionCounts suma desglose del tablón', () {
    expect(
      mergeReactionCounts([
        {'❤️': 2},
        {'❤️': 1, '👏': 1},
      ]),
      {'❤️': 3, '👏': 1},
    );
  });
}
