import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/auth_provider.dart';
import '../../auth/email_verification_gate.dart';
import '../../profile/profile_provider.dart';
import '../constants/topic_moderation_copy.dart';
import '../data/forums_repository.dart';
import '../forums_provider.dart';
import 'mention_autocomplete_field.dart';

Future<void> showTopicComposeSheet(
  BuildContext context,
  WidgetRef ref, {
  required String forumId,
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
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return _TopicComposeSheet(forumId: forumId);
    },
  );
}

class _TopicComposeSheet extends ConsumerStatefulWidget {
  const _TopicComposeSheet({required this.forumId});

  final String forumId;

  @override
  ConsumerState<_TopicComposeSheet> createState() => _TopicComposeSheetState();
}

class _TopicComposeSheetState extends ConsumerState<_TopicComposeSheet> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _submitting = false;
  String? _error;

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
          .submit(title: title, body: body);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(TopicModerationCopy.submitSuccess),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Mi perfil',
              onPressed: () => context.go('/perfil'),
            ),
          ),
        );
        context.push('/foros/${widget.forumId}/tema/${topic.id}');
      }
    } on ForumsRemoteUnavailableException {
      setState(() => _error = 'Supabase no disponible.');
    } catch (_) {
      setState(() => _error = 'No se pudo crear el tema.');
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
          Text('Nuevo tema', style: AppTypography.displaySmall()),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Título del tema',
              labelText: 'Título',
            ),
          ),
          const SizedBox(height: 12),
          MentionAutocompleteField(
            controller: _bodyController,
            maxLines: 5,
            minLines: 4,
            hintText: 'Describe tu consulta o noticia… Usa @usuario para mencionar.',
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
                : const Text('Enviar a la Junta'),
          ),
        ],
      ),
    );
  }
}
