enum HistoriaKind {
  libro,
  articulo;

  static HistoriaKind fromDb(String? raw) => switch (raw) {
        'libro' => HistoriaKind.libro,
        _ => HistoriaKind.articulo,
      };

  String get dbValue => name;

  String get label => switch (this) {
        HistoriaKind.libro => 'Libro',
        HistoriaKind.articulo => 'Artículo',
      };

  String get blurb => switch (this) {
        HistoriaKind.libro =>
          'Un relato largo. Varias páginas, se lee como un libro.',
        HistoriaKind.articulo =>
          'Una pieza más corta: un tema, un momento, lo que ocurrió.',
      };

  String get composeTitle => switch (this) {
        HistoriaKind.libro => 'Nuevo libro',
        HistoriaKind.articulo => 'Nuevo artículo',
      };

  String get publishLabel => switch (this) {
        HistoriaKind.libro => 'Publicar libro',
        HistoriaKind.articulo => 'Publicar artículo',
      };
}

class HistoriaPage {
  const HistoriaPage({
    this.body = '',
    this.imageUrl,
    this.caption,
  });

  final String body;
  final String? imageUrl;
  final String? caption;

  bool get hasText => body.trim().isNotEmpty;
  bool get hasImage => (imageUrl ?? '').trim().isNotEmpty;
  bool get isEmpty => !hasText && !hasImage;

  Map<String, dynamic> toJson() => {
        'body': body.trim(),
        if (hasImage) 'image_url': imageUrl!.trim(),
        if ((caption ?? '').trim().isNotEmpty) 'caption': caption!.trim(),
      };

  static List<HistoriaPage> parseList(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map(parse)
        .where((page) => !page.isEmpty)
        .toList(growable: false);
  }

  static HistoriaPage parse(Object? raw) {
    if (raw is String) return HistoriaPage(body: raw);
    if (raw is Map) {
      return HistoriaPage(
        body: (raw['body'] ?? raw['text'] ?? '').toString(),
        imageUrl: raw['image_url'] as String?,
        caption: raw['caption'] as String?,
      );
    }
    return HistoriaPage(body: raw?.toString() ?? '');
  }
}

class Historia {
  const Historia({
    required this.id,
    required this.authorId,
    required this.authorHandle,
    required this.authorDisplayName,
    required this.title,
    required this.excerpt,
    required this.pages,
    required this.commentCount,
    required this.createdAt,
    this.kind = HistoriaKind.articulo,
    this.authorAvatarUrl,
    this.coverImageUrl,
    this.status = 'published',
  });

  final String id;
  final String authorId;
  final String authorHandle;
  final String authorDisplayName;
  final String? authorAvatarUrl;
  final String title;
  final String excerpt;
  final HistoriaKind kind;
  final String? coverImageUrl;
  final List<HistoriaPage> pages;
  final String status;
  final int commentCount;
  final DateTime createdAt;

  int get pageCount => pages.length;

  bool get isPublished => status == 'published';
  bool get isDraft => status == 'draft';

  String get atHandle {
    final raw = authorHandle.trim();
    if (raw.isEmpty) return '@cofrade';
    return raw.startsWith('@') ? raw : '@$raw';
  }
}

class HistoriaComment {
  const HistoriaComment({
    required this.id,
    required this.historiaId,
    required this.userId,
    required this.userHandle,
    required this.userDisplayName,
    required this.body,
    required this.createdAt,
    this.userAvatarUrl,
  });

  final String id;
  final String historiaId;
  final String userId;
  final String userHandle;
  final String userDisplayName;
  final String? userAvatarUrl;
  final String body;
  final DateTime createdAt;
}
