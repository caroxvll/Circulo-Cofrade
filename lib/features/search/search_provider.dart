import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/mock_search.dart';
import 'data/recent_searches_store.dart';
import 'data/search_repository.dart';
import 'data/trends_repository.dart';
import 'models/search_results.dart';

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return createSearchRepository();
});

final trendsRepositoryProvider = Provider<TrendsRepository>((ref) {
  return createTrendsRepository();
});

final searchTrendsProvider = FutureProvider<List<SearchTrend>>((ref) async {
  return ref.watch(trendsRepositoryProvider).fetchTrends();
});

final recentSearchesProvider = FutureProvider<List<String>>((ref) async {
  return RecentSearchesStore.load();
});

final searchResultsProvider =
    FutureProvider.autoDispose.family<SearchResults, String>((ref, rawQuery) async {
  final query = rawQuery.trim();
  if (query.isEmpty) return SearchResults.empty;

  await Future<void>.delayed(const Duration(milliseconds: 350));

  final results = await ref.read(searchRepositoryProvider).search(query);

  if (query.length >= 2) {
    await RecentSearchesStore.add(query);
    ref.invalidate(recentSearchesProvider);
  }

  return results;
});
