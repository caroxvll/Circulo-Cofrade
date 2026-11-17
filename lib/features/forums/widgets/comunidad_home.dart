import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/forum_text_format.dart';
import '../../../core/utils/image_decode_cache.dart';
import '../../../core/utils/time_ago.dart';
import '../../../core/widgets/cofradeo_asset_image.dart';
import '../../../core/widgets/cofradeo_avatar.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../../../core/widgets/screen_title_row.dart';
import '../../../core/widgets/search_quick_access_button.dart';
import '../../../core/widgets/verified_account_badge.dart';
import '../../../shared/models/followed_topic.dart';
import '../../../shared/models/user_profile.dart';
import '../../../shared/models/forum.dart';
import '../../auth/auth_provider.dart';
import '../../cuaresma/models/event_live_update.dart';
import '../../cuaresma/utils/cuaresma_topic.dart';
import '../../notifications/widgets/notifications_bell_button.dart';
import '../../semana_santa/models/ss_live_update.dart';
import '../../semana_santa/widgets/ss_forums_live_chip.dart';
import '../../semana_santa/widgets/ss_radar_section.dart';
import '../data/forum_pillar_covers.dart';
import '../data/topic_icon_assets.dart';
import '../followed_people_provider.dart';
import '../forums_provider.dart';
import '../para_ti_pulse_provider.dart';
import '../data/mock_forums.dart';
import '../mis_hermandades_provider.dart';
import '../utils/forum_navigation.dart';
import '../utils/hermandad_board_display.dart';
import '../utils/hermandad_local_assets.dart';
import '../utils/noticias_forum.dart';
import '../utils/official_post_categories.dart';
import '../../profile/open_hermandad_picker.dart';
import '../../search/follows_provider.dart';
import 'forum_pillar_icon_mark.dart';
import 'para_ti_live_events_band.dart';

/// Portada de Comunidad: lo que se mueve, lo que sigues y los foros.
class ComunidadHome extends ConsumerStatefulWidget {
  const ComunidadHome({
    super.key,
    required this.forums,
    this.noticias,
  });

  final List<ForumCategory> forums;
  final ForumCategory? noticias;

  @override
  ConsumerState<ComunidadHome> createState() => _ComunidadHomeState();
}

class _ComunidadHomeState extends ConsumerState<ComunidadHome> {
  var _tab = 0;
  var _forYouFilter = _ForYouFilter.todo;
  var _followingFilter = _FollowingFilter.todo;

  static const _scrollPhysics = AlwaysScrollableScrollPhysics(
    parent: BouncingScrollPhysics(),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ComunidadHeader(),
        _ComunidadTabs(
          index: _tab,
          onChanged: (index) => setState(() => _tab = index),
        ),
        Expanded(child: _tabBody(context)),
      ],
    );
  }

  Widget _tabBody(BuildContext context) {
    if (_tab == 0) return _forYouBody(context);
    return CustomScrollView(
      physics: _scrollPhysics,
      slivers: [
        ...switch (_tab) {
          1 => _followingSlivers(context),
          _ => _forumsSlivers(context),
        },
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _forYouBody(BuildContext context) {
    final cards = <_Activity>[
      if (widget.noticias != null) _Activity.fromForum(widget.noticias!),
      for (final forum in widget.forums) _Activity.fromForum(forum),
    ].where((item) => item.hasTopic).toList();
    final visible = [
      for (final item in cards)
        if (item.kind.matches(_forYouFilter)) item,
    ];
    final river = _forYouFilter == _ForYouFilter.todo
        ? ref.watch(paraTiRiverProvider)
        : const ParaTiRiver.empty();
    final feed = _forYouPieces(visible, river);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PillFilterBar(
          labels: [for (final filter in _ForYouFilter.values) filter.label],
          icons: [for (final filter in _ForYouFilter.values) filter.icon],
          selectedIndex: _forYouFilter.index,
          onChanged: (index) => setState(
            () => _forYouFilter = _ForYouFilter.values[index],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: AppColors.border),
        if (_forYouFilter == _ForYouFilter.todo) const ParaTiLiveEventsBand(),
        Expanded(
          child: ListView(
            physics: _scrollPhysics,
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (feed.isEmpty)
                _EmptyNote(
                  text: cards.isEmpty && river.entries.isEmpty
                      ? 'Cuando haya temas nuevos, aparecerán aquí.'
                      : _forYouFilter.emptyLabel,
                )
              else
                for (final piece in feed) piece,
            ],
          ),
        ),
      ],
    );
  }

  /// Para ti, de más nuevo a más viejo. Una noticia o una respuesta reciente
  /// pasa por delante de un comunicado de hermandad más antiguo.
  List<Widget> _forYouPieces(List<_Activity> visible, ParaTiRiver river) {
    if (_forYouFilter != _ForYouFilter.todo) {
      final sorted = [...visible]..sort((a, b) {
        final aAt = a.forum.lastActivityAt?.millisecondsSinceEpoch ?? 0;
        final bAt = b.forum.lastActivityAt?.millisecondsSinceEpoch ?? 0;
        return bAt.compareTo(aAt);
      });
      return [
        for (final item in sorted)
          _TopicActivityCard(
            item: item,
            onTap: () => _openTopic(context, item),
          ),
      ];
    }

    final signedIn = ref.watch(currentUserProvider) != null;
    final posts = signedIn
        ? ref.watch(followedPeoplePostsProvider).asData?.value ??
            const <FollowedPersonPost>[]
        : const <FollowedPersonPost>[];
    final digests = signedIn
        ? ref.watch(followedHermandadDigestsProvider).asData?.value ??
            const <HermandadDigest>[]
        : const <HermandadDigest>[];
    final coveredTopics = {for (final post in posts) post.activity.topicId};
    final coveredReplies = {for (final post in posts) post.activity.id};

    final ranked = <({int at, Widget child})>[
      for (final entry in river.entries)
        (at: entry.at.millisecondsSinceEpoch, child: _riverEntry(entry)),
      for (final post in posts)
        (
          at: post.at.millisecondsSinceEpoch,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: _PersonPostCard(post: post),
          ),
        ),
      for (final group in digests)
        for (final section in group.sections)
          if (!coveredReplies.contains(section.reply.id))
            (
              at: section.reply.createdAt?.millisecondsSinceEpoch ?? 0,
              child: _HermandadLatestCard(
                group: HermandadDigest(
                  board: group.board,
                  hermandadName: group.hermandadName,
                  processionDay: group.processionDay,
                  sections: [section],
                ),
              ),
            ),
      for (final item in visible)
        if (item.kind != _ForYouKind.hermandad &&
            !coveredTopics.contains(item.topicId))
          (
            at: item.forum.lastActivityAt?.millisecondsSinceEpoch ?? 0,
            child: _TopicActivityCard(
              item: item,
              onTap: () => _openTopic(context, item),
            ),
          ),
    ]..sort((a, b) => b.at.compareTo(a.at));

    return [for (final piece in ranked.take(24)) piece.child];
  }

  Widget _riverEntry(ParaTiRiverEntry entry) {
    return switch (entry) {
      ParaTiCuaresmaTweet(:final update) => _ParaTiEventTweet(update: update),
      ParaTiSsLive(:final update) => _ParaTiLiveUpdate(update: update),
      ParaTiHotTopic(:final topic, :final activityAt) => _SeasonPulseCard(
          topic: topic,
          activityAt: activityAt,
        ),
    };
  }

  List<Widget> _followingSlivers(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return [
        SliverToBoxAdapter(
          child: _EmptyNote(
            text: 'Entra para ver las hermandades y los temas que sigues.',
            actionLabel: 'Entrar',
            onAction: () => context.push(
              '/login?redirect=${Uri.encodeComponent('/foros')}',
            ),
          ),
        ),
      ];
    }

    final digests = ref.watch(followedHermandadDigestsProvider);
    final topics = ref.watch(followedTopicsDetailsProvider);
    final profiles = ref.watch(followedProfilesDetailsProvider);
    final posts = ref.watch(followedPeoplePostsProvider);
    final hermandades =
        ref.watch(followedHermandadBoardsProvider).asData?.value ??
        const <FollowedTopic>[];
    final hashtagsAsync = ref.watch(followedHashtagsProvider);
    final hashtags = (hashtagsAsync.asData?.value.toList() ?? <String>[])
      ..sort();
    final people = (profiles.asData?.value ?? const <UserProfile>[])
        .where((profile) => !profile.isSuspended)
        .toList();
    final boards = topics.asData?.value
            .where((topic) => !topic.isHermandadBoard)
            .toList() ??
        const <FollowedTopic>[];
    final published = digests.asData?.value
            .where((group) => group.sections.isNotEmpty)
            .toList() ??
        const <HermandadDigest>[];
    final personPosts = posts.asData?.value ?? const <FollowedPersonPost>[];
    final filter = _followingFilter;
    final visibleBoards = [
      for (final topic in boards)
        if (_followedTopicMatches(topic, filter)) topic,
    ];
    final topicCount = filter == _FollowingFilter.todo
        ? (visibleBoards.length > 3 ? 3 : visibleBoards.length)
        : visibleBoards.length;
    final visibleDigests = _digestsForFilter(published, filter);
    final visiblePosts = [
      for (final post in personPosts)
        if (_personPostMatches(post, filter)) post,
    ];
    final activity = _followingActivity(visibleDigests, visiblePosts);
    final waiting = (digests.isLoading && published.isEmpty) ||
        (posts.isLoading && personPosts.isEmpty);
    final hasFeed = visibleBoards.isNotEmpty ||
        visibleDigests.isNotEmpty ||
        visiblePosts.isNotEmpty;

    return [
      SliverToBoxAdapter(
        child: _PillFilterBar(
          labels: [for (final item in _FollowingFilter.values) item.label],
          icons: [for (final item in _FollowingFilter.values) item.icon],
          selectedIndex: filter.index,
          onChanged: (index) => setState(
            () => _followingFilter = _FollowingFilter.values[index],
          ),
        ),
      ),
      if (people.isEmpty && hermandades.isEmpty && profiles.hasValue)
        SliverToBoxAdapter(
          child: _ShelfHint(
            title: 'Cuentas que sigues',
            text: 'Sigue una hermandad o un cofrade y aparecerá aquí.',
            actionLabel: 'Elegir',
            onAction: () => openHermandadPicker(context, ref),
          ),
        )
      else if (people.isNotEmpty || hermandades.isNotEmpty)
        SliverToBoxAdapter(
          child: _AccountsRail(hermandades: hermandades, people: people),
        ),
      if (hashtags.isNotEmpty)
        SliverToBoxAdapter(child: _HashtagShelf(tags: hashtags)),
      if (visibleBoards.isNotEmpty) ...[
        const SliverToBoxAdapter(
          child: _SectionTitle(title: 'Temas que sigues', top: 16),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          sliver: SliverList.separated(
            itemCount: topicCount,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final topic = visibleBoards[index];
              return _FollowedTopicRow(
                topic: topic,
                forumName: _forumName(topic.forumId),
                onTap: () => pushForumTopic(
                  context,
                  ref,
                  forumId: topic.forumId,
                  topicId: topic.topicId,
                ),
              );
            },
          ),
        ),
      ],
      if (waiting && !hasFeed)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 22),
            child: Center(child: CircularProgressIndicator()),
          ),
        )
      else if (!hasFeed && posts.hasValue && digests.hasValue)
        SliverToBoxAdapter(
          child: _EmptyNote(text: filter.emptyLabel),
        )
      else if (activity.isNotEmpty) ...[
        const SliverToBoxAdapter(
          child: _SectionTitle(title: 'Actividad reciente', top: 18),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(top: 2),
          sliver: SliverList.separated(
            itemCount: activity.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => activity[index],
          ),
        ),
      ],
    ];
  }

  List<Widget> _followingActivity(
    List<HermandadDigest> digests,
    List<FollowedPersonPost> posts,
  ) {
    final coveredReplies = {for (final post in posts) post.activity.id};
    final ranked = <({int at, Widget child})>[
      for (final post in posts)
        (
          at: post.at.millisecondsSinceEpoch,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _PersonPostCard(post: post),
          ),
        ),
      for (final group in digests)
        for (final section in group.sections)
          if (!coveredReplies.contains(section.reply.id))
            (
              at: section.reply.createdAt?.millisecondsSinceEpoch ?? 0,
              child: _HermandadLatestCard(
                group: HermandadDigest(
                  board: group.board,
                  hermandadName: group.hermandadName,
                  processionDay: group.processionDay,
                  sections: [section],
                ),
              ),
            ),
    ]..sort((a, b) => b.at.compareTo(a.at));
    return [for (final piece in ranked) piece.child];
  }

  bool _followedTopicMatches(FollowedTopic topic, _FollowingFilter filter) {
    final isNews = isNoticiasForum(topic.forumId);
    return switch (filter) {
      _FollowingFilter.todo => true,
      _FollowingFilter.noticias => isNews,
      _FollowingFilter.temas => !isNews,
      _ => false,
    };
  }

  bool _personPostMatches(FollowedPersonPost post, _FollowingFilter filter) {
    final isNews = isNoticiasForum(post.activity.forumId);
    return switch (filter) {
      _FollowingFilter.todo => true,
      _FollowingFilter.noticias => isNews,
      _FollowingFilter.temas => !isNews,
      _ => false,
    };
  }

  List<HermandadDigest> _digestsForFilter(
    List<HermandadDigest> published,
    _FollowingFilter filter,
  ) {
    if (filter == _FollowingFilter.todo) return published;
    final category = filter.officialCategory;
    if (category == null) return const [];
    return [
      for (final group in published)
        if (group.sections.any(
          (section) =>
              (section.reply.officialCategory ?? 'noticia') == category,
        ))
          HermandadDigest(
            board: group.board,
            hermandadName: group.hermandadName,
            processionDay: group.processionDay,
            sections: [
              for (final section in group.sections)
                if ((section.reply.officialCategory ?? 'noticia') == category)
                  section,
            ],
          ),
    ];
  }

  String _forumName(String forumId) {
    final noticias = widget.noticias;
    if (noticias != null && noticias.id == forumId) return noticias.name;
    for (final forum in widget.forums) {
      if (forum.id == forumId) return forum.name;
    }
    return '';
  }

  List<Widget> _forumsSlivers(BuildContext context) {
    final latest = <_Activity>[
      for (final forum in widget.forums) _Activity.fromForum(forum),
    ].where((item) => item.hasTopic).take(5).toList();

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
        sliver: SliverList.separated(
          itemCount: widget.forums.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final forum = widget.forums[index];
            return _ForumDirectoryCard(
              forum: forum,
              onTap: () => pushForumTopicsList(
                context,
                ref,
                forumId: forum.id,
              ),
            );
          },
        ),
      ),
      if (latest.isNotEmpty) ...[
        const SliverToBoxAdapter(
          child: _SectionTitle(title: 'En conversación', top: 22),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          sliver: SliverToBoxAdapter(
            child: _SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < latest.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: 14,
                        endIndent: 14,
                        color: AppColors.border.withValues(alpha: 0.9),
                      ),
                    _LatestTopicRow(
                      item: latest[i],
                      onTap: () => _openTopic(context, latest[i]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    ];
  }

  void _openTopic(BuildContext context, _Activity item) {
    final topicId = item.topicId;
    if (topicId == null || topicId.isEmpty) {
      pushForumTopicsList(context, ref, forumId: item.forum.id);
      return;
    }
    if (isNoticiasForum(item.forum.id)) {
      context.push(forumTopicLocation(item.forum.id, topicId));
      return;
    }
    pushForumTopic(
      context,
      ref,
      forumId: item.forum.id,
      topicId: topicId,
    );
  }
}

class _Activity {
  const _Activity({
    required this.forum,
    required this.topicId,
    required this.title,
    required this.excerpt,
  });

  factory _Activity.fromForum(ForumCategory forum) {
    return _Activity(
      forum: forum,
      topicId: forum.lastTopicId?.trim(),
      title: forum.lastTopicTitle?.trim() ?? '',
      excerpt: forum.lastTopicExcerpt?.trim() ?? '',
    );
  }

  final ForumCategory forum;
  final String? topicId;
  final String title;
  final String excerpt;

  bool get hasTopic =>
      topicId != null &&
      topicId!.isNotEmpty &&
      title.isNotEmpty;

  _ForYouKind get kind {
    if (isNoticiasForum(forum.id)) return _ForYouKind.noticias;
    if (forum.isHermandadesChannel) return _ForYouKind.hermandad;
    return _ForYouKind.temas;
  }
}

enum _FollowingFilter { todo, noticias, cultos, actos, patrimonio, temas }

extension on _FollowingFilter {
  String get label => switch (this) {
        _FollowingFilter.todo => 'Todo',
        _FollowingFilter.noticias => 'Noticias',
        _FollowingFilter.cultos => 'Cultos',
        _FollowingFilter.actos => 'Actos',
        _FollowingFilter.patrimonio => 'Patrimonio',
        _FollowingFilter.temas => 'Temas',
      };

  IconData get icon => switch (this) {
        _FollowingFilter.todo => Icons.local_fire_department,
        _FollowingFilter.noticias => Icons.article_outlined,
        _FollowingFilter.cultos => Icons.church_outlined,
        _FollowingFilter.actos => Icons.event_outlined,
        _FollowingFilter.patrimonio => Icons.account_balance_outlined,
        _FollowingFilter.temas => Icons.forum_outlined,
      };

  String? get officialCategory => switch (this) {
        _FollowingFilter.noticias => 'noticia',
        _FollowingFilter.cultos => 'culto',
        _FollowingFilter.actos => 'acto',
        _FollowingFilter.patrimonio => 'patrimonio',
        _FollowingFilter.todo || _FollowingFilter.temas => null,
      };

  String get emptyLabel => switch (this) {
        _FollowingFilter.todo => 'Hoy no hay nada nuevo en lo que sigues.',
        _FollowingFilter.noticias => 'No hay noticias nuevas en lo que sigues.',
        _FollowingFilter.cultos => 'No hay cultos nuevos en lo que sigues.',
        _FollowingFilter.actos => 'No hay actos nuevos en lo que sigues.',
        _FollowingFilter.patrimonio =>
          'No hay patrimonio nuevo en lo que sigues.',
        _FollowingFilter.temas => 'No hay temas nuevos en lo que sigues.',
      };
}

enum _ForYouFilter { todo, noticias, temas }

extension on _ForYouFilter {
  String get label => switch (this) {
        _ForYouFilter.todo => 'Todo',
        _ForYouFilter.noticias => 'Noticias',
        _ForYouFilter.temas => 'Temas',
      };

  IconData get icon => switch (this) {
        _ForYouFilter.todo => Icons.local_fire_department,
        _ForYouFilter.noticias => Icons.article_outlined,
        _ForYouFilter.temas => Icons.forum_outlined,
      };

  String get emptyLabel => switch (this) {
        _ForYouFilter.todo => 'Cuando haya temas nuevos, aparecerán aquí.',
        _ForYouFilter.noticias => 'No hay noticias nuevas en tu inicio.',
        _ForYouFilter.temas => 'No hay temas nuevos en tu inicio.',
      };
}

enum _ForYouKind { noticias, temas, hermandad }

extension on _ForYouKind {
  bool matches(_ForYouFilter filter) => switch (filter) {
        _ForYouFilter.todo => true,
        _ForYouFilter.noticias => this == _ForYouKind.noticias,
        _ForYouFilter.temas => this == _ForYouKind.temas,
      };
}

class _ComunidadHeader extends StatelessWidget {
  const _ComunidadHeader();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
        child: Row(
          children: [
            Expanded(
              child: AdaptiveScreenTitle(
                text: 'COMUNIDAD',
                style: AppTypography.screenTitle().copyWith(
                  fontSize: 28,
                  letterSpacing: 0.4,
                  height: 1,
                ),
              ),
            ),
            const SemanaSantaForumsLiveChip(inline: true),
            const SearchQuickAccessButton(iconColor: AppColors.textPrimary),
            const NotificationsBellButton(iconColor: AppColors.textPrimary),
          ],
        ),
      ),
    );
  }
}

class _ComunidadTabs extends StatelessWidget {
  const _ComunidadTabs({
    required this.index,
    required this.onChanged,
  });

  final int index;
  final ValueChanged<int> onChanged;

  static const _labels = ['Para ti', 'Siguiendo', 'Foros'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(i),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 10),
                  child: Column(
                    children: [
                      Text(
                        _labels[i],
                        style: AppTypography.bodyMedium(
                          color: index == i
                              ? AppColors.burgundy
                              : AppColors.textMuted,
                        ).copyWith(
                          fontWeight:
                              index == i ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 2,
                        width: index == i ? 28 : 0,
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

const _hotCommentCount = 6;

class _ParaTiEventTweet extends StatelessWidget {
  const _ParaTiEventTweet({required this.update});

  final EventLiveUpdate update;

  @override
  Widget build(BuildContext context) {
    final handle = update.authorHandle.startsWith('@')
        ? update.authorHandle
        : '@${update.authorHandle}';
    final place = update.placeLabel?.trim() ?? '';

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: InkWell(
        onTap: () => context.push(
          '/foros/foro-cofradiero/tema/$cuaresmaTopicId/ensayo/${update.calendarEventId}',
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'EN DIRECTO',
                    style: AppTypography.labelSmall(
                      color: const Color(0xFF2E7D32),
                    ).copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatTimeAgo(update.createdAt),
                    style: AppTypography.labelSmall().copyWith(fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                handle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.hermandadName().copyWith(
                  fontSize: 15,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                update.message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMedium(),
              ),
              if (place.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  place,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSmall(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ParaTiLiveUpdate extends StatelessWidget {
  const _ParaTiLiveUpdate({required this.update});

  final SsLiveUpdate update;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: SsLiveHubCompactTile(update: update),
      ),
    );
  }
}

class _SeasonPulseCard extends ConsumerWidget {
  const _SeasonPulseCard({required this.topic, required this.activityAt});

  final ForumTopic topic;
  final DateTime activityAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicExcerpt = plainTextForExcerpt(topic.excerpt, maxLength: 180);
    final title = topic.title;
    final showBody = topicExcerpt.isNotEmpty && topicExcerpt != title;
    final thumb = topic.coverImageUrl?.trim();
    final handle = topic.authorHandle;
    final atHandle = handle.isEmpty
        ? ''
        : (handle.startsWith('@') ? handle : '@$handle');
    final when = activityAt;
    final meta = atHandle.isEmpty
        ? formatTimeAgo(when)
        : '$atHandle · ${formatTimeAgo(when)}';

    return _TimelinePost(
      onTap: () => _open(context, ref),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CofradeoAvatar(
                imageUrl: topic.authorAvatarUrl,
                icon: topic.avatarIcon,
                size: 40,
                backgroundColor: AppColors.backgroundElevated,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _prettyAuthor(topic),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.hermandadName().copyWith(
                              fontSize: 17,
                              height: 1.05,
                            ),
                          ),
                        ),
                        if (topic.authorVerified) ...[
                          const SizedBox(width: 4),
                          const VerifiedAccountIcon(size: 15),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelSmall().copyWith(
                        fontSize: 12,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _OpenPostButton(
                label: 'Ver',
                onTap: () => _open(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ConversationSlide(
            topicId: topic.id,
            chip: const _Chip(label: 'Cuaresma'),
            post: _PulsePostFace(
              title: title,
              excerpt: showBody ? topicExcerpt : '',
              thumb: thumb,
            ),
            footer: Row(
              children: [
                _FeedMetric(
                  icon: Icons.chat_bubble_outline,
                  value: formatCount(topic.commentCount),
                  heat: topic.commentCount >= _hotCommentCount,
                ),
                const SizedBox(width: 16),
                _FeedMetric(
                  icon: Icons.visibility_outlined,
                  value: formatCount(topic.viewCount),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, WidgetRef ref) {
    pushForumTopic(
      context,
      ref,
      forumId: topic.forumId,
      topicId: topic.id,
    );
  }

  String _prettyAuthor(ForumTopic topic) {
    final display = topic.authorDisplayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    return _prettyHandle(topic.authorHandle);
  }

  String _prettyHandle(String raw) {
    final handle = raw.trim().replaceFirst(RegExp(r'^@'), '');
    if (handle.isEmpty) return 'Cofradeo';
    return handle
        .split(RegExp(r'[._\-]+'))
        .where((part) => part.isNotEmpty)
        .map((part) {
          if (part.length == 1) return part.toUpperCase();
          return '${part[0].toUpperCase()}${part.substring(1)}';
        })
        .join(' ');
  }
}

class _PulsePostFace extends StatelessWidget {
  const _PulsePostFace({
    required this.title,
    required this.excerpt,
    this.thumb,
    this.media,
  });

  final String title;
  final String excerpt;
  final String? thumb;
  final Widget? media;

  @override
  Widget build(BuildContext context) {
    final source = thumb?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.newsHeadline().copyWith(
            fontSize: 18,
            height: 1.15,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (excerpt.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            excerpt,
            style: AppTypography.bodyMedium().copyWith(
              fontSize: 13.5,
              height: 1.35,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (media != null) ...[
          const SizedBox(height: 10),
          media!,
        ] else if (source != null && source.isNotEmpty) ...[
          const SizedBox(height: 10),
          _TimelineMedia(source: source),
        ],
      ],
    );
  }
}

class _ConversationSlide extends ConsumerStatefulWidget {
  const _ConversationSlide({
    required this.topicId,
    required this.chip,
    required this.post,
    this.footer,
  });

  final String topicId;
  final Widget chip;
  final Widget post;
  final Widget? footer;

  @override
  ConsumerState<_ConversationSlide> createState() =>
      _ConversationSlideState();
}

class _ConversationSlideState extends ConsumerState<_ConversationSlide> {
  Timer? _timer;
  var _showReply = false;
  var _introduced = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _advance();
    });
  }

  @override
  void didUpdateWidget(covariant _ConversationSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.topicId != widget.topicId) {
      _showReply = false;
      _introduced = false;
      _advance();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _advance() {
    _timer?.cancel();
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    final pending = ref.read(latestTopicReplyProvider(widget.topicId));
    if (pending.isLoading) {
      _timer = Timer(const Duration(seconds: 1), _advance);
      return;
    }
    if (pending.asData?.value == null) return;
    final stagger = widget.topicId.hashCode.abs() % 900;
    final wait = _showReply
        ? const Duration(seconds: 4)
        : (_introduced
              ? const Duration(seconds: 4)
              : Duration(milliseconds: 1100 + stagger));
    _timer = Timer(wait, () {
      if (!mounted) return;
      setState(() {
        _showReply = !_showReply;
        if (_showReply) _introduced = true;
      });
      _advance();
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    ref.listen(latestTopicReplyProvider(widget.topicId), (previous, next) {
      final before = previous?.asData?.value?.id;
      final after = next.asData?.value?.id;
      if (after == null || after == before || !mounted) return;
      setState(() {
        _showReply = true;
        _introduced = true;
      });
    });
    final reply = ref
        .watch(latestTopicReplyProvider(widget.topicId))
        .asData
        ?.value;
    final showReply = !reduce && _showReply && reply != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            widget.chip,
            const Spacer(),
            if (reply != null) _PulseDots(active: showReply ? 1 : 0),
          ],
        ),
        const SizedBox(height: 8),
        if (reduce && reply != null) ...[
          widget.post,
          const SizedBox(height: 12),
          _replyFace(reply),
        ] else
          AnimatedSize(
            alignment: Alignment.topCenter,
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 460),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (current, previous) {
                return Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    ...previous,
                    ?current,
                  ],
                );
              },
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(
                  begin: const Offset(0.22, 0),
                  end: Offset.zero,
                ).animate(animation);
                return ClipRect(
                  child: SlideTransition(
                    position: slide,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                );
              },
              child: showReply
                  ? KeyedSubtree(
                      key: ValueKey('reply-${reply.id}'),
                      child: _replyFace(reply),
                    )
                  : KeyedSubtree(
                      key: ValueKey('post-${widget.topicId}'),
                      child: widget.post,
                    ),
            ),
          ),
        if (widget.footer != null) ...[
          const SizedBox(height: 12),
          widget.footer!,
        ],
      ],
    );
  }

  Widget _replyFace(ForumReply reply) {
    final text = plainTextForExcerpt(reply.content, maxLength: 180);
    final handle = reply.authorHandle.startsWith('@')
        ? reply.authorHandle
        : '@${reply.authorHandle}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ÚLTIMO COMENTARIO',
          style: AppTypography.labelSmall(color: AppColors.gold).copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 10,
            letterSpacing: 0.7,
            height: 1,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            CofradeoAvatar(
              imageUrl: reply.authorAvatarUrl,
              icon: Icons.chat_bubble_outline,
              size: 32,
              backgroundColor: AppColors.backgroundElevated,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _prettyReplyName(reply.authorHandle),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.hermandadName().copyWith(
                            fontSize: 15,
                            height: 1.05,
                          ),
                        ),
                      ),
                      if (reply.authorVerified) ...[
                        const SizedBox(width: 4),
                        const VerifiedAccountIcon(size: 14),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$handle · ${reply.timeAgo}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall().copyWith(
                      fontSize: 12,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            text,
            style: AppTypography.newsHeadline().copyWith(
              fontSize: 18,
              height: 1.2,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  String _prettyReplyName(String raw) {
    final handle = raw.trim().replaceFirst(RegExp(r'^@'), '');
    if (handle.isEmpty) return 'Cofrade';
    return handle
        .split(RegExp(r'[._\-]+'))
        .where((part) => part.isNotEmpty)
        .map((part) {
          if (part.length == 1) return part.toUpperCase();
          return '${part[0].toUpperCase()}${part.substring(1)}';
        })
        .join(' ');
  }
}

class _PulseDots extends StatelessWidget {
  const _PulseDots({required this.active});

  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 2; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            width: i == active ? 14 : 5,
            height: 5,
            decoration: BoxDecoration(
              color: i == active ? AppColors.burgundy : AppColors.border,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ],
      ],
    );
  }
}

class _TopicActivityCard extends ConsumerWidget {
  const _TopicActivityCard({
    required this.item,
    required this.onTap,
  });

  final _Activity item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicId = item.topicId;
    final topic = topicId == null || topicId.isEmpty
        ? null
        : ref
            .watch(
              forumTopicProvider(
                ForumTopicKey(forumId: item.forum.id, topicId: topicId),
              ),
            )
            .asData
            ?.value;
    final excerpt = plainTextForExcerpt(
      topic?.excerpt.trim().isNotEmpty == true ? topic!.excerpt : item.excerpt,
      maxLength: 180,
    );
    final thumb = _feedThumb(context, topic);

    return _TimelinePost(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (topic != null)
                CofradeoAvatar(
                  imageUrl: topic.authorAvatarUrl,
                  icon: topic.avatarIcon,
                  size: 40,
                  backgroundColor: AppColors.backgroundElevated,
                )
              else
                ForumPillarIconMark(forum: item.forum, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _authorName(topic, item.forum),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.hermandadName().copyWith(
                              fontSize: 17,
                              height: 1.05,
                            ),
                          ),
                        ),
                        if (topic?.authorVerified == true) ...[
                          const SizedBox(width: 4),
                          const VerifiedAccountIcon(size: 15),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _authorMeta(topic, item.forum),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelSmall().copyWith(
                        fontSize: 12,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _OpenPostButton(label: 'Ver', onTap: onTap),
            ],
          ),
          const SizedBox(height: 10),
          if (item.kind == _ForYouKind.temas &&
              topicId != null &&
              topicId.isNotEmpty)
            _ConversationSlide(
              topicId: topicId,
              chip: _Chip(label: _chipLabel(topic)),
              post: _PulsePostFace(
                title: item.title,
                excerpt: excerpt,
                media: thumb,
              ),
              footer: topic == null
                  ? null
                  : Row(
                      children: [
                        _FeedMetric(
                          icon: Icons.chat_bubble_outline,
                          value: formatCount(topic.commentCount),
                          heat: topic.commentCount >= _hotCommentCount,
                        ),
                        const SizedBox(width: 16),
                        _FeedMetric(
                          icon: Icons.visibility_outlined,
                          value: formatCount(topic.viewCount),
                        ),
                      ],
                    ),
            )
          else ...[
            _Chip(label: _chipLabel(topic)),
            const SizedBox(height: 8),
            _PulsePostFace(
              title: item.title,
              excerpt: excerpt,
              media: thumb,
            ),
            if (topic != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  _FeedMetric(
                    icon: Icons.chat_bubble_outline,
                    value: formatCount(topic.commentCount),
                    heat: topic.commentCount >= _hotCommentCount,
                  ),
                  const SizedBox(width: 16),
                  _FeedMetric(
                    icon: Icons.visibility_outlined,
                    value: formatCount(topic.viewCount),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _chipLabel(ForumTopic? topic) {
    return switch (item.kind) {
      _ForYouKind.noticias => topic == null
          ? 'Noticias'
          : noticiasCategoryLabel(topic.relatedForumId),
      _ForYouKind.hermandad => 'Hermandad',
      _ForYouKind.temas => item.forum.name,
    };
  }

  String _authorName(ForumTopic? topic, ForumCategory forum) {
    final display = topic?.authorDisplayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final handle = topic?.authorHandle.trim() ?? '';
    if (handle.isEmpty) return forum.name;
    final pretty = handle
        .split(RegExp(r'[._\-]+'))
        .where((part) => part.isNotEmpty)
        .map((part) {
          if (part.length == 1) return part.toUpperCase();
          return '${part[0].toUpperCase()}${part.substring(1)}';
        })
        .join(' ');
    return pretty.isEmpty ? forum.name : pretty;
  }

  String _authorMeta(ForumTopic? topic, ForumCategory forum) {
    final when = topic?.timeAgo ?? forum.lastMessageAgo;
    final raw = topic?.authorHandle.trim() ?? '';
    if (raw.isEmpty) return when;
    final handle = raw.startsWith('@') ? raw : '@$raw';
    return '$handle · $when';
  }

  Widget? _feedThumb(BuildContext context, ForumTopic? topic) {
    final source = topic?.coverImageUrl?.trim();
    if (source == null || source.isEmpty) return null;
    final image = topicCoverIsAsset(source)
        ? CofradeoAssetImage(
            assetPath: source,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            cacheWidth: ImageDecodeCache.px(context, 176),
          )
        : CofradeoNetworkImage(
            url: source,
            fit: BoxFit.cover,
            cacheSize: 176,
          );
    return _TimelineMedia(source: source, image: image);
  }
}

class _TimelinePost extends StatelessWidget {
  const _TimelinePost({
    required this.onTap,
    required this.child,
  });

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.burgundy.withValues(alpha: 0.06),
        highlightColor: AppColors.gold.withValues(alpha: 0.05),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.border),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _TimelineMedia extends StatelessWidget {
  const _TimelineMedia({required this.source, this.image});

  final String source;
  final Widget? image;

  @override
  Widget build(BuildContext context) {
    final child = image ??
        (topicCoverIsAsset(source)
            ? CofradeoAssetImage(
                assetPath: source,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                cacheWidth: ImageDecodeCache.px(context, 720),
              )
            : CofradeoNetworkImage(
                url: source,
                fit: BoxFit.cover,
                cacheSize: 720,
              ));

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: double.infinity,
        height: 196,
        child: child,
      ),
    );
  }
}

class _HashtagShelf extends StatelessWidget {
  const _HashtagShelf({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Hashtags que sigues', top: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: tags.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final raw = tags[index].trim();
              final label = raw.startsWith('#') ? raw : '#$raw';
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.push(
                    '/buscar?q=${Uri.encodeComponent(label)}',
                  ),
                  borderRadius: BorderRadius.circular(99),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: AppTypography.hermandadName(
                          color: AppColors.burgundyDark,
                        ).copyWith(fontSize: 16),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ShelfHint extends StatelessWidget {
  const _ShelfHint({
    required this.text,
    this.title,
    this.actionLabel,
    this.onAction,
  });

  final String? title;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) _SectionTitle(title: title!, top: 14),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: AppTypography.bodyMedium().copyWith(
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.burgundy,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    actionLabel!,
                    style: AppTypography.labelSmall(
                      color: AppColors.burgundy,
                    ).copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountsRail extends ConsumerWidget {
  const _AccountsRail({
    required this.hermandades,
    required this.people,
  });

  final List<FollowedTopic> hermandades;
  final List<UserProfile> people;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = hermandades.length + people.length + 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: 'Cuentas que sigues',
          top: 4,
          actionLabel: 'Ver todos',
          onAction: () => context.push('/perfil/siguiendo'),
        ),
        SizedBox(
          height: 102,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: count,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              if (index < hermandades.length) {
                final board = hermandades[index];
                final parsed = parseHermandadTopicTitle(board.title);
                return _AccountBubble(
                  name: parsed.hermandadName,
                  caption: 'Hermandad',
                  gold: true,
                  onTap: () => pushForumTopic(
                    context,
                    ref,
                    forumId: board.forumId,
                    topicId: board.topicId,
                  ),
                  child: _HermandadCrest(
                    name: parsed.hermandadName,
                    day: parsed.processionDay,
                    iconImageUrl: board.iconImageUrl,
                    size: 54,
                  ),
                );
              }
              final personIndex = index - hermandades.length;
              if (personIndex < people.length) {
                final profile = people[personIndex];
                final hermandad = profile.accountType.isBrotherhood;
                return _AccountBubble(
                  name: profile.displayName,
                  caption: hermandad ? 'Hermandad' : 'Cofrade',
                  gold: hermandad,
                  onTap: () => context.push('/perfil/usuario/${profile.id}'),
                  child: CofradeoAvatar(
                    imageUrl: profile.avatarUrl,
                    icon: hermandad ? Icons.church_outlined : Icons.person,
                    size: 54,
                    backgroundColor: AppColors.burgundyDark,
                  ),
                );
              }
              return _AccountBubble(
                name: 'Seguir',
                caption: '',
                gold: false,
                onTap: () => openHermandadPicker(context, ref),
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.burgundy.withValues(alpha: 0.06),
                  ),
                  child: const Icon(Icons.add, color: AppColors.burgundy, size: 22),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AccountBubble extends StatelessWidget {
  const _AccountBubble({
    required this.name,
    required this.caption,
    required this.gold,
    required this.onTap,
    required this.child,
  });

  final String name;
  final String caption;
  final bool gold;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2.2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: gold ? AppColors.gold : AppColors.burgundy.withValues(alpha: 0.55),
                  width: 1.4,
                ),
              ),
              child: child,
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.labelSmall(
                color: AppColors.textPrimary,
              ).copyWith(fontWeight: FontWeight.w700, fontSize: 11, height: 1.1),
            ),
            if (caption.isNotEmpty)
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSmall(
                  color: gold ? AppColors.goldDark : AppColors.textMuted,
                ).copyWith(fontSize: 9.5, fontWeight: FontWeight.w700),
              ),
          ],
        ),
      ),
    );
  }
}

class _PersonPostCard extends StatelessWidget {
  const _PersonPostCard({required this.post});

  final FollowedPersonPost post;

  @override
  Widget build(BuildContext context) {
    final profile = post.profile;
    final activity = post.activity;
    final hermandad = profile.accountType.isBrotherhood;
    final preview = plainTextForExcerpt(activity.preview, maxLength: 160);
    final cover = activity.coverImageUrl?.trim();
    final hasCover = cover != null && cover.isNotEmpty && !cover.startsWith('assets/');
    final kind = activity.isTopic ? 'Publicó' : 'Respondió';

    return _SurfaceCard(
      onTap: () {
        final suffix = activity.isTopic ? '' : '?reply=${activity.id}';
        context.push(
          forumTopicLocation(
            activity.forumId,
            activity.topicId,
            querySuffix: suffix,
          ),
        );
      },
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              children: [
                CofradeoAvatar(
                  imageUrl: profile.avatarUrl,
                  icon: hermandad ? Icons.church_outlined : Icons.person,
                  size: 36,
                  backgroundColor: AppColors.burgundyDark,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.hermandadName().copyWith(fontSize: 18),
                      ),
                      Text(
                        hermandad
                            ? 'Hermandad · ${activity.timeAgo}'
                            : 'Cofrade · ${activity.placeName} · ${activity.timeAgo}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelSmall(
                          color: hermandad ? AppColors.goldDark : AppColors.textMuted,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (hasCover)
            SizedBox(
              height: 168,
              child: CofradeoNetworkImage(url: cover, fit: BoxFit.cover, cacheSize: 480),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kind.toUpperCase(),
                  style: AppTypography.labelSmall(color: AppColors.goldDark).copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activity.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.newsHeadline().copyWith(fontSize: 20, height: 1.15),
                ),
                if (preview.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    preview,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium().copyWith(height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HermandadLatestCard extends ConsumerWidget {
  const _HermandadLatestCard({required this.group});

  final HermandadDigest group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lead = group.sections.isEmpty ? null : group.sections.first;
    final image = lead?.reply.imageUrl?.trim();
    final hasImage = image != null && image.isNotEmpty;
    final rest = group.sections.skip(1).toList();
    final leadCopy = lead == null ? null : _officialCopy(lead.reply.content);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ColoredBox(
                  color: AppColors.gold,
                  child: SizedBox(width: 3),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
          InkWell(
            onTap: () => pushForumTopic(
              context,
              ref,
              forumId: group.board.forumId,
              topicId: group.board.topicId,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Row(
                children: [
                  _HermandadCrest(
                    name: group.hermandadName,
                    day: group.processionDay,
                    iconImageUrl: group.board.iconImageUrl,
                    size: 38,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.hermandadName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.hermandadName().copyWith(fontSize: 17, height: 1.05),
                        ),
                        Text(
                          'Hermandad · ${lead?.reply.timeAgo ?? group.processionDay ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelSmall(
                            color: AppColors.goldDark,
                          ).copyWith(fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (lead != null)
            InkWell(
              onTap: () => _openSection(context, ref, lead),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Chip(
                      label: officialCategoryLabel(
                        lead.reply.officialCategory ?? 'noticia',
                      ),
                      gold: true,
                    ),
                    if (leadCopy != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        leadCopy.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.newsHeadline().copyWith(
                          fontSize: 20,
                          height: 1.15,
                        ),
                      ),
                      if (leadCopy.body.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          leadCopy.body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMedium().copyWith(height: 1.4),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (hasImage)
            SizedBox(
              height: 210,
              width: double.infinity,
              child: CofradeoNetworkImage(
                url: image,
                fit: BoxFit.cover,
                cacheSize: 720,
              ),
            ),
          for (var i = 0; i < rest.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 14,
                endIndent: 14,
                color: AppColors.border.withValues(alpha: 0.85),
              ),
            _HermandadSectionRow(item: rest[i]),
          ],
        ],
      ),
    );
  }

  void _openSection(BuildContext context, WidgetRef ref, HermandadFeedItem item) {
    final category = item.reply.officialCategory ?? 'noticia';
    prefetchForumTopic(
      ref,
      forumId: item.board.forumId,
      topicId: item.board.topicId,
    );
    final section = hermandadSectionQueryValue(category);
    context.push(
      forumTopicLocation(
        item.board.forumId,
        item.board.topicId,
        querySuffix: '?$hermandadSectionQueryKey=$section&reply=${item.reply.id}',
      ),
    );
  }
}

class _HermandadSectionRow extends ConsumerWidget {
  const _HermandadSectionRow({required this.item});

  final HermandadFeedItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reply = item.reply;
    final title = _officialCopy(reply.content).title;
    final category = reply.officialCategory ?? 'noticia';
    final label = officialCategoryLabel(category);

    return InkWell(
      onTap: () {
        prefetchForumTopic(
          ref,
          forumId: item.board.forumId,
          topicId: item.board.topicId,
        );
        final section = hermandadSectionQueryValue(category);
        context.push(
          forumTopicLocation(
            item.board.forumId,
            item.board.topicId,
            querySuffix: '?$hermandadSectionQueryKey=$section&reply=${reply.id}',
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: AppTypography.labelSmall(
                      color: AppColors.goldDark,
                    ).copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.newsHeadline().copyWith(
                      fontSize: 16,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              reply.timeAgo,
              style: AppTypography.labelSmall(),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _HermandadCrest extends StatelessWidget {
  const _HermandadCrest({
    required this.name,
    required this.day,
    required this.size,
    this.iconImageUrl,
  });

  final String name;
  final String? day;
  final String? iconImageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = hermandadDayAccentColor(day);
    final remote = iconImageUrl?.trim();
    final local = HermandadLocalAssets.avatar(
      processionDay: day,
      hermandadName: name,
    );
    final Widget mark;
    if (remote != null && remote.isNotEmpty) {
      mark = CofradeoNetworkImage(
        url: remote,
        fit: BoxFit.contain,
        width: size,
        height: size,
        cacheSize: size * 2,
      );
    } else if (local != null) {
      mark = CofradeoAssetImage(
        assetPath: local,
        fit: BoxFit.contain,
        cacheWidth: ImageDecodeCache.px(context, size),
      );
    } else {
      mark = Icon(Icons.church_outlined, color: accent, size: size * 0.48);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.75),
          width: size > 32 ? 1.4 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.all(size * 0.08),
      child: mark,
    );
  }
}

({String title, String body}) _officialCopy(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return (title: 'Comunicado oficial', body: '');
  text = text.replaceAllMapped(
    RegExp(r'\*\*(.+?)\*\*', dotAll: true),
    (match) => match.group(1) ?? '',
  );
  text = text.replaceAllMapped(
    RegExp(r'_(.+?)_'),
    (match) => match.group(1) ?? '',
  );
  final lines = text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  if (lines.isEmpty) return (title: 'Comunicado oficial', body: '');
  return (title: lines.first, body: lines.skip(1).join(' '));
}

class _ForumDirectoryCard extends StatelessWidget {
  const _ForumDirectoryCard({
    required this.forum,
    required this.onTap,
  });

  final ForumCategory forum;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cover = forumPillarCover(forum);
    return _SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      radius: 16,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 72,
              height: 72,
              child: ForumPillarCoverImage(
                cover: cover,
                fit: BoxFit.cover,
                alignment: cover.alignment,
                cacheSize: 144,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  forum.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.newsHeadline().copyWith(
                    fontSize: 18,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  forum.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium().copyWith(
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      _forumCount(forum.topicCount, 'tema', 'temas'),
                      style: AppTypography.labelSmall(
                        color: AppColors.burgundy,
                      ).copyWith(fontWeight: FontWeight.w700, fontSize: 11),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Container(
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(
                          color: AppColors.gold,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Text(
                      _forumCount(forum.messageCount, 'mensaje', 'mensajes'),
                      style: AppTypography.labelSmall().copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _forumCount(int count, String singular, String plural) {
  final label = count == 1 ? singular : plural;
  return '${formatCount(count)} $label';
}

class _LatestTopicRow extends StatelessWidget {
  const _LatestTopicRow({
    required this.item,
    required this.onTap,
  });

  final _Activity item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            ForumPillarIconMark(forum: item.forum, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.forum.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall(
                      color: AppColors.goldDark,
                    ).copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.newsHeadline().copyWith(
                      fontSize: 17,
                      height: 1.12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.forum.lastMessageAgo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall(),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.goldDark, size: 20),
          ],
        ),
      ),
    );
  }
}

class _FollowedTopicRow extends StatelessWidget {
  const _FollowedTopicRow({
    required this.topic,
    required this.forumName,
    required this.onTap,
  });

  final FollowedTopic topic;
  final String forumName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final canSlide =
        !topic.isHermandadBoard && !isNoticiasForum(topic.forumId);
    final title = Text(
      topic.title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.newsHeadline().copyWith(
        fontSize: 18,
        height: 1.15,
      ),
    );
    final preview = topic.preview.trim();

    return _SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Row(
        children: [
          Expanded(
            child: canSlide
                ? _ConversationSlide(
                    topicId: topic.topicId,
                    chip: forumName.isEmpty
                        ? const SizedBox.shrink()
                        : Text(
                            forumName.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelSmall(
                              color: AppColors.goldDark,
                            ).copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              fontSize: 10,
                            ),
                          ),
                    post: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        title,
                        if (preview.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            preview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyMedium().copyWith(
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (forumName.isNotEmpty)
                        Text(
                          forumName.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelSmall(
                            color: AppColors.goldDark,
                          ).copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            fontSize: 10,
                          ),
                        ),
                      title,
                      if (preview.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMedium().copyWith(
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.goldDark),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.top = 8,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final double top;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14, top, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTypography.newsHeadline(
                color: AppColors.burgundyDark,
              ).copyWith(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.burgundy,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                actionLabel!,
                style: AppTypography.labelSmall(
                  color: AppColors.burgundy,
                ).copyWith(fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.radius = 18,
  });

  final VoidCallback? onTap;
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: AppColors.gold.withValues(alpha: 0.28),
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.burgundyDark.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
    final body = Ink(
      decoration: decoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Padding(padding: padding, child: child),
      ),
    );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: onTap == null
          ? body
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(radius),
              splashColor: AppColors.burgundy.withValues(alpha: 0.06),
              highlightColor: AppColors.gold.withValues(alpha: 0.05),
              child: body,
            ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    this.gold = false,
  });

  final String label;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final background = gold
        ? AppColors.gold.withValues(alpha: 0.95)
        : AppColors.goldPale.withValues(alpha: 0.55);
    final color = gold ? AppColors.burgundyDark : AppColors.burgundy;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label.toUpperCase(),
          style: AppTypography.labelSmall(color: color).copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 9.5,
            letterSpacing: 0.45,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _PillFilterBar extends StatelessWidget {
  const _PillFilterBar({
    required this.labels,
    required this.icons,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> labels;
  final List<IconData> icons;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: NotificationListener<ScrollNotification>(
        onNotification: (_) => true,
        child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 2, 14, 4),
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == selectedIndex;
          final foreground = selected ? Colors.white : AppColors.textSecondary;
          return Material(
            color: selected ? AppColors.burgundy : AppColors.surfaceAlt,
            elevation: selected ? 1 : 0,
            shadowColor: AppColors.burgundyDark.withValues(alpha: 0.28),
            shape: StadiumBorder(
              side: BorderSide(
                color: selected ? AppColors.burgundyDark : AppColors.border,
              ),
            ),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => onChanged(index),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icons[index],
                        size: 16,
                        color: selected ? AppColors.gold : AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        labels[index],
                        style: AppTypography.bodyMedium(
                          color: foreground,
                        ).copyWith(
                          fontSize: 13,
                          height: 1,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        ),
      ),
    );
  }
}

class _OpenPostButton extends StatelessWidget {
  const _OpenPostButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: AppTypography.labelSmall(
                color: AppColors.burgundy,
              ).copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 0.8,
                height: 1,
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.burgundy,
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedMetric extends StatelessWidget {
  const _FeedMetric({
    required this.icon,
    required this.value,
    this.heat = false,
  });

  final IconData icon;
  final String value;
  final bool heat;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.labelSmall(
      color: AppColors.textSecondary,
    ).copyWith(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        if (heat) ...[
          const SizedBox(width: 2),
          const _PulsingFlame(),
        ],
        const SizedBox(width: 5),
        Text(value, style: style),
      ],
    );
  }
}

class _PulsingFlame extends StatefulWidget {
  const _PulsingFlame();

  @override
  State<_PulsingFlame> createState() => _PulsingFlameState();
}

class _PulsingFlameState extends State<_PulsingFlame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const icon = Icon(
      Icons.local_fire_department,
      size: 15,
      color: AppColors.gold,
    );
    if (MediaQuery.disableAnimationsOf(context)) return icon;
    return ScaleTransition(
      scale: Tween<double>(begin: 0.86, end: 1.08).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: icon,
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 8),
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium().copyWith(height: 1.4),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: AppTypography.bodyMedium(color: AppColors.burgundy)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
