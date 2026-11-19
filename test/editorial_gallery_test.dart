import 'package:cofradeo/shared/models/forum.dart';
import 'package:flutter_test/flutter_test.dart';

ForumTopic _topic({
  String? cover,
  List<String> gallery = const [],
}) {
  return ForumTopic(
    id: 'editorial-1',
    forumId: 'foro-cofradiero',
    title: 'Título',
    excerpt: 'extracto',
    body: 'cuerpo',
    authorHandle: '@cofradeo',
    timeAgo: 'ahora',
    commentCount: 0,
    viewCount: 0,
    isEditorial: true,
    coverImageUrl: cover,
    galleryImageUrls: gallery,
  );
}

void main() {
  test('la portada va delante y no se repite', () {
    final urls = _topic(
      cover: 'https://cdn/cover.jpg',
      gallery: [
        'https://cdn/cover.jpg',
        ' https://cdn/dos.jpg ',
        '',
      ],
    ).editorialImageUrls;

    expect(urls, [
      'https://cdn/cover.jpg',
      'https://cdn/dos.jpg',
    ]);
  });

  test('un asset de portada no entra en el montón', () {
    final urls = _topic(
      cover: 'assets/icon.png',
      gallery: ['https://cdn/dos.jpg'],
    ).editorialImageUrls;

    expect(urls, ['https://cdn/dos.jpg']);
  });

  test('parsea el array de postgres y ignora lo que no es texto', () {
    expect(
      parseGalleryImageUrls([' https://a ', '', 3, 'https://b']),
      ['https://a', 'https://b'],
    );
    expect(parseGalleryImageUrls(null), isEmpty);
  });
}
