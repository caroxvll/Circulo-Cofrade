import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../forums/forums_provider.dart';
import '../../permissions/data/permissions_repository.dart';
import '../../permissions/permissions_provider.dart';
import '../admin_provider.dart';
import '../junta_ui.dart';
import 'junta_handle_search_field.dart';

class JuntaModeratorsTab extends ConsumerStatefulWidget {
  const JuntaModeratorsTab({super.key});

  @override
  ConsumerState<JuntaModeratorsTab> createState() => _JuntaModeratorsTabState();
}

class _JuntaModeratorsTabState extends ConsumerState<JuntaModeratorsTab> {
  final _handleController = TextEditingController();
  ProfileHandleSearchHit? _selectedProfile;
  String? _selectedForumId;
  var _assigning = false;

  @override
  void dispose() {
    _handleController.dispose();
    super.dispose();
  }

  Future<void> _assign() async {
    final forumId = _selectedForumId;
    if (forumId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un foro')),
      );
      return;
    }

    setState(() => _assigning = true);
    try {
      final profileId = _selectedProfile?.id ??
          await ref.read(permissionsRepositoryProvider).fetchProfileIdByHandle(
                _handleController.text,
              );

      if (profileId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selecciona un cofrade de la lista o escribe un handle válido'),
            ),
          );
        }
        return;
      }

      await ref.read(permissionsRepositoryProvider).assignForumModerator(
            profileId: profileId,
            forumId: forumId,
          );
      ref.invalidate(forumModeratorAssignmentsProvider);
      ref.invalidate(moderatedForumIdsProvider);
      ref.invalidate(forumAboutModeratorsProvider(forumId));
      final assignedHandle = _selectedProfile?.handleLabel ??
          '@${_handleController.text.trim().replaceFirst('@', '')}';
      _handleController.clear();
      setState(() => _selectedProfile = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$assignedHandle asignado como moderador')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo asignar. ¿Ejecutaste roles_v2.sql?',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  Future<void> _remove(ForumModeratorAssignment assignment) async {
    try {
      await ref.read(permissionsRepositoryProvider).removeForumModerator(
            profileId: assignment.profileId,
            forumId: assignment.forumId,
          );
      ref.invalidate(forumModeratorAssignmentsProvider);
      ref.invalidate(moderatedForumIdsProvider);
      ref.invalidate(forumAboutModeratorsProvider(assignment.forumId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo quitar la asignación')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pillarsAsync = ref.watch(adminPillarsProvider);
    final assignmentsAsync = ref.watch(forumModeratorAssignmentsProvider);

    return ListView(
      padding: JuntaUi.listPadding,
      children: [
        const JuntaSectionHeader(
          title: 'Asignar moderador',
          subtitle:
              'Puedes asignar varios cofrades al mismo foro. '
              'Cada handle solo puede moderar una vez ese foro.',
        ),
        const SizedBox(height: 10),
        JuntaHandleSearchField(
          controller: _handleController,
          labelText: 'Handle del cofrade',
          hintText: '@usuario',
          onSelected: (profile) => setState(() => _selectedProfile = profile),
        ),
        const SizedBox(height: 10),
        pillarsAsync.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (_, _) => Text('No se pudieron cargar los foros', style: JuntaUi.body()),
          data: (pillars) => DropdownButtonFormField<String>(
            initialValue: _selectedForumId,
            style: JuntaUi.body(color: AppColors.textPrimary),
            decoration: JuntaUi.inputDecoration(labelText: 'Foro'),
            items: [
              for (final pillar in pillars)
                DropdownMenuItem(
                  value: pillar.id,
                  child: Text(pillar.name, style: JuntaUi.body(color: AppColors.textPrimary)),
                ),
            ],
            onChanged: (value) => setState(() => _selectedForumId = value),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: _assigning ? null : _assign,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.burgundy,
            foregroundColor: AppColors.textOnDark,
          ),
          child: _assigning
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Asignar moderador'),
        ),
        const SizedBox(height: JuntaUi.sectionGap),
        const JuntaSectionHeader(title: 'Moderadores activos'),
        const SizedBox(height: 10),
        assignmentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e', style: JuntaUi.body()),
          data: (assignments) {
            if (assignments.isEmpty) {
              return Text(
                'Aún no hay moderadores asignados por foro.',
                style: JuntaUi.body(color: AppColors.textMuted),
              );
            }
            return Column(
              children: [
                for (final assignment in assignments)
                  Card(
                    margin: const EdgeInsets.only(bottom: JuntaUi.itemGap),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(JuntaUi.cardRadius),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: Text('@${assignment.handle}', style: JuntaUi.cardTitle()),
                      subtitle: Text(assignment.forumName, style: JuntaUi.caption()),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                        color: AppColors.accentRed,
                        onPressed: () => _remove(assignment),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
