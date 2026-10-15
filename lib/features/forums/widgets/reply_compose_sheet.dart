import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_upload_compress.dart';
import '../../../core/widgets/cofradeo_avatar.dart';
import '../../auth/auth_provider.dart';
import '../../auth/email_verification_gate.dart';
import '../../permissions/permissions_provider.dart';
import '../../profile/profile_provider.dart';
import '../data/forums_repository.dart';
import '../forums_provider.dart';
import '../hermandad_scheduled_posts_provider.dart';
import '../hermandad_scheduled_posts_screen.dart';
import '../utils/forum_navigation.dart';
import '../utils/official_post_categories.dart';
import '../topic_detail_typography.dart';
import 'forum_compose_field.dart';
import 'forum_compose_sheet_header.dart';
import 'forum_compose_sheet_layout.dart';
import 'hermandad_official_compose_header.dart';
import 'hermandad_official_post_preview.dart';
import 'hermandad_post_image_picker.dart';
import 'hermandad_publish_mode_picker.dart';
import 'official_post_categories_picker.dart';
import 'scheduled_post_datetime_picker.dart';

Future<void> showReplyComposeSheet(
  BuildContext context,
  WidgetRef ref, {
  required String forumId,
  required String topicId,
  String? mentionHandle,
  String? parentReplyId,
  String? initialOfficialCategory,
}) async {
  final isAuth = ref.read(isAuthenticatedProvider);
  if (!isAuth) {
    final redirect = forumTopicLocation(forumId, topicId);
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
          content: Text('Tu cuenta está suspendida. No puedes responder.'),
        ),
      );
    }
    return;
  }

  final userId = ref.read(currentUserProvider)?.id;
  if (userId != null) {
    final banned = await ref.read(
      isForumBannedProvider((userId: userId, forumId: forumId)).future,
    );
    if (banned) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No puedes participar en este foro. Contacta con la moderación si crees que es un error.',
            ),
          ),
        );
      }
      return;
    }
  }

  if (!ref.read(supabaseReadyProvider)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Conecta Supabase (env.json) para publicar respuestas reales.',
          ),
        ),
      );
    }
    return;
  }

  if (forumId == 'noticias') {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Las noticias no admiten comentarios.'),
        ),
      );
    }
    return;
  }

  if (forumId == 'hermandades') {
    final profile = ref.read(currentUserProfileProvider).asData?.value;
    final hermandadTopics = await ref.read(hermandadTopicIdsProvider.future);
    final canPostOfficial = profile?.isAdmin == true ||
        (profile?.isVerified == true &&
            hermandadTopics.contains(topicId));
    if (!canPostOfficial) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Solo la cuenta oficial de la hermandad puede publicar aquí.',
            ),
          ),
        );
      }
      return;
    }
  }

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return _ReplyComposeSheet(
        forumId: forumId,
        topicId: topicId,
        mentionHandle: mentionHandle,
        parentReplyId: parentReplyId,
        initialOfficialCategory: initialOfficialCategory,
      );
    },
  );
}

class _ReplyComposeSheet extends ConsumerStatefulWidget {
  const _ReplyComposeSheet({
    required this.forumId,
    required this.topicId,
    this.mentionHandle,
    this.parentReplyId,
    this.initialOfficialCategory,
  });

  final String forumId;
  final String topicId;
  final String? mentionHandle;
  final String? parentReplyId;
  final String? initialOfficialCategory;

  @override
  ConsumerState<_ReplyComposeSheet> createState() => _ReplyComposeSheetState();
}

class _ReplyComposeSheetState extends ConsumerState<_ReplyComposeSheet> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String _officialCategory = 'noticia';
  String? _error;
  HermandadPublishMode _publishMode = HermandadPublishMode.now;
  late DateTime _scheduledAt;
  Uint8List? _imageBytes;
  String? _imageMime;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _scheduledAt = defaultHermandadScheduleTime();
    final preset = widget.initialOfficialCategory?.trim();
    if (preset != null && preset.isNotEmpty) {
      _officialCategory = preset;
    }
    final handle = widget.mentionHandle;
    if (handle != null && handle.isNotEmpty) {
      final mention = handle.startsWith('@') ? handle : '@$handle';
      _controller.text = '$mention ';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<String?> _resolveImageUrl() async {
    if (_imageBytes == null) return _imageUrl;

    final repo = ref.read(forumsRepositoryProvider);
    return repo.uploadOfficialPostImage(
      topicId: widget.topicId,
      bytes: _imageBytes!,
      mimeType: _imageMime ?? 'image/jpeg',
    );
  }

  Future<void> _submitNow(String text, {String? imageUrl}) async {
    final isOfficial = widget.forumId == 'hermandades' && _canPostOfficialNow();
    await ref
        .read(
          replyControllerProvider(
            ReplyTarget(
              forumId: widget.forumId,
              topicId: widget.topicId,
              parentReplyId: widget.parentReplyId,
              isOfficial: isOfficial,
              officialCategory: isOfficial ? _officialCategory : null,
            ),
          ),
        )
        .submit(text, imageUrl: imageUrl);

    if (mounted) Navigator.pop(context);
  }

  Future<void> _submitDraft(String text, {String? imageUrl}) async {
    await ref.read(hermandadScheduledPostControllerProvider).saveDraft(
          topicId: widget.topicId,
          forumId: widget.forumId,
          content: text,
          officialCategory: _officialCategory,
          imageUrl: imageUrl,
        );

    if (mounted) Navigator.pop(context);
  }

  Future<void> _submitScheduled(String text, {String? imageUrl}) async {
    if (!isValidHermandadScheduleTime(_scheduledAt)) {
      setState(
        () => _error = 'La fecha debe ser al menos 5 minutos en el futuro.',
      );
      return;
    }

    await ref.read(hermandadScheduledPostControllerProvider).schedule(
          topicId: widget.topicId,
          forumId: widget.forumId,
          content: text,
          officialCategory: _officialCategory,
          scheduledAt: _scheduledAt,
          imageUrl: imageUrl,
        );

    if (mounted) Navigator.pop(context);
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    final hasImage = _imageBytes != null || (_imageUrl?.isNotEmpty ?? false);
    if (text.isEmpty && !hasImage) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final isOfficialHermandad =
        widget.forumId == 'hermandades' && _canPostOfficialNow();
    final isScheduled =
        isOfficialHermandad && _publishMode == HermandadPublishMode.scheduled;
    final isDraft =
        isOfficialHermandad && _publishMode == HermandadPublishMode.draft;

    try {
      final imageUrl = isOfficialHermandad ? await _resolveImageUrl() : null;

      if (isDraft) {
        await _submitDraft(text, imageUrl: imageUrl);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Borrador guardado')),
          );
        }
      } else if (isScheduled) {
        await _submitScheduled(text, imageUrl: imageUrl);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Publicación programada')),
          );
        }
      } else {
        await _submitNow(text, imageUrl: imageUrl);
      }
    } on ImageTooLargeAfterCompressException {
      setState(
        () => _error = 'La imagen es demasiado grande incluso tras optimizarla.',
      );
    } on OfficialPostImageTooLargeException {
      setState(() => _error = 'La imagen supera 5 MB.');
    } on ForumsRemoteUnavailableException {
      setState(() => _error = 'Supabase no disponible.');
    } catch (_) {
      setState(
        () => _error = isDraft
            ? 'No se pudo guardar el borrador. ¿Ejecutaste hermandad_scheduled_posts_drafts.sql?'
            : isScheduled
                ? 'No se pudo programar. ¿Ejecutaste hermandad_scheduled_posts.sql?'
                : isOfficialHermandad
                    ? 'No se pudo publicar. ¿Ejecutaste hermandad_official_posts.sql y forum_official_post_images.sql?'
                    : 'No se pudo publicar la respuesta.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool _canPostOfficialNow() {
    final profile = ref.read(currentUserProfileProvider).asData?.value;
    if (profile?.isAdmin == true) return true;
    if (profile?.isVerified != true) return false;
    final topics = ref.read(hermandadTopicIdsProvider).asData?.value;
    return topics?.contains(widget.topicId) ?? false;
  }

  Future<void> _showPreview() async {
    final handle = ref.read(userHandleProvider);
    await showHermandadOfficialPostPreview(
      context,
      content: _controller.text,
      officialCategory: _officialCategory,
      authorHandle: handle,
      imageUrl: _imageUrl,
      imageBytes: _imageBytes,
    );
  }

  Widget _socialSubmitButton({required bool enabled}) {
    return FilledButton(
      onPressed: (_submitting || !enabled) ? null : _submit,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.burgundy,
        disabledBackgroundColor: AppColors.burgundy.withValues(alpha: 0.35),
        foregroundColor: AppColors.textOnDark,
        disabledForegroundColor: AppColors.textOnDark.withValues(alpha: 0.85),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: const Size(0, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const StadiumBorder(),
        textStyle: AppTypography.buttonLabel().copyWith(fontSize: 12.5),
      ),
      child: _submitting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.textOnDark,
              ),
            )
          : const Text('Responder'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHermandadBoard = widget.forumId == 'hermandades';
    final canPostOfficial = _canPostOfficialNow();
    final useRichEditor = isHermandadBoard && canPostOfficial;
    final isScheduled =
        isHermandadBoard &&
        canPostOfficial &&
        _publishMode == HermandadPublishMode.scheduled;
    final socialReply = !useRichEditor;
    final profile = ref.watch(currentUserProfileProvider).asData?.value;

    return ForumComposeSheetLayout(
      padding: socialReply
          ? const EdgeInsets.fromLTRB(14, 0, 12, 0)
          : const EdgeInsets.fromLTRB(20, 0, 12, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (useRichEditor)
            HermandadOfficialComposeHeader(closeEnabled: !_submitting)
          else
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                final canSubmit = value.text.trim().isNotEmpty;
                return Row(
                  children: [
                    ForumComposeSheetCloseButton(enabled: !_submitting),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.parentReplyId != null
                            ? 'Responder'
                            : 'Nueva respuesta',
                        style: TopicDetailTypography.meta(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ).copyWith(fontSize: 13),
                      ),
                    ),
                    _socialSubmitButton(enabled: canSubmit),
                  ],
                );
              },
            ),
          SizedBox(height: socialReply ? 6 : 10),
          if (useRichEditor) ...[
            OfficialPostCategoriesPicker(
              category: _officialCategory,
              onCategoryChanged: (value) {
                setState(() => _officialCategory = value);
              },
            ),
            const SizedBox(height: 10),
            HermandadPublishModePicker(
              mode: _publishMode,
              onChanged: (value) => setState(() => _publishMode = value),
            ),
            if (isScheduled) ...[
              const SizedBox(height: 8),
              ScheduledPostDatetimePicker(
                scheduledAt: _scheduledAt,
                onChanged: (value) => setState(() => _scheduledAt = value),
              ),
            ],
            const SizedBox(height: 10),
            HermandadPostImagePicker(
              enabled: !_submitting,
              onChanged: ({bytes, mimeType, existingUrl}) {
                setState(() {
                  _imageBytes = bytes;
                  _imageMime = mimeType;
                  _imageUrl = existingUrl;
                });
              },
            ),
            const SizedBox(height: 10),
          ],
          if (socialReply)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (profile != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: CofradeoAvatar(
                      imageUrl: profile.avatarUrl,
                      icon: profile.avatarIcon,
                      size: 34,
                      backgroundColor: AppColors.backgroundElevated,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: ForumComposeField(
                    controller: _controller,
                    maxLines: 4,
                    minLines: 3,
                    dense: true,
                    showHintCaption: false,
                    toolbar: ForumComposeToolbar.standard,
                    hintText: widget.parentReplyId != null
                        ? 'Escribe tu respuesta…'
                        : '¿Qué opinas?',
                  ),
                ),
              ],
            )
          else
            ForumComposeField(
              controller: _controller,
              maxLines: 8,
              minLines: 6,
              toolbar: ForumComposeToolbar.editorial,
              hintText: 'Redacta la noticia o comunicado oficial…',
            ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: AppTypography.bodyMedium(color: AppColors.accentRed),
            ),
          ],
          if (useRichEditor) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _submitting ? null : _showPreview,
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: const Text('Vista previa'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.burgundy,
                side: BorderSide(color: AppColors.gold.withValues(alpha: 0.35)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
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
                  : Text(_submitButtonLabel(isHermandadBoard, canPostOfficial)),
            ),
          ],
        ],
      ),
    );
  }

  String _submitButtonLabel(bool isHermandadBoard, bool canPostOfficial) {
    if (!isHermandadBoard || !canPostOfficial) return 'Publicar respuesta';
    return switch (_publishMode) {
      HermandadPublishMode.draft => 'Guardar borrador',
      HermandadPublishMode.scheduled =>
        'Programar en ${officialCategoryLabel(_officialCategory)}',
      HermandadPublishMode.now =>
        'Publicar en ${officialCategoryLabel(_officialCategory)}',
    };
  }
}
