import '../../../shared/models/calendar_event.dart';
import '../../../shared/models/forum.dart';

class SearchProfileHit {
  const SearchProfileHit({
    required this.id,
    required this.handle,
    required this.displayName,
    this.avatarUrl,
    this.isVerified = false,
    this.bio = '',
  });

  final String id;
  final String handle;
  final String displayName;
  final String? avatarUrl;
  final bool isVerified;
  final String bio;
}

class SearchResults {
  const SearchResults({
    required this.topics,
    required this.profiles,
    required this.events,
  });

  final List<ForumTopic> topics;
  final List<SearchProfileHit> profiles;
  final List<CalendarEvent> events;

  bool get isEmpty => topics.isEmpty && profiles.isEmpty && events.isEmpty;
  bool get isNotEmpty => !isEmpty;

  int get totalCount => profiles.length + events.length + topics.length;

  String get summaryLabel {
    final parts = <String>[];
    if (profiles.isNotEmpty) {
      parts.add(
        profiles.length == 1 ? '1 perfil' : '${profiles.length} perfiles',
      );
    }
    if (events.isNotEmpty) {
      parts.add(
        events.length == 1 ? '1 evento' : '${events.length} eventos',
      );
    }
    if (topics.isNotEmpty) {
      parts.add(
        topics.length == 1 ? '1 tema' : '${topics.length} temas',
      );
    }
    return parts.join(' · ');
  }

  static const empty = SearchResults(topics: [], profiles: [], events: []);
}
