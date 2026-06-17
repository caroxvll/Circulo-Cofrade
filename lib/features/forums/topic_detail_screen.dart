import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';



import '../../core/theme/app_colors.dart';

import '../../core/theme/app_typography.dart';

import '../../core/utils/text_normalize.dart';

import '../../core/widgets/calendar_quick_access_button.dart';

import '../../core/widgets/cofradeo_avatar.dart';

import '../../core/widgets/cofradeo_badge.dart';

import '../../core/widgets/mention_rich_text.dart';

import '../../shared/models/forum.dart';
import '../auth/auth_provider.dart';
import '../auth/email_verification_gate.dart';
import '../admin/admin_provider.dart';
import '../profile/profile_provider.dart';
import '../profile/widgets/suspended_account_banner.dart';
import '../moderation/widgets/report_content_dialog.dart';
import 'data/mock_forums.dart';
import 'data/reply_likes_repository.dart';
import 'data/reply_moderation_exception.dart';
import 'forums_provider.dart';
import 'topic_replies_provider.dart';
import 'utils/reply_permissions.dart';
import 'widgets/reply_card.dart';
import 'widgets/reply_edit_sheet.dart';

import 'utils/forum_navigation.dart';
import 'utils/reply_tree.dart';

import 'widgets/replies_load_more_button.dart';

import 'widgets/reply_compose_sheet.dart';

import 'widgets/topic_follow_button.dart';
import 'widgets/topic_moderation_banner.dart';



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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToHighlightedReply() {
    final replyId = widget.highlightReplyId;
    if (replyId == null || replyId.isEmpty || _didScrollToReply) return;

    final key = _replyAnchorKeys[replyId.toLowerCase()];
    final targetContext = key?.currentContext;
    if (targetContext == null) return;

    _didScrollToReply = true;
    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
      alignment: 0.2,
    );
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
    if (user.id == ref.read(forumTopicProvider(_topicKey)).asData?.value?.authorId) {
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
    return user != null &&
        user.id != reply.authorId &&
        !reply.isDeleted;
  }

  ReplyManageOptions? _manageOptionsFor(
    ForumReply reply,
    List<ForumReply> allReplies,
  ) {
    if (!ref.read(supabaseReadyProvider)) return null;

    final userId = ref.read(currentUserProvider)?.id;
    final isStaff = ref.read(isStaffProvider);
    final hasChildren = replyHasChildReplies(reply, allReplies);
    final canEdit = canAuthorEditReply(
      reply,
      userId,
      hasChildReplies: hasChildren,
    );
    final canDelete = canAuthorDeleteReply(reply, userId) ||
        canStaffDeleteReply(reply, isStaff);

    if (!canEdit && !canDelete) return null;

    return ReplyManageOptions(
      canEdit: canEdit,
      canDelete: canDelete,
      onEdit: canEdit ? () => _editReply(reply) : null,
      onDelete: canDelete ? () => _deleteReply(reply) : null,
    );
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
            content: Text('Comentario eliminado. Queda registrado para moderación.'),
          ),
        );
      }
    } on ReplyModerationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.userMessage)),
        );
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

    final forum = ref.watch(forumPillarProvider(widget.forumId)).asData?.value ??

        (supabaseReady ? null : forumById(widget.forumId));

    final topicAsync = ref.watch(forumTopicProvider(topicKey));

    final topic = topicAsync.asData?.value ??

        (supabaseReady ? null : topicById(widget.forumId, widget.topicId));

    final repliesState = ref.watch(topicRepliesStateProvider(widget.topicId));

    final likedIdsAsync = ref.watch(likedReplyIdsProvider(widget.topicId));

    if (supabaseReady && topic != null && topic.isPublished) {

      ref.watch(topicViewTrackerProvider(topicKey));

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

      error: (_, __) => topic.viewCount,

    );



    final likedIds = likedIdsAsync.asData?.value ?? {};

    final showPublishedConfirmation =
        GoRouterState.of(context).uri.queryParameters['aprobado'] == '1';

    if (widget.highlightReplyId != null && topic.isPublished) {
      ref.listen(topicRepliesStateProvider(widget.topicId), (previous, next) {
        if (!next.isLoading && next.replies.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scrollToHighlightedReply();
          });
        }
      });
    }



    Future<void> onLike(ForumReply reply) async {

      if (!supabaseReady) {

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(

            content: Text('Conecta Supabase para usar me gusta.'),

          ),

        );

        return;

      }



      final user = ref.read(currentUserProvider);

      if (user == null) {

        await context.push(

          '/login?redirect=${Uri.encodeComponent('/foros/${widget.forumId}/tema/${widget.topicId}')}',

        );

        return;

      }

      if (!await ensureEmailVerifiedForEngage(context, ref)) return;

      if (ref.read(isCurrentUserSuspendedProvider)) {
        final liked = likedIds.contains(reply.id.toLowerCase());
        if (!liked) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Tu cuenta está suspendida. No puedes dar me gusta.',
                ),
              ),
            );
          }
          return;
        }
      }



      try {

        await ref.read(replyLikesRepositoryProvider).toggleLike(

              userId: user.id,

              replyId: reply.id,

              currentlyLiked: likedIds.contains(reply.id.toLowerCase()),

            );

        await refreshTopicReplies(ref, widget.topicId);

        ref.invalidate(likedReplyIdsProvider(widget.topicId));

      } on ReplyLikesUnavailableException {

        if (context.mounted) {

          ScaffoldMessenger.of(context).showSnackBar(

            const SnackBar(content: Text('No se pudo guardar el me gusta.')),

          );

        }

      } catch (_) {

        if (context.mounted) {

          ScaffoldMessenger.of(context).showSnackBar(

            const SnackBar(

              content: Text(

                'No se pudo guardar el me gusta. ¿Ejecutaste reply_likes_and_moderation.sql?',

              ),

            ),

          );

        }

      }

    }



    Widget buildRepliesSection() {

      if (!topic.isPublished) {

        return Text(

          topic.isPending

              ? 'Las respuestas se abrirán cuando la Junta apruebe el tema.'

              : 'Este tema no admite respuestas.',

          style: AppTypography.bodyMedium(color: AppColors.textMuted),

        );

      }



      if (!supabaseReady) {

        return ReplyThreadList(

          nodes: buildReplyTree(repliesForTopic(widget.topicId)),

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

          showReport: _canReportReply,

          onReportTap: _reportReply,

          manageOptionsFor: (r) => _manageOptionsFor(
            r,
            repliesForTopic(widget.topicId),
          ),

        );

      }



      final page = repliesState;

      if (page.isLoading) {

        return const Padding(

          padding: EdgeInsets.symmetric(vertical: 24),

          child: Center(child: CircularProgressIndicator()),

        );

      }



      if (page.replies.isEmpty) {

        return Text(

          'Sé el primero en responder.',

          style: AppTypography.bodyMedium(color: AppColors.textMuted),

        );

      }



      return Column(

        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [

          ReplyThreadList(

            nodes: buildReplyTree(page.replies),

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

            isLiked: (r) => likedIds.contains(r.id.toLowerCase()),

            onLikeTap: onLike,

            showReport: _canReportReply,

            onReportTap: _reportReply,

            manageOptionsFor: (r) => _manageOptionsFor(r, page.replies),

          ),

          RepliesLoadMoreButton(

            loadedCount: page.replies.length,

            totalCount: topic.commentCount,

            isLoading: page.isLoadingMore,

            hasMore: page.hasMore,

            onLoadMore: () => loadMoreTopicReplies(ref, widget.topicId),

          ),

        ],

      );

    }



    final isSuspended = ref.watch(isCurrentUserSuspendedProvider);
    final canReply = topic.isPublished && !isSuspended;



    return Scaffold(

      backgroundColor: AppColors.background,

      appBar: AppBar(

        leading: IconButton(

          onPressed: _onBack,

          icon: const Icon(Icons.chevron_left, color: AppColors.burgundy),

        ),

        title: Text(

          forum?.name ?? 'Foro',

          style: AppTypography.displaySmall().copyWith(fontSize: 16),

        ),

        centerTitle: true,

        actions: [

          if (ref.watch(currentUserProvider) != null &&
              ref.watch(currentUserProvider)!.id != topic.authorId)
            IconButton(
              onPressed: _reportTopic,
              icon: const Icon(Icons.flag_outlined, color: AppColors.burgundy),
              tooltip: 'Reportar tema',
            ),

          const CalendarQuickAccessButton(),

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

              child: ListView(

                controller: _scrollController,

                physics: const AlwaysScrollableScrollPhysics(),

                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),

                children: [

                  TopicModerationBanner(

                    status: topic.status,

                    showPublishedConfirmation: showPublishedConfirmation,

                  ),

                  Text(

                    topic.title,

                    style: AppTypography.displaySmall(

                      color: AppColors.textPrimary,

                    ).copyWith(fontSize: 22, height: 1.25),

                  ),

                  if (topic.isPublished) ...[
                    const SizedBox(height: 12),
                    TopicFollowButton(
                      forumId: widget.forumId,
                      topicId: widget.topicId,
                    ),
                  ],

                  const SizedBox(height: 16),

                  Row(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      CofradeoAvatar(

                        imageUrl: topic.authorAvatarUrl,

                        icon: topic.avatarIcon,

                        size: 44,

                        backgroundColor: AppColors.backgroundElevated,

                      ),

                      const SizedBox(width: 12),

                      Expanded(

                        child: InkWell(

                          onTap: topic.authorId != null

                              ? () => context.push(

                                    '/perfil/usuario/${topic.authorId}',

                                  )

                              : null,

                          child: Column(

                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [

                              Text(

                                topic.authorHandle,

                                style: AppTypography.titleLarge().copyWith(

                                  fontSize: 15,

                                  color: topic.authorId != null

                                      ? AppColors.burgundy

                                      : null,

                                ),

                              ),

                              Text(

                                topic.timeAgo,

                                style: AppTypography.bodyMedium(

                                  color: AppColors.accentRed,

                                ),

                              ),

                            ],

                          ),

                        ),

                      ),

                    ],

                  ),

                  const SizedBox(height: 16),

                  MentionRichText(

                    text: normalizeStoredText(topic.body),

                    style: AppTypography.bodyLarge().copyWith(height: 1.55),

                  ),

                  const SizedBox(height: 16),

                  Row(

                    children: [

                      Icon(Icons.chat_bubble_outline,

                          size: 16, color: AppColors.textMuted),

                      const SizedBox(width: 4),

                      Text(

                        '$displayCommentCount',

                        style: AppTypography.labelSmall(),

                      ),

                      const SizedBox(width: 16),

                      Icon(Icons.visibility_outlined,

                          size: 16, color: AppColors.textMuted),

                      const SizedBox(width: 4),

                      Text(

                        '${formatCount(displayViewCount)} vistas',

                        style: AppTypography.labelSmall(),

                      ),

                      const Spacer(),

                      if (topic.isResolved)

                        const CofradeoBadge(label: 'Resuelto'),

                    ],

                  ),

                  const SizedBox(height: 20),

                  Container(height: 2, color: AppColors.burgundy),

                  const SizedBox(height: 24),

                  Text('Respuestas', style: AppTypography.displaySmall()),

                  if (topic.isPublished && displayCommentCount > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      displayCommentCount == 1
                          ? '1 respuesta · más recientes primero'
                          : '$displayCommentCount respuestas · más recientes primero',
                      style: AppTypography.labelSmall(color: AppColors.textMuted),
                    ),
                  ],

                  const SizedBox(height: 16),

                  buildRepliesSection(),

                ],

              ),

            ),

          ),

          if (topic.isPublished && isSuspended)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: SuspendedAccountBanner(compact: true),
            ),

          if (canReply) _ReplyInputBar(onTap: _onReplyTap),

        ],

      ),

    );

  }

}



class _ReplyInputBar extends StatelessWidget {

  const _ReplyInputBar({required this.onTap});



  final VoidCallback onTap;



  @override

  Widget build(BuildContext context) {

    return Material(

      color: AppColors.surface,

      elevation: 8,

      child: SafeArea(

        top: false,

        child: Padding(

          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),

          child: Row(

            children: [

              Expanded(

                child: GestureDetector(

                  onTap: onTap,

                  child: Container(

                    padding: const EdgeInsets.symmetric(

                      horizontal: 16,

                      vertical: 12,

                    ),

                    decoration: BoxDecoration(

                      color: AppColors.backgroundElevated,

                      borderRadius: BorderRadius.circular(24),

                      border: Border.all(color: AppColors.border),

                    ),

                    child: Text(

                      'Escribe una respuesta…',

                      style: AppTypography.bodyMedium(

                        color: AppColors.textMuted,

                      ),

                    ),

                  ),

                ),

              ),

              const SizedBox(width: 8),

              IconButton.filled(

                onPressed: onTap,

                icon: const Icon(Icons.send_rounded, size: 20),

                style: IconButton.styleFrom(

                  backgroundColor: AppColors.burgundy,

                  foregroundColor: AppColors.textOnDark,

                ),

              ),

            ],

          ),

        ),

      ),

    );

  }

}


