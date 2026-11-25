import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/time_ago.dart';
import '../../../core/widgets/cofradeo_avatar.dart';
import '../../auth/auth_provider.dart';
import '../../auth/email_verification_gate.dart';
import '../../permissions/permissions_provider.dart';
import '../data/historias_repository.dart';
import '../historias_provider.dart';
import '../models/historia.dart';

Future<void> showHistoriaCommentsSheet(
  BuildContext context, {
  required String historiaId,
  int commentCount = 0,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CommentsSheetHost(
      historiaId: historiaId,
      commentCount: commentCount,
    ),
  );
}

class _CommentsSheetHost extends StatelessWidget {
  const _CommentsSheetHost({
    required this.historiaId,
    required this.commentCount,
  });

  final String historiaId;
  final int commentCount;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.62,
        minChildSize: 0.42,
        maxChildSize: 0.94,
        builder: (context, scrollController) => _HistoriaCommentsSheet(
          historiaId: historiaId,
          initialCount: commentCount,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

class _HistoriaCommentsSheet extends ConsumerStatefulWidget {
  const _HistoriaCommentsSheet({
    required this.historiaId,
    required this.initialCount,
    required this.scrollController,
  });

  final String historiaId;
  final int initialCount;
  final ScrollController scrollController;

  @override
  ConsumerState<_HistoriaCommentsSheet> createState() =>
      _HistoriaCommentsSheetState();
}

class _HistoriaCommentsSheetState
    extends ConsumerState<_HistoriaCommentsSheet> {
  final _body = TextEditingController();
  final _items = <HistoriaComment>[];
  var _count = 0;
  var _loading = true;
  var _loadingMore = false;
  var _hasMore = true;
  var _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _count = widget.initialCount;
    widget.scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _body.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    final pos = widget.scrollController.position;
    if (pos.pixels > pos.maxScrollExtent - 240) {
      _load(more: true);
    }
  }

  Future<void> _load({bool more = false}) async {
    if (more) {
      if (_loadingMore) return;
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final page = await ref.read(historiasRepositoryProvider).fetchComments(
            widget.historiaId,
            offset: more ? _items.length : 0,
          );
      if (!mounted) return;
      setState(() {
        if (more) {
          _items.addAll(page);
        } else {
          _items
            ..clear()
            ..addAll(page);
        }
        _hasMore = page.length >= HistoriasRepository.commentsPageSize;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = 'No se pudieron cargar los comentarios.';
      });
    }
  }

  Future<void> _send() async {
    if (_sending) return;
    if (!await ensureEmailVerifiedForEngage(context, ref)) return;
    setState(() => _sending = true);
    try {
      final created = await ref.read(historiasRepositoryProvider).addComment(
            historiaId: widget.historiaId,
            body: _body.text,
          );
      _body.clear();
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() {
        _items.insert(0, created);
        _count += 1;
      });
      ref.invalidate(historiaByIdProvider(widget.historiaId));
      ref.invalidate(publishedHistoriasFeedProvider);
      ref.invalidate(publishedHistoriasProvider);
    } on HistoriasValidationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo publicar el comentario')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(HistoriaComment comment) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar comentario?'),
        content: const Text('Se quita de esta obra. No se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(historiasRepositoryProvider).deleteComment(comment.id);
      if (!mounted) return;
      setState(() {
        _items.removeWhere((item) => item.id == comment.id);
        _count = (_count - 1).clamp(0, 999999);
      });
      ref.invalidate(historiaByIdProvider(widget.historiaId));
      ref.invalidate(publishedHistoriasFeedProvider);
      ref.invalidate(publishedHistoriasProvider);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar el comentario')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final title = _count == 1 ? '1 comentario' : '$_count comentarios';

    return Material(
      color: AppColors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTypography.titleLarge()),
                      Text(
                        'Los más recientes primero',
                        style: AppTypography.labelSmall(),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  color: AppColors.burgundy,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _list()),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: user == null
                  ? Text(
                      'Entra en tu cuenta para dejar un comentario.',
                      style: AppTypography.bodyMedium(),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _body,
                            enabled: !_sending,
                            maxLength: 500,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            decoration: InputDecoration(
                              hintText: 'Escribe un comentario…',
                              counterText: '',
                              filled: true,
                              fillColor: AppColors.backgroundElevated,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: _sending ? null : _send,
                          icon: const Icon(Icons.send_rounded),
                          color: AppColors.burgundy,
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _list() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: AppTypography.bodyMedium()),
              TextButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Sé el primero en comentar esta obra.',
            style: AppTypography.bodyMedium(),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final comment = _items[index];
        final canDelete = ref.watch(isAdminProvider);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CofradeoAvatar(
              imageUrl: comment.userAvatarUrl,
              size: 34,
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
                          comment.userDisplayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMedium(
                            color: AppColors.textPrimary,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatTimeAgo(comment.createdAt),
                        style: AppTypography.labelSmall(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    comment.body,
                    style: AppTypography.bodyMedium(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (canDelete)
              IconButton(
                tooltip: 'Eliminar',
                onPressed: () => _delete(comment),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                color: AppColors.textMuted,
                visualDensity: VisualDensity.compact,
              ),
          ],
        );
      },
    );
  }
}
