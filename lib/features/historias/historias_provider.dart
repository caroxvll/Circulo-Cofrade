import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import '../auth/auth_provider.dart';
import '../permissions/permissions_provider.dart';
import '../profile/profile_provider.dart';
import '../search/follows_provider.dart';
import 'data/historias_repository.dart';
import 'models/historia.dart';
import 'models/historia_reading_progress.dart';

export 'data/historias_repository.dart' show historiasHubConfigKey;

final historiasRepositoryProvider = Provider<HistoriasRepository>((ref) {
  return HistoriasRepository(client: SupabaseBootstrap.client);
});

/// `on` muestra El Cronicón en Comunidad. Cualquier otro valor la oculta.
final historiasHubEnabledProvider = FutureProvider<bool>((ref) async {
  return ref.watch(historiasRepositoryProvider).isHubEnabled();
});

@immutable
class HistoriasShelfQuery {
  const HistoriasShelfQuery({this.kind, this.onlyFollowing = false});

  final HistoriaKind? kind;
  final bool onlyFollowing;

  @override
  bool operator ==(Object other) =>
      other is HistoriasShelfQuery &&
      other.kind == kind &&
      other.onlyFollowing == onlyFollowing;

  @override
  int get hashCode => Object.hash(kind, onlyFollowing);
}

class HistoriasFeedPage {
  const HistoriasFeedPage({
    required this.items,
    required this.hasMore,
    this.isLoadingMore = false,
  });

  final List<Historia> items;
  final bool hasMore;
  final bool isLoadingMore;

  HistoriasFeedPage copyWith({
    List<Historia>? items,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return HistoriasFeedPage(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

final publishedHistoriasFeedProvider = AsyncNotifierProvider.family<
    PublishedHistoriasFeed, HistoriasFeedPage, HistoriasShelfQuery>(
  PublishedHistoriasFeed.new,
);

class PublishedHistoriasFeed extends AsyncNotifier<HistoriasFeedPage> {
  PublishedHistoriasFeed(this.query);

  final HistoriasShelfQuery query;

  @override
  Future<HistoriasFeedPage> build() async {
    if (query.onlyFollowing) {
      ref.watch(followedProfilesProvider);
    }
    final batch = await _fetch(offset: 0);
    return HistoriasFeedPage(
      items: batch,
      hasMore: batch.length >= HistoriasRepository.shelfPageSize,
    );
  }

  Future<List<Historia>> _fetch({required int offset}) async {
    Iterable<String>? authorIds;
    if (query.onlyFollowing) {
      final followed = await ref.read(followedProfilesProvider.future);
      if (followed.isEmpty) return const [];
      authorIds = followed;
    }
    return ref.read(historiasRepositoryProvider).fetchPublished(
          offset: offset,
          kind: query.kind,
          authorIds: authorIds,
        );
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final batch = await _fetch(offset: current.items.length);
      state = AsyncData(
        HistoriasFeedPage(
          items: [...current.items, ...batch],
          hasMore: batch.length >= HistoriasRepository.shelfPageSize,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }
}

final publishedHistoriasProvider = FutureProvider<List<Historia>>((ref) async {
  final page = await ref.watch(
    publishedHistoriasFeedProvider(const HistoriasShelfQuery()).future,
  );
  return page.items;
});

final myHistoriasProvider = FutureProvider<List<Historia>>((ref) {
  return ref.watch(historiasRepositoryProvider).fetchMine();
});

final staffHistoriasProvider = FutureProvider<List<Historia>>((ref) {
  return ref.watch(historiasRepositoryProvider).fetchAllForStaff();
});

final publishedHistoriasByAuthorProvider =
    FutureProvider.family<List<Historia>, String>((ref, authorId) {
  return ref.watch(historiasRepositoryProvider).fetchPublishedByAuthor(authorId);
});

final historiaByIdProvider =
    FutureProvider.family<Historia?, String>((ref, id) {
  return ref.watch(historiasRepositoryProvider).fetchById(id);
});

final historiaCommentsProvider =
    FutureProvider.family<List<HistoriaComment>, String>((ref, historiaId) {
  return ref.watch(historiasRepositoryProvider).fetchComments(historiaId);
});

final staffHistoriaCommentsProvider =
    FutureProvider<List<HistoriaComment>>((ref) {
  if (!ref.watch(isJuntaMemberProvider)) return Future.value(const []);
  return ref.watch(historiasRepositoryProvider).fetchRecentComments();
});

final canPublishHistoriasProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  final profile = ref.watch(currentUserProfileProvider).asData?.value;
  if (profile?.isSuspended == true) return false;
  return profile?.isChronicler == true || ref.watch(isAdminProvider);
});

final historiaReadingPageProvider =
    FutureProvider.family<int, String>((ref, historiaId) async {
  ref.watch(currentUserProvider);
  return ref.watch(historiasRepositoryProvider).loadReadingPage(historiaId);
});

final continueReadingProvider =
    FutureProvider<List<HistoriaContinueItem>>((ref) async {
  ref.watch(currentUserProvider);
  return ref.watch(historiasRepositoryProvider).fetchContinueReading();
});
