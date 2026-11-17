import 'package:flutter_test/flutter_test.dart';

import 'package:cofradeo/core/utils/forum_markdown_blocks.dart';

void main() {
  test('cada Enter crea un párrafo propio', () {
    const raw = 'Primer párrafo.\nSegundo párrafo.\n\nTercero tras línea en blanco.';
    final blocks = parseForumMarkdownBlocks(raw);

    expect(blocks.length, 3);
    expect(blocks.every((b) => b.kind == ForumMarkdownBlockKind.paragraph), isTrue);
    expect(blocks[0].lines.single, 'Primer párrafo.');
    expect(blocks[1].lines.single, 'Segundo párrafo.');
    expect(blocks[2].lines.single, 'Tercero tras línea en blanco.');
  });

  test('listas y citas siguen agrupadas', () {
    const raw = 'Intro.\n- uno\n- dos\n> cita';
    final blocks = parseForumMarkdownBlocks(raw);

    expect(blocks.map((b) => b.kind).toList(), [
      ForumMarkdownBlockKind.paragraph,
      ForumMarkdownBlockKind.bulletList,
      ForumMarkdownBlockKind.blockquote,
    ]);
    expect(blocks[1].lines, ['uno', 'dos']);
    expect(blocks[2].lines, ['cita']);
  });
}
