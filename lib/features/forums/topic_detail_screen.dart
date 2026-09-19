import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';

import '../../core/theme/app_typography.dart';

import '../../core/utils/forum_share_urls.dart';
import '../../core/utils/forum_text_format.dart';
import '../../core/widgets/calendar_quick_access_button.dart';
import '../../core/widgets/cofradeo_avatar.dart';

import '../../shared/models/forum.dart';
import '../ads/models/sponsored_ad.dart';
import '../ads/utils/featured_topic_ads.dart';
import '../ads/widgets/sponsored_ad_card.dart';
import '../ads/widgets/sponsored_placement_slot.dart';
import '../auth/auth_provider.dart';
import '../auth/email_verification_gate.dart';
import '../permissions/permissions_provider.dart';
import '../profile/profile_provider.dart';
import '../profile/widgets/suspended_account_banner.dart';
import '../moderation/widgets/report_content_dialog.dart';
import 'data/hermandad_board_tab_store.dart';
import 'data/mock_forums.dart';
import 'data/reply_likes_repository.dart';
import 'data/reply_moderation_exception.dart';
import 'forums_provider.dart';
import 'topic_replies_provider.dart';
import 'hermandad_scheduled_posts_provider.dart';
import 'utils/hermandad_board_display.dart';
import 'utils/official_post_categories.dart';
import 'utils/reply_reactions.dart';
import 'utils/reply_permissions.dart';
import 'utils/topic_permissions.dart';
import 'widgets/hermandad_board_tabs_header.dart';
import 'widgets/hermandad_board_category_tabs.dart';
import 'widgets/hermandad_official_edit_sheet.dart';
import 'widgets/hermandad_official_confirm_dialogs.dart';
import 'widgets/hermandad_pinned_post_header.dart';
import 'widgets/hermandad_pending_posts_banner.dart';
import 'widgets/reply_card.dart';
import 'widgets/reply_edit_sheet.dart';

import 'utils/forum_navigation.dart';
import 'utils/reply_tree.dart';
import 'utils/season_hub_context.dart';

import 'widgets/replies_load_more_button.dart';

import 'widgets/reply_compose_sheet.dart';

import 'widgets/topic_edit_sheet.dart';
import 'widgets/topic_moderation_banner.dart';
import 'widgets/topic_moderation_sheet.dart';
import 'topic_detail_typography.dart';
import 'widgets/topic_detail_header.dart';
import 'widgets/topic_status_badge.dart';

class TopicDetailScreen extends ConsumerStatefulWidget {
  const TopicDetailScreen({
    super.key,

    required this.forumId,

    required this.topicId,

    this.highlightReplyId,
  });

  final String forumId;

  final String topicId;

  final String? highlightReplyId;

  @override
  ConsumerState<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends ConsumerState<TopicDetailScreen> {
  final _scrollController = ScrollController();
  final _replyAnchorKeys = <String, GlobalKey>{};
  var _didScrollToReply = false;
  var _didPublishDueHermandadPosts = false;
  String? _hermandadCategoryFilter;

  @override
  void initState() {
    super.initState();
    if (widget.forumId == 'hermandades') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didPublishDueHermandadPosts) return;
        _didPublishDueHermandadPosts = true;
        ensureHermandadDuePostsPublished(
          ref,
          topicId: widget.topicId,
          forumId: widget.forumId,
        );
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _initHermandadBoardTab();
      });
    }
  }

  Future<void> _initHermandadBoardTab() async {
    final params = GoRouterState.of(context).uri.queryParameters;
    final String? filter;
    if (params.containsKey(hermandadSectionQueryKey)) {
      filter = parseHermandadSectionQuery(params[hermandadSectionQueryKey]);
    } else {
      filter = await HermandadBoardTabStore.load(widget.topicId);
    }
    if (!mounted || _hermandadCategoryFilter == filter) return;
    setState(() => _hermandadCategoryFilter = filter);
  }

  void _syncHermandadSectionInUrl(String? category) {
    final state = GoRouterState.of(context);
    final params = Map<String, String>.from(state.uri.queryParameters);
    if (category == null) {
      params.remove(hermandadSectionQueryKey);
    } else {
      params[hermandadSectionQueryKey] = hermandadSectionQueryValue(category);
    }
    final path = '/foros/${widget.forumId}/tema/${widget.topicId}';
    final nextUri = Uri(
      path: path,
      queryParameters: params.isEmpty ? null : params,
    );
    if (nextUri.toString() == state.uri.toString()) return;
    context.replace(nextUri.toString());
  }

  void _onHermandadCategorySelected(String? value) {
    setState(() => _hermandadCategoryFilter = value);
    HermandadBoardTabStore.save(widget.topicId, value);
    _syncHermandadSectionInUrl(value);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToHighlightedReply({List<ForumReply>? replies}) {
    final replyId = widget.highlightReplyId;
    if (replyId == null || replyId.isEmpty || _didScrollToReply) return;

    final nodes = replies == null
        ? null
        : buildReplyTree(
            widget.forumId == 'hermandades'
                ? _boardFeedReplies(
                    replies,
                    excludePinned: _pinnedHermandadReply(replies),
                  )
                : filterVisibleReplies(replies),
          );
    _scrollToReply(replyId, nodes: nodes);
    _didScrollToReply = true;
  }

  void _alignSectionForHighlightedReply(List<ForumReply> replies) {
    final replyId = widget.highlightReplyId;
    if (replyId == null ||
        replyId.isEmpty ||
        widget.forumId != 'hermandades') {
      return;
    }

    final params = GoRouterState.of(context).uri.queryParameters;
    if (params.containsKey(hermandadSectionQueryKey)) return;

    final normalized = replyId.toLowerCase();
    ForumReply? target;
    for (final reply in replies) {
      if (reply.id.toLowerCase() == normalized) {
        target = reply;
        break;
      }
    }
    final category = target?.officialCategory;
    if (category == null || _hermandadCategoryFilter == category) return;

    setState(() => _hermandadCategoryFilter = category);
    HermandadBoardTabStore.save(widget.topicId, category);
    _syncHermandadSectionInUrl(category);
  }

  void _scrollToReply(String replyId, {List<ReplyTreeNode>? nodes}) {
    final normalized = replyId.toLowerCase();
    final rootIndex =
        nodes == null ? null : indexOfReplyRoot(nodes, normalized);

    void attempt(int n) {
      if (!mounted) return;
      final targetContext = _replyAnchorKeys[normalized]?.currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration: n == 0
              ? const Duration(milliseconds: 450)
              : const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          alignment: 0.12,
        );
        return;
      }
      if (n >= 18) return;

      // Con lista virtualizada el ítem puede no estar montado: acercamos el scroll.
      if (rootIndex != null && _scrollController.hasClients) {
        final max = _scrollController.position.maxScrollExtent;
        final estimated = (320.0 + rootIndex * 210.0).clamp(0.0, max);
        if (n == 0 || n == 2 || n == 5 || n == 9) {
          _scrollController.jumpTo(estimated);
        }
      }

      WidgetsBinding.instance.addPostFrameCallback((_) => attempt(n + 1));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => attempt(0));
  }

  ForumTopicKey get _topicKey =>
      ForumTopicKey(forumId: widget.forumId, topicId: widget.topicId);

  void _onBack() => popForumTopic(context, forumId: widget.forumId);

  void _onReplyTap() {
    showReplyComposeSheet(
      context,
      ref,
      forumId: widget.forumId,
      topicId: widget.topicId,
      initialOfficialCategory: _hermandadCategoryFilter,
    );
  }

  Future<void> _reportTopic() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      await context.push(
        '/login?redirect=${Uri.encodeComponent('/foros/${widget.forumId}/tema/${widget.topicId}')}',
      );
      return;
    }
    if (user.id ==
        ref.read(forumTopicProvider(_topicKey)).asData?.value?.authorId) {
      return;
    }
    await submitContentReport(
      context: context,
      ref: ref,
      reporterId: user.id,
      targetType: 'topic',
      targetId: widget.topicId,
      dialogTitle: 'Reportar tema',
    );
  }

  Future<void> _reportReply(ForumReply reply) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      await context.push(
        '/login?redirect=${Uri.encodeComponent('/foros/${widget.forumId}/tema/${widget.topicId}')}',
      );
      return;
    }
    if (user.id == reply.authorId) return;
    await submitContentReport(
      context: context,
      ref: ref,
      reporterId: user.id,
      targetType: 'reply',
      targetId: reply.id,
      dialogTitle: 'Reportar respuesta',
    );
  }

  bool _canReportReply(ForumReply reply) {
    final user = ref.read(currentUserProvider);
    return user != null && user.id != reply.authorId && !reply.isDeleted;
  }

  bool _canModerateCurrentForum() {
    final isAdmin = ref.read(isAdminProvider);
    final moderatedForums =
        ref.read(moderatedForumIdsProvider).asData?.value ?? {};
    return canModerateForum(
      forumId: widget.forumId,
      isAdmin: isAdmin,
      moderatedForumIds: moderatedForums,
    );
  }

  Future<void> _banReplyAuthorFromForum(ForumReply reply) async {
    final authorId = reply.authorId;
    if (authorId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Expulsar a ${reply.authorHandle}?'),
        content: const Text(
          'No podrá participar en este foro. No es una suspensión global de la app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Expulsar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(permissionsRepositoryProvider).banFromForum(
            profileId: authorId,
            forumId: widget.forumId,
            reason: 'Expulsión desde moderación de respuesta',
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${reply.authorHandle} expulsado del foro')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo expulsar del foro')),
        );
      }
    }
  }

  ReplyManageOptions? _manageOptionsFor(
    ForumReply reply,
    List<ForumReply> allReplies,
    ForumTopic topic,
  ) {
    if (!ref.read(supabaseReadyProvider)) return null;

    final userId = ref.read(currentUserProvider)?.id;
    final profile = ref.read(currentUserProfileProvider).asData?.value;
    final hermandadTopics =
        ref.read(hermandadTopicIdsProvider).asData?.value ?? {};
    final isHermandadBoard = widget.forumId == 'hermandades';
    final canModerate = _canModerateCurrentForum();
    final hasChildren = replyHasChildReplies(reply, allReplies);
    final canEditOfficial = isHermandadBoard &&
        reply.isOfficial &&
        canEditOfficialHermandadPost(
          reply: reply,
          topicId: widget.topicId,
          userId: userId,
          isAdmin: profile?.isAdmin == true,
          isVerified: profile?.isVerified == true,
          hermandadTopicIds: hermandadTopics,
        );
    final canEdit = canEditOfficial ||
        canAuthorEditReply(
          reply,
          userId,
          hasChildReplies: hasChildren,
        );
    final canDelete = canAuthorDeleteReply(reply, userId) ||
        canForumModeratorDeleteReply(reply: reply, canModerate: canModerate);
    final canFeature = canFeatureReply(
      topic: topic,
      reply: reply,
      userId: userId,
      isAdmin: profile?.isAdmin == true,
      isVerified: profile?.isVerified == true,
      hermandadTopicIds: hermandadTopics,
    );
    final canBan = canModerate &&
        reply.authorId != null &&
        reply.authorId != userId &&
        !reply.isDeleted;

    if (!canEdit && !canDelete && !canFeature && !canBan) return null;

    return ReplyManageOptions(
      canEdit: canEdit,
      canDelete: canDelete,
      canFeature: canFeature,
      isFeatured: reply.isFeatured,
      pinOfficialStyle: isHermandadBoard && reply.isOfficial,
      canBanFromForum: canBan,
      onEdit: canEdit
          ? () => canEditOfficial
              ? showHermandadOfficialEditSheet(
                  context,
                  ref,
                  forumId: widget.forumId,
                  topicId: widget.topicId,
                  reply: reply,
                )
              : _editReply(reply)
          : null,
      onDelete: canDelete ? () => _deleteReply(reply) : null,
      onToggleFeature: canFeature ? () => _toggleFeatured(reply) : null,
      onBanFromForum: canBan ? () => _banReplyAuthorFromForum(reply) : null,
    );
  }

  Future<void> _toggleFeatured(ForumReply reply) async {
    final isOfficialPin =
        widget.forumId == 'hermandades' && reply.isOfficial;

    if (isOfficialPin) {
      if (reply.isFeatured) {
        final ok = await confirmUnpinOfficialPost(context);
        if (!ok || !mounted) return;
      } else {
        final ok = await confirmPinOfficialPost(context);
        if (!ok || !mounted) return;
      }
    }

    try {
      await ref.read(forumsRepositoryProvider).setReplyFeatured(
            replyId: reply.id,
            featured: !reply.isFeatured,
            officialHermandadPin: isOfficialPin,
          );
      await refreshTopicReplies(ref, widget.topicId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isOfficialPin
                  ? reply.isFeatured
                      ? 'Comunicado ya no está fijado'
                      : 'Comunicado fijado arriba del tablón'
                  : reply.isFeatured
                      ? 'Respuesta ya no está destacada'
                      : 'Respuesta destacada',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isOfficialPin
                  ? 'No se pudo fijar. ¿Ejecutaste hermandad_official_edit.sql?'
                  : 'No se pudo destacar la respuesta',
            ),
          ),
        );
      }
    }
  }

  Future<void> _requestTopicClose(ForumTopic topic) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Solicitar cierre del hilo?'),
        content: const Text(
          'La Junta revisará tu solicitud. Si se aprueba, el tema quedará cerrado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enviar solicitud'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(forumsRepositoryProvider).requestTopicClose(topic.id);
      invalidateTopicData(
        ref,
        forumId: widget.forumId,
        topicId: widget.topicId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud de cierre enviada a la Junta')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo enviar. ¿Ejecutaste roles_v2.sql?'),
          ),
        );
      }
    }
  }

  Future<void> _editReply(ForumReply reply) async {
    await showReplyEditSheet(
      context,
      ref,
      forumId: widget.forumId,
      topicId: widget.topicId,
      reply: reply,
    );
  }

  Future<void> _deleteReply(ForumReply reply) async {
    final confirmed = await confirmSoftDeleteReply(context);
    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(
            replyEditControllerProvider(
              ReplyEditTarget(
                forumId: widget.forumId,
                topicId: widget.topicId,
                replyId: reply.id,
              ),
            ),
          )
          .softDelete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Comentario eliminado. Queda registrado para moderación.',
            ),
          ),
        );
      }
    } on ReplyModerationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.userMessage)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo eliminar. ¿Ejecutaste forum_reply_edit_delete.sql?',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topicKey = _topicKey;

    final supabaseReady = ref.watch(supabaseReadyProvider);

    final forum =
        ref.watch(forumPillarProvider(widget.forumId)).asData?.value ??
        (supabaseReady ? null : forumById(widget.forumId));

    final topicAsync = ref.watch(forumTopicProvider(topicKey));

    final topic =
        topicAsync.asData?.value ??
        (supabaseReady ? null : topicById(widget.forumId, widget.topicId));

    final repliesState = ref.watch(topicRepliesStateProvider(widget.topicId));

    final userReactionsAsync =
        ref.watch(replyUserReactionsProvider(widget.topicId));
    final reactionCountsAsync =
        ref.watch(replyReactionCountsProvider(widget.topicId));

    if (supabaseReady) {
      ref.watch(topicThreadRealtimeProvider(topicKey));
    }

    if (supabaseReady && topic != null && topic.isPublished) {
      ref.watch(topicViewTrackerProvider(topicKey));
      ref.watch(topicReplyReactionsRealtimeProvider(widget.topicId));
    }

    if (topic == null) {
      if (supabaseReady && topicAsync.isLoading) {
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              onPressed: _onBack,

              icon: const Icon(Icons.chevron_left),
            ),

            title: const Text('Foro'),
          ),

          body: const Center(child: CircularProgressIndicator()),
        );
      }

      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _onBack,

            icon: const Icon(Icons.chevron_left),
          ),

          title: const Text('Foro'),
        ),

        body: Center(
          child: Text('Tema no encontrado', style: AppTypography.bodyLarge()),
        ),
      );
    }

    final displayCommentCount = topic.commentCount;

    final displayViewCount = topicAsync.when(
      data: (t) => t?.viewCount ?? topic.viewCount,

      loading: () => topic.viewCount,

      error: (_, _) => topic.viewCount,
    );

    final userReactions = userReactionsAsync.value ?? const <String, String>{};
    final reactionCountsByReply =
        reactionCountsAsync.value ?? const <String, Map<String, int>>{};

    final showPublishedConfirmation =
        GoRouterState.of(context).uri.queryParameters['aprobado'] == '1';

    if (widget.highlightReplyId != null && topic.isPublished) {
      ref.listen(topicRepliesStateProvider(widget.topicId), (previous, next) {
        if (!next.isLoading && next.replies.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _alignSectionForHighlightedReply(next.replies);
            _scrollToHighlightedReply(replies: next.replies);
          });
        }
      });
    }

    Future<void> onReaction(ForumReply reply, String? reaction) async {
      if (!supabaseReady) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Conecta Supabase para reaccionar.')),
          );
        }
        throw const ReplyReactionCancelled();
      }

      final user = ref.read(currentUserProvider);
      if (user == null) {
        await context.push(
          '/login?redirect=${Uri.encodeComponent('/foros/${widget.forumId}/tema/${widget.topicId}')}',
        );
        throw const ReplyReactionCancelled();
      }

      if (!await ensureEmailVerifiedForEngage(context, ref)) {
        throw const ReplyReactionCancelled();
      }

      if (ref.read(isCurrentUserSuspendedProvider) && reaction != null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Tu cuenta está suspendida. No puedes reaccionar.',
              ),
            ),
          );
        }
        throw const ReplyReactionCancelled();
      }

      try {
        await ref.read(replyLikesRepositoryProvider).setReaction(
              userId: user.id,
              replyId: reply.id,
              reaction: reaction,
              topicId: widget.topicId,
            );
        // Optimistic + realtime; invalidar vaciaba contadores y parecía fallar.
      } on ReplyLikesUnavailableException {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo guardar la reacción.')),
          );
        }
        rethrow;
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(replyReactionSaveErrorMessage(e))),
          );
        }
        rethrow;
      }
    }

    final isHermandadBoard = widget.forumId == 'hermandades';
    final allBoardReplies = supabaseReady
        ? repliesState.replies
        : repliesForTopic(widget.topicId);
    final pinnedHermandadReply = isHermandadBoard
        ? _pinnedHermandadReply(allBoardReplies)
        : null;
    final filteredBoardReplies = _boardFeedReplies(
      allBoardReplies,
      excludePinned: pinnedHermandadReply,
    );
    final officialCategoryCounts = isHermandadBoard
        ? _officialCategoryCounts(allBoardReplies)
        : const <String, int>{};
    final boardOfficialReplyIds = isHermandadBoard
        ? allBoardReplies
            .where((r) => r.isOfficial && !r.isDeleted)
            .map((r) => r.id)
        : const Iterable<String>.empty();
    final threadReplyIds = allBoardReplies
        .where((r) => !r.isDeleted)
        .map((r) => r.id);
    final boardTotalReactions = isHermandadBoard
        ? sumReplyReactionTotals(reactionCountsByReply, boardOfficialReplyIds)
        : sumReplyReactionTotals(reactionCountsByReply, threadReplyIds);
    final boardReactionBreakdown = isHermandadBoard
        ? mergeReactionCounts(
            boardOfficialReplyIds.map(
              (id) => reactionCountsByReply[id.toLowerCase()] ?? const {},
            ),
          )
        : mergeReactionCounts(
            threadReplyIds.map(
              (id) => reactionCountsByReply[id.toLowerCase()] ?? const {},
            ),
          );

    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final hermandadTopics =
        ref.watch(hermandadTopicIdsProvider).asData?.value ?? {};
    final canPublishOfficial = profile?.isAdmin == true ||
        (profile?.isVerified == true &&
            hermandadTopics.contains(widget.topicId));
    final pendingForTopic = canPublishOfficial && isHermandadBoard
        ? ref.watch(myHermandadPendingPostsProvider).asData?.value
        : null;
    final pendingDraftCount = pendingForTopic?.drafts
            .where((p) => p.topicId == widget.topicId)
            .length ??
        0;
    final pendingScheduledCount = pendingForTopic?.scheduled
            .where((p) => p.topicId == widget.topicId)
            .length ??
        0;

    ReplyThreadList buildReplyThreadList(
      List<ForumReply> replies, {
      required List<ForumReply> manageContext,
      bool sliver = false,
    }) {
      return ReplyThreadList(
        sliver: sliver,
        nodes: buildReplyTree(replies),
        topicAuthorId: topic.authorId,
        highlightReplyId: widget.highlightReplyId,
        replyAnchorKeys: _replyAnchorKeys,
        onAuthorTap: (r) {
          if (r.authorId != null) {
            context.push('/perfil/usuario/${r.authorId}');
          }
        },
        onReplyTap: (r) => showReplyComposeSheet(
          context,
          ref,
          forumId: widget.forumId,
          topicId: widget.topicId,
          mentionHandle: r.authorHandle,
          parentReplyId: r.id,
        ),
        reactionCountsFor: (r) {
          final fromDb = reactionCountsByReply[r.id.toLowerCase()];
          if (fromDb != null && fromDb.isNotEmpty) {
            return normalizeReactionCounts(fromDb);
          }
          if (r.likeCount > 0) return {'❤️': r.likeCount};
          return const {};
        },
        userReactionFor: (r) => userReactions[r.id.toLowerCase()],
        onReactionChanged: onReaction,
        showReport: _canReportReply,
        onReportTap: _reportReply,
        onShareTap: topic.isPublished
            ? (r) => shareForumReplyLink(
                  context,
                  forumId: widget.forumId,
                  topicId: widget.topicId,
                  replyId: r.id,
                  section: r.officialCategory,
                  excerpt: plainTextForExcerpt(r.content, maxLength: 90),
                  authorHandle: r.authorHandle,
                )
            : null,
        manageOptionsFor: (r) => _manageOptionsFor(r, manageContext, topic),
      );
    }

    final repliesPadding = EdgeInsets.fromLTRB(
      16,
      isHermandadBoard ? 4 : 8,
      16,
      16,
    );

    List<Widget> buildRepliesSlivers() {
      SliverPadding statusSliver(Widget child) {
        return SliverPadding(
          padding: repliesPadding,
          sliver: SliverToBoxAdapter(child: child),
        );
      }

      if (!topic.isPublished) {
        return [
          statusSliver(
            Text(
              topic.isPending
                  ? 'Las respuestas se abrirán cuando la Junta apruebe el tema.'
                  : 'Este tema no admite respuestas.',
              style: AppTypography.bodyMedium(color: AppColors.textMuted),
            ),
          ),
        ];
      }

      if (!supabaseReady) {
        final replies = filteredBoardReplies;
        if (isHermandadBoard &&
            replies.isEmpty &&
            pinnedHermandadReply == null) {
          return [
            statusSliver(
              _HermandadBoardEmptyState(category: _hermandadCategoryFilter),
            ),
          ];
        }
        if (replies.isEmpty) {
          return const [SliverToBoxAdapter(child: SizedBox.shrink())];
        }
        return [
          SliverPadding(
            padding: repliesPadding,
            sliver: buildReplyThreadList(
              replies,
              manageContext: _visibleRepliesForBoard(allBoardReplies),
              sliver: true,
            ),
          ),
        ];
      }

      final page = repliesState;

      if (page.isLoading) {
        return [
          statusSliver(
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ];
      }

      final visibleReplies = filteredBoardReplies;

      if (visibleReplies.isEmpty) {
        if (isHermandadBoard) {
          if (pinnedHermandadReply != null) {
            return const [SliverToBoxAdapter(child: SizedBox.shrink())];
          }
          return [
            statusSliver(
              _HermandadBoardEmptyState(category: _hermandadCategoryFilter),
            ),
          ];
        }

        return [
          statusSliver(
            Text(
              'Sé el primero en responder.',
              style: AppTypography.bodyMedium(color: AppColors.textMuted),
            ),
          ),
        ];
      }

      return [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            16,
            isHermandadBoard ? 4 : 8,
            16,
            0,
          ),
          sliver: buildReplyThreadList(
            visibleReplies,
            manageContext: _visibleRepliesForBoard(page.replies),
            sliver: true,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverToBoxAdapter(
            child: RepliesLoadMoreButton(
              loadedCount: visibleReplies.length,
              totalCount: topic.commentCount,
              isLoading: page.isLoadingMore,
              hasMore: page.hasMore,
              onLoadMore: () => loadMoreTopicReplies(ref, widget.topicId),
            ),
          ),
        ),
      ];
    }

    final isSuspended = ref.watch(isCurrentUserSuspendedProvider);
    final userId = profile?.id;
    final forumBanAsync = userId == null
        ? null
        : ref.watch(
            isForumBannedProvider((userId: userId, forumId: widget.forumId)),
          );
    final isForumBanned = forumBanAsync?.asData?.value ?? false;
    final canReply =
        topic.acceptsReplies &&
        !isSuspended &&
        !isForumBanned &&
        (!isHermandadBoard || canPublishOfficial);

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        leading: IconButton(
          onPressed: _onBack,

          icon: const Icon(Icons.chevron_left, color: AppColors.burgundy),
        ),

        title: _TopicDetailAppBarTitle(
          isHermandadBoard: isHermandadBoard,
          topic: topic,
          forumName: forum?.name,
        ),

        centerTitle: true,

        actions: [
          if (topic.isPublished)
            IconButton(
              onPressed: () => shareForumTopicLink(
                context,
                forumId: widget.forumId,
                topicId: widget.topicId,
                label: isHermandadBoard
                    ? parseHermandadTopicTitle(topic.title).hermandadName
                    : topic.title,
              ),
              icon: const Icon(Icons.share_outlined, color: AppColors.burgundy),
              tooltip: 'Compartir',
            ),
          const CalendarQuickAccessButton(),
          _TopicDetailOverflowMenu(
            isHermandadBoard: isHermandadBoard,
            canPublishOfficial: canPublishOfficial,
            canEditTopic: canEditTopicAsOwner(
              topic,
              ref.read(currentUserProvider)?.id,
            ),
            canModerate: _canModerateCurrentForum() && topic.isPublished,
            canRequestClose: canRequestTopicClose(
              topic,
              ref.read(currentUserProvider)?.id,
            ),
            canReport: ref.watch(currentUserProvider) != null &&
                ref.watch(currentUserProvider)!.id != topic.authorId,
            onScheduledPosts: () =>
                context.push('/perfil/publicaciones-programadas'),
            onEditTopic: () => showTopicEditSheet(
              context,
              ref,
              forumId: widget.forumId,
              topic: topic,
            ),
            onModerate: () => showTopicModerationSheet(
              context,
              ref,
              forumId: widget.forumId,
              topic: topic,
            ),
            onRequestClose: () => _requestTopicClose(topic),
            onReport: _reportTopic,
          ),
          const SizedBox(width: 4),
        ],
      ),

      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                invalidateTopicData(
                  ref,

                  forumId: widget.forumId,

                  topicId: widget.topicId,
                );

                await ref.read(forumTopicProvider(topicKey).future);

                if (topic.isPublished) {
                  await refreshTopicReplies(ref, widget.topicId);
                }
              },

              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (isHermandadBoard) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                              child: Column(
                                children: [
                                  TopicModerationBanner(
                                    status: topic.status,
                                    showPublishedConfirmation:
                                        showPublishedConfirmation,
                                  ),
                                  if (topic.isCloseRequested) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.backgroundElevated,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      child: Text(
                                        'Cierre solicitado — la Junta está revisando este hilo.',
                                        style: TopicDetailTypography.meta(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (topic.isClosed) ...[
                                    const SizedBox(height: 10),
                                    TopicClosedBanner(topic: topic),
                                  ],
                                  if (canPublishOfficial)
                                    HermandadPendingPostsBanner(
                                      draftCount: pendingDraftCount,
                                      scheduledCount: pendingScheduledCount,
                                    ),
                                ],
                              ),
                            ),
                            TopicDetailHeader(
                              topic: topic,
                              forumId: widget.forumId,
                              topicId: widget.topicId,
                              isHermandadBoard: isHermandadBoard,
                              displayCommentCount: displayCommentCount,
                              displayViewCount: displayViewCount,
                              displayTotalReactions: boardTotalReactions,
                              reactionBreakdown: boardReactionBreakdown,
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ] else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          TopicModerationBanner(
                            status: topic.status,
                            showPublishedConfirmation:
                                showPublishedConfirmation,
                          ),
                          if (topic.isCloseRequested) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.backgroundElevated,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                'Cierre solicitado — la Junta está revisando este hilo.',
                                style: TopicDetailTypography.meta(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                          if (topic.isClosed) ...[
                            const SizedBox(height: 10),
                            TopicClosedBanner(topic: topic),
                          ],
                        ]),
                      ),
                    ),
                  if (!isHermandadBoard)
                    SliverToBoxAdapter(
                      child: TopicDetailHeader(
                        topic: topic,
                        forumId: widget.forumId,
                        topicId: widget.topicId,
                        isHermandadBoard: isHermandadBoard,
                        displayCommentCount: displayCommentCount,
                        displayViewCount: displayViewCount,
                        displayTotalReactions: boardTotalReactions,
                        reactionBreakdown: boardReactionBreakdown,
                      ),
                    ),
                  if (!isHermandadBoard && topicAcceptsFeaturedAds(topic))
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: SponsoredPlacementSlot(
                          placement: AdPlacement.featuredTopic,
                          topicId: widget.topicId,
                          style: SponsoredAdCardStyle.banner,
                          compact: true,
                          sectionLabel: 'Publicidad',
                        ),
                      ),
                    ),
                  if (!isHermandadBoard)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: TopicDetailRepliesHeader(
                          isHermandadBoard: false,
                          commentCount: displayCommentCount,
                        ),
                      ),
                    ),
                  if (isHermandadBoard)
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: HermandadBoardTabsDelegate(
                        selected: _hermandadCategoryFilter,
                        counts: officialCategoryCounts,
                        onSelected: _onHermandadCategorySelected,
                        boardSubtitle: hermandadBoardSectionSubtitle(
                          selectedCategory: _hermandadCategoryFilter,
                          visibleCount:
                              _visibleRepliesForBoard(allBoardReplies).length,
                        ),
                      ),
                    ),
                  if (isHermandadBoard && pinnedHermandadReply != null)
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: HermandadPinnedPostDelegate(
                        reply: pinnedHermandadReply,
                        onTap: () => _scrollToReply(pinnedHermandadReply.id),
                      ),
                    ),
                  if (isHermandadBoard && pinnedHermandadReply != null)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: buildReplyThreadList(
                          [pinnedHermandadReply],
                          manageContext: _visibleRepliesForBoard(allBoardReplies),
                        ),
                      ),
                    ),
                  ...buildRepliesSlivers(),
                ],
              ),
            ),
          ),

          if (topic.isPublished && isSuspended)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: SuspendedAccountBanner(compact: true),
            ),

          if (topic.isPublished && isForumBanned && !isSuspended)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.backgroundElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accentRed),
                ),
                child: Text(
                  'No puedes participar en este foro.',
                  style: AppTypography.bodyMedium(color: AppColors.accentRed),
                ),
              ),
            ),

          if (canReply)
            _ReplyInputBar(
              onTap: _onReplyTap,
              hint: isHermandadBoard
                  ? 'Publicar información oficial…'
                  : 'Escribe una respuesta…',
            ),
        ],
      ),
    );
  }

  ForumReply? _pinnedHermandadReply(List<ForumReply> replies) {
    if (widget.forumId != 'hermandades') return null;
    for (final reply in _visibleRepliesForBoard(replies)) {
      if (reply.isFeatured && !reply.isDeleted) return reply;
    }
    return null;
  }

  List<ForumReply> _boardFeedReplies(
    List<ForumReply> replies, {
    ForumReply? excludePinned,
  }) {
    final visible = _visibleRepliesForBoard(replies);
    if (excludePinned == null) return visible;
    final pinnedId = excludePinned.id.toLowerCase();
    return [
      for (final reply in visible)
        if (reply.id.toLowerCase() != pinnedId) reply,
    ];
  }

  List<ForumReply> _officialReplies(List<ForumReply> replies) {
    return [
      for (final reply in replies)
        if (reply.isOfficial) reply,
    ];
  }

  Map<String, int> _officialCategoryCounts(List<ForumReply> replies) {
    final counts = <String, int>{};
    for (final reply in _officialReplies(replies)) {
      final category = reply.officialCategory;
      if (category == null) continue;
      counts[category] = (counts[category] ?? 0) + 1;
    }
    return counts;
  }

  List<ForumReply> _visibleRepliesForBoard(List<ForumReply> replies) {
    if (widget.forumId != 'hermandades') return replies;

    final official = _officialReplies(replies);
    final filter = _hermandadCategoryFilter;
    if (filter == null) {
      official.sort(_compareOfficialReplies);
      return official;
    }

    final filtered = [
      for (final reply in official)
        if (reply.officialCategory == filter) reply,
    ];
    filtered.sort(_compareOfficialReplies);
    return filtered;
  }

  int _compareOfficialReplies(ForumReply a, ForumReply b) {
    if (a.isFeatured != b.isFeatured) {
      return a.isFeatured ? -1 : 1;
    }
    final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bTime.compareTo(aTime);
  }
}

class _TopicDetailAppBarTitle extends StatelessWidget {
  const _TopicDetailAppBarTitle({
    required this.isHermandadBoard,
    required this.topic,
    required this.forumName,
  });

  final bool isHermandadBoard;
  final ForumTopic topic;
  final String? forumName;

  @override
  Widget build(BuildContext context) {
    if (isHermandadBoard) {
      return Text(
        parseHermandadTopicTitle(topic.title).hermandadName,
        style: TopicDetailTypography.appBarTitle(),
      );
    }

    final season = seasonHubLabel(topic.seasonKey);
    if (season != null && isSeasonCommunityTopicDetail(topic)) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            season,
            style: TopicDetailTypography.appBarTitle(),
          ),
          Text(
            'Tema · ${forumName ?? 'Foro'}',
            style: TopicDetailTypography.meta(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 11, height: 1.1),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    return Text(
      forumName ?? 'Foro',
      style: TopicDetailTypography.appBarTitle(),
    );
  }
}

class _HermandadBoardEmptyState extends StatelessWidget {
  const _HermandadBoardEmptyState({this.category});

  final String? category;

  @override
  Widget build(BuildContext context) {
    final section = category == null
        ? 'ninguna sección'
        : officialCategoryLabel(category!);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.goldPale.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            child: Icon(
              category == null
                  ? Icons.campaign_outlined
                  : officialPostCategories
                      .firstWhere(
                        (item) => item.value == category,
                        orElse: () => officialPostCategories.first,
                      )
                      .icon,
              color: AppColors.burgundy,
              size: 22,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            category == null
                ? 'Aún no hay información oficial'
                : 'Sin publicaciones en $section',
            style: AppTypography.titleLarge().copyWith(fontSize: 15),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            category == null
                ? 'Cuando la hermandad publique noticias, cultos, actos o patrimonio aparecerán aquí.'
                : 'Prueba otra pestaña o publica la primera entrada en esta sección.',
            style: AppTypography.bodyMedium(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ReplyInputBar extends ConsumerWidget {
  const _ReplyInputBar({required this.onTap, required this.hint});

  final VoidCallback onTap;
  final String hint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).asData?.value;

    return Material(
      color: AppColors.surface,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              children: [
                if (profile != null) ...[
                  CofradeoAvatar(
                    imageUrl: profile.avatarUrl,
                    icon: profile.avatarIcon,
                    size: 32,
                    backgroundColor: AppColors.backgroundElevated,
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: GestureDetector(
                    onTap: onTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundElevated,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        hint,
                        style: TopicDetailTypography.meta(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: AppColors.burgundy,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: onTap,
                    customBorder: const CircleBorder(),
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.send_rounded,
                        size: 18,
                        color: AppColors.textOnDark,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _TopicOverflowAction {
  scheduledPosts,
  editTopic,
  moderate,
  requestClose,
  report,
}

class _TopicDetailOverflowMenu extends StatelessWidget {
  const _TopicDetailOverflowMenu({
    required this.isHermandadBoard,
    required this.canPublishOfficial,
    required this.canEditTopic,
    required this.canModerate,
    required this.canRequestClose,
    required this.canReport,
    required this.onScheduledPosts,
    required this.onEditTopic,
    required this.onModerate,
    required this.onRequestClose,
    required this.onReport,
  });

  final bool isHermandadBoard;
  final bool canPublishOfficial;
  final bool canEditTopic;
  final bool canModerate;
  final bool canRequestClose;
  final bool canReport;
  final VoidCallback onScheduledPosts;
  final VoidCallback onEditTopic;
  final VoidCallback onModerate;
  final VoidCallback onRequestClose;
  final VoidCallback onReport;

  bool get _hasItems =>
      (isHermandadBoard && canPublishOfficial) ||
      canEditTopic ||
      canModerate ||
      canRequestClose ||
      canReport;

  @override
  Widget build(BuildContext context) {
    if (!_hasItems) return const SizedBox.shrink();

    return PopupMenuButton<_TopicOverflowAction>(
      icon: const Icon(Icons.more_vert, color: AppColors.burgundy),
      tooltip: 'Más opciones',
      onSelected: (action) {
        switch (action) {
          case _TopicOverflowAction.scheduledPosts:
            onScheduledPosts();
          case _TopicOverflowAction.editTopic:
            onEditTopic();
          case _TopicOverflowAction.moderate:
            onModerate();
          case _TopicOverflowAction.requestClose:
            onRequestClose();
          case _TopicOverflowAction.report:
            onReport();
        }
      },
      itemBuilder: (context) => [
        if (isHermandadBoard && canPublishOfficial)
          const PopupMenuItem(
            value: _TopicOverflowAction.scheduledPosts,
            child: Text('Borradores y programadas'),
          ),
        if (canEditTopic)
          const PopupMenuItem(
            value: _TopicOverflowAction.editTopic,
            child: Text('Editar tema'),
          ),
        if (canModerate)
          const PopupMenuItem(
            value: _TopicOverflowAction.moderate,
            child: Text('Moderar tema'),
          ),
        if (canRequestClose)
          const PopupMenuItem(
            value: _TopicOverflowAction.requestClose,
            child: Text('Solicitar cierre del hilo'),
          ),
        if (canReport)
          const PopupMenuItem(
            value: _TopicOverflowAction.report,
            child: Text('Reportar tema'),
          ),
      ],
    );
  }
}
