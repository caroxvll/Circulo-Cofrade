import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/auth_provider.dart';
import '../../auth/email_verification_gate.dart';
import '../../permissions/permissions_provider.dart';
import '../../profile/profile_provider.dart';
import '../constants/topic_moderation_copy.dart';
import '../data/forums_repository.dart';
import '../data/mock_forums.dart';
import '../forums_provider.dart';
import '../topic_detail_typography.dart';
import '../utils/noticias_forum.dart';
import '../utils/topic_list_order.dart';
import '../utils/topic_permissions.dart';
import '../../../shared/models/forum.dart';
import 'forum_compose_field.dart';
import 'forum_compose_sheet_header.dart';
import 'forum_compose_sheet_layout.dart';
import 'hermandad_post_image_picker.dart';

Future<void> showTopicComposeSheet(
  BuildContext context,
  WidgetRef ref, {
  required String forumId,
  String? seasonKey,
}) async {
  final isAuth = ref.read(isAuthenticatedProvider);
  if (!isAuth) {
    final redirect = '/foros/$forumId';
    if (context.mounted) {
      await context.push('/login?redirect=${Uri.encodeComponent(redirect)}');
    }
    return;
  }

  if (!await ensureEmailVerifiedForEngage(context, ref)) return;

  if (ref.read(isCurrentUserSuspendedProvider)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu cuenta está suspendida. No puedes crear temas.'),
        ),
      );
    }
    return;
  }

  final isAdmin = ref.read(isAdminProvider);
  final moderatedForumIds =
      ref.read(moderatedForumIdsProvider).asData?.value ?? const <String>{};
  if (!canCreateTopicInForum(
    forumId: forumId,
    isAdmin: isAdmin,
    moderatedForumIds: moderatedForumIds,
  )) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNoticiasForum(forumId)
                ? 'Solo la Junta puede publicar noticias.'
                : 'No puedes crear temas en este foro.',
          ),
        ),
      );
    }
    return;
  }

  if (!ref.read(supabaseReadyProvider)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Conecta Supabase (env.json) para crear temas reales.',
          ),
        ),
      );
    }
    return;
  }

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return _TopicComposeSheet(forumId: forumId, seasonKey: seasonKey);
    },
  );
}

class _TopicComposeSheet extends ConsumerStatefulWidget {
  const _TopicComposeSheet({
    required this.forumId,
    this.seasonKey,
  });

  final String forumId;
  final String? seasonKey;

  @override
  ConsumerState<_TopicComposeSheet> createState() => _TopicComposeSheetState();
}

class _TopicComposeSheetState extends ConsumerState<_TopicComposeSheet> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  Uint8List? _coverBytes;
  String? _coverMimeType;
  String? _relatedForumId;
  bool _submitting = false;
  String? _error;

  bool get _isHermandades => widget.forumId == 'hermandades';
  bool get _isNoticias => isNoticiasForum(widget.forumId);

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.length < 5) {
      setState(() => _error = 'El título debe tener al menos 5 caracteres.');
      return;
    }
    if (body.length < 10) {
      setState(() => _error = 'El mensaje debe tener al menos 10 caracteres.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final topic = await ref
          .read(topicControllerProvider(widget.forumId))
          .submit(
            title: title,
            body: body,
            seasonKey: widget.seasonKey,
            coverBytes: _coverBytes,
            coverMimeType: _coverMimeType,
            relatedForumId: _relatedForumId,
          );

      if (mounted) {
        Navigator.pop(context);
        final isAdmin = ref.read(isAdminProvider);
        final publishedNow = _isNoticias && isAdmin && topic.isPublished;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              publishedNow
                  ? 'Noticia publicada. Los cofrades ya pueden leerla y opinar.'
                  : TopicModerationCopy.submitSuccess,
            ),
            duration: const Duration(seconds: 6),
            action: publishedNow
                ? null
                : SnackBarAction(
                    label: 'Mi perfil',
                    onPressed: () => context.go('/perfil'),
                  ),
          ),
        );
        context.push('/foros/${widget.forumId}/tema/${topic.id}');
      }
    } on ForumsRemoteUnavailableException {
      setState(() => _error = 'Supabase no disponible.');
    } on TopicCoverTooLargeException {
      setState(
        () => _error =
            'La imagen es demasiado grande. Prueba con otra más ligera.',
      );
    } on NoticiasStaffRequiredException {
      setState(() => _error = 'Solo la Junta puede publicar noticias.');
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('solo la junta puede publicar noticias')) {
        setState(() => _error = 'Solo la Junta puede publicar noticias.');
      } else if (message.contains('related') ||
          message.contains('asoci')) {
        setState(
          () => _error =
              'No se pudo asociar el foro. ¿Ejecutaste noticias_related_forum.sql?',
        );
      } else {
        setState(() => _error = 'No se pudo crear el tema.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  List<ForumCategory> _relatedForumOptions() {
    final pillars = ref.watch(forumPillarsProvider).asData?.value;
    final source = pillars == null
        ? mockForumCategories
        : visibleForumPillars(pillars);
    final byId = {for (final f in source) f.id: f};
    return [
      for (final id in noticiasRelatedForumIds)
        if (byId[id] != null) byId[id]!,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final publishDirect = _isNoticias && isAdmin;
    final relatedOptions = _isNoticias ? _relatedForumOptions() : const <ForumCategory>[];

    return ForumComposeSheetLayout(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ForumComposeSheetTitleBar(
            closeEnabled: !_submitting,
            title: Text(
              _isNoticias ? 'Nueva noticia' : 'Nuevo tema',
              style: TopicDetailTypography.title(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: _isNoticias
                  ? 'Titular de la noticia'
                  : 'Título del tema',
              labelText: 'Título',
            ),
          ),
          const SizedBox(height: 12),
          ForumComposeField(
            controller: _bodyController,
            maxLines: 8,
            minLines: 5,
            toolbar: _isHermandades || _isNoticias
                ? ForumComposeToolbar.editorial
                : ForumComposeToolbar.standard,
            hintText: _isNoticias
                ? 'Redacta la noticia con párrafos claros…'
                : _isHermandades
                    ? 'Redacta la publicación oficial con párrafos claros…'
                    : 'Redacta tu mensaje con párrafos claros…',
          ),
          if (_isNoticias && relatedOptions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'RELACIONADO CON',
              style: AppTypography.labelSmall(
                color: AppColors.textMuted,
              ).copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Opcional · etiqueta el foro del tema (no crea un hilo nuevo)',
              style: AppTypography.bodyMedium(
                color: AppColors.textMuted,
              ).copyWith(fontSize: 12.5, height: 1.25),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Ninguno'),
                  selected: _relatedForumId == null,
                  onSelected: _submitting
                      ? null
                      : (_) => setState(() => _relatedForumId = null),
                  selectedColor: AppColors.burgundy.withValues(alpha: 0.14),
                  labelStyle: AppTypography.labelSmall(
                    color: _relatedForumId == null
                        ? AppColors.burgundyDark
                        : AppColors.textSecondary,
                  ).copyWith(fontWeight: FontWeight.w600),
                  side: BorderSide(
                    color: _relatedForumId == null
                        ? AppColors.burgundy.withValues(alpha: 0.35)
                        : AppColors.border,
                  ),
                  showCheckmark: false,
                ),
                for (final forum in relatedOptions)
                  ChoiceChip(
                    label: Text(forum.name),
                    selected: _relatedForumId == forum.id,
                    onSelected: _submitting
                        ? null
                        : (selected) => setState(
                              () => _relatedForumId =
                                  selected ? forum.id : null,
                            ),
                    selectedColor: AppColors.burgundy.withValues(alpha: 0.14),
                    labelStyle: AppTypography.labelSmall(
                      color: _relatedForumId == forum.id
                          ? AppColors.burgundyDark
                          : AppColors.textSecondary,
                    ).copyWith(fontWeight: FontWeight.w600),
                    side: BorderSide(
                      color: _relatedForumId == forum.id
                          ? AppColors.burgundy.withValues(alpha: 0.35)
                          : AppColors.border,
                    ),
                    showCheckmark: false,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          HermandadPostImagePicker(
            enabled: !_submitting,
            sectionTitle: 'PORTADA',
            sectionSubtitle: _isNoticias
                ? 'Opcional · foto o cartel de la noticia'
                : 'Opcional · cartel, foto…',
            maxBytes: ForumsRepository.maxTopicCoverBytes,
            onChanged: ({bytes, mimeType, existingUrl}) {
              setState(() {
                _coverBytes = bytes;
                _coverMimeType = mimeType;
              });
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: AppTypography.bodyMedium(color: AppColors.accentRed),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.burgundy,
              foregroundColor: AppColors.textOnDark,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    publishDirect ? 'Publicar noticia' : 'Enviar a la Junta',
                  ),
          ),
        ],
      ),
    );
  }
}
