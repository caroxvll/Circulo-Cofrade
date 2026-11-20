import 'historia.dart';

/// Marca de lectura. [page] es el índice del page-flip: 0 portada, 1..n papel.
class HistoriaReadingMark {
  const HistoriaReadingMark({
    required this.historiaId,
    required this.page,
    required this.pageCount,
    required this.updatedAt,
  });

  final String historiaId;
  final int page;
  final int pageCount;
  final DateTime updatedAt;

  bool get isInProgress => page >= 1 && page <= pageCount;

  Map<String, dynamic> toJson() => {
        'page': page,
        'pageCount': pageCount,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  static HistoriaReadingMark? tryParse(String historiaId, Object? raw) {
    if (raw is! Map) return null;
    final page = int.tryParse('${raw['page']}');
    final pageCount = int.tryParse('${raw['pageCount'] ?? raw['page_count']}');
    final updatedAt = DateTime.tryParse(
      (raw['updatedAt'] ?? raw['updated_at'] ?? '').toString(),
    );
    if (page == null || pageCount == null || updatedAt == null) return null;
    return HistoriaReadingMark(
      historiaId: historiaId,
      page: page,
      pageCount: pageCount < 1 ? 1 : pageCount,
      updatedAt: updatedAt.toLocal(),
    );
  }
}

class HistoriaContinueItem {
  const HistoriaContinueItem({
    required this.historia,
    required this.mark,
  });

  final Historia historia;
  final HistoriaReadingMark mark;

  int get currentLeaf => mark.page.clamp(1, mark.pageCount);

  String get progressLabel => 'Pág. $currentLeaf de ${mark.pageCount}';

  double get fraction {
    if (mark.pageCount <= 0) return 0;
    return (mark.page.clamp(0, mark.pageCount)) / mark.pageCount;
  }
}

int clampHistoriaResumePage(int page, int contentPages) {
  if (contentPages <= 0 || page <= 0) return 0;
  if (page > contentPages) return 0;
  return page;
}
