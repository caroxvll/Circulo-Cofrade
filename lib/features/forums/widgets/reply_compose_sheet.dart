import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/auth_provider.dart';
import '../../auth/email_verification_gate.dart';
import '../../profile/profile_provider.dart';
import '../data/forums_repository.dart';
import '../forums_provider.dart';
import 'mention_autocomplete_field.dart';

Future<void> showReplyComposeSheet(
  BuildContext context,
  WidgetRef ref, {
  required String forumId,
  required String topicId,
  String? mentionHandle,
  String? parentReplyId,
}) async {
  final isAuth = ref.read(isAuthenticatedProvider);
  if (!isAuth) {
    final redirect = '/foros/$forumId/tema/$topicId';
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

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return _ReplyComposeSheet(
        forumId: forumId,
        topicId: topicId,
        mentionHandle: mentionHandle,
        parentReplyId: parentReplyId,
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
  });

  final String forumId;
  final String topicId;
  final String? mentionHandle;
  final String? parentReplyId;

  @override
  ConsumerState<_ReplyComposeSheet> createState() =>
      _ReplyComposeSheetState();
}

class _ReplyComposeSheetState extends ConsumerState<_ReplyComposeSheet> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
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

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref
          .read(
            replyControllerProvider(
              ReplyTarget(
                forumId: widget.forumId,
                topicId: widget.topicId,
                parentReplyId: widget.parentReplyId,
              ),
            ),
          )
          .submit(text);

      if (mounted) Navigator.pop(context);
    } on ForumsRemoteUnavailableException {
      setState(() => _error = 'Supabase no disponible.');
    } catch (_) {
      setState(() => _error = 'No se pudo publicar la respuesta.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Escribe una respuesta', style: AppTypography.displaySmall()),
          const SizedBox(height: 12),
          MentionAutocompleteField(
            controller: _controller,
            hintText: 'Comparte tu opinión… Usa @usuario o #hashtag',
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
                : const Text('Publicar respuesta'),
          ),
        ],
      ),
    );
  }
}
