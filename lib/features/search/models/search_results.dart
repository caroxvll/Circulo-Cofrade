import '../../../shared/models/calendar_event.dart';
import '../../../shared/models/forum.dart';

class SearchProfileHit {
  const SearchProfileHit({
    required this.id,
    required this.handle,
    required this.displayName,
    this.avatarUrl,
    this.bio = '',
  });

  final String id;
  final String handle;
  final String displayName;
  final String? avatarUrl;
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

  static const empty = SearchResults(topics: [], profiles: [], events: []);
}
