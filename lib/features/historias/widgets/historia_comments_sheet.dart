import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/time_ago.dart';
import '../../../core/widgets/cofradeo_avatar.dart';
import '../../auth/auth_provider.dart';
import '../../forums/widgets/forum_compose_sheet_header.dart';
import '../../forums/widgets/forum_compose_sheet_layout.dart';
import '../data/historias_repository.dart';
import '../historias_provider.dart';

Future<void> showHistoriaCommentsSheet(
  BuildContext context, {
  required String historiaId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _HistoriaCommentsSheet(historiaId: historiaId),
  );
}

class _HistoriaCommentsSheet extends ConsumerStatefulWidget {
  const _HistoriaCommentsSheet({required this.historiaId});

  final String historiaId;

  @override
  ConsumerState<_HistoriaCommentsSheet> createState() =>
      _HistoriaCommentsSheetState();
}

class _HistoriaCommentsSheetState
    extends ConsumerState<_HistoriaCommentsSheet> {
  final _body = TextEditingController();
  var _sending = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(historiasRepositoryProvider).addComment(
            historiaId: widget.historiaId,
            body: _body.text,
          );
      _body.clear();
      ref.invalidate(historiaCommentsProvider(widget.historiaId));
      ref.invalidate(historiaByIdProvider(widget.historiaId));
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

  @override
  Widget build(BuildContext context) {
    final comments = ref.watch(historiaCommentsProvider(widget.historiaId));
    final user = ref.watch(currentUserProvider);

    return ForumComposeSheetLayout(
      header: ForumComposeSheetTitleBar(
        title: Text('Comentarios', style: AppTypography.titleLarge()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          comments.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => Text(
              'No se pudieron cargar los comentarios.',
              style: AppTypography.bodyMedium(),
            ),
            data: (items) {
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Sé el primero en comentar esta historia.',
                    style: AppTypography.bodyMedium(),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return Column(
                children: [
                  for (final comment in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CofradeoAvatar(
                            imageUrl: comment.userAvatarUrl,
                            size: 32,
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
                                        ).copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
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
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          if (user != null)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _body,
                    enabled: !_sending,
                    maxLength: 500,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Escribe un comentario…',
                      counterText: '',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send_rounded),
                  color: AppColors.burgundy,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
