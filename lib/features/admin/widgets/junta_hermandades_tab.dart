import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../permissions/data/permissions_repository.dart';
import '../../permissions/permissions_provider.dart';
import '../admin_provider.dart';
import '../junta_ui.dart';
import 'junta_handle_search_field.dart';

class JuntaHermandadesTab extends ConsumerStatefulWidget {
  const JuntaHermandadesTab({super.key});

  @override
  ConsumerState<JuntaHermandadesTab> createState() =>
      _JuntaHermandadesTabState();
}

class _JuntaHermandadesTabState extends ConsumerState<JuntaHermandadesTab> {
  final _createDisplayName = TextEditingController();
  final _createHandle = TextEditingController();
  final _createEmail = TextEditingController();
  final _createPassword = TextEditingController();
  final _linkHandleController = TextEditingController();

  ProfileHandleSearchHit? _selectedProfile;
  String? _createTopicId;
  String? _linkTopicId;
  var _creating = false;
  var _assigning = false;
  var _autoPassword = true;

  @override
  void dispose() {
    _createDisplayName.dispose();
    _createHandle.dispose();
    _createEmail.dispose();
    _createPassword.dispose();
    _linkHandleController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    final displayName = _createDisplayName.text.trim();
    final handle = _createHandle.text.trim();
    final email = _createEmail.text.trim();
    final password = _autoPassword ? null : _createPassword.text.trim();

    if (displayName.length < 2) {
      _snack('Indica el nombre oficial de la hermandad');
      return;
    }
    if (handle.replaceFirst('@', '').length < 3) {
      _snack('Indica un handle válido (mín. 3 caracteres)');
      return;
    }
    if (!email.contains('@')) {
      _snack('Indica un email válido');
      return;
    }
    if (!_autoPassword && (password == null || password.length < 8)) {
      _snack('La contraseña debe tener al menos 8 caracteres');
      return;
    }

    setState(() => _creating = true);
    try {
      final created =
          await ref.read(permissionsRepositoryProvider).createHermandadAccount(
                email: email,
                handle: handle,
                displayName: displayName,
                password: password,
                topicId: _createTopicId,
              );
      ref.invalidate(hermandadAssignmentsProvider);
      ref.invalidate(hermandadTopicIdsProvider);

      _createDisplayName.clear();
      _createHandle.clear();
      _createEmail.clear();
      _createPassword.clear();
      setState(() {
        _createTopicId = null;
        _autoPassword = true;
      });

      if (!mounted) return;
      await _showCredentialsDialog(created);
    } on HermandadAccountProvisionException catch (e) {
      _snack(e.message);
    } on FunctionException catch (e) {
      _snack(_functionErrorMessage(e));
    } catch (_) {
      _snack(
        'No se pudo crear la cuenta. ¿Está desplegada la Edge Function?',
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _assign() async {
    final topicId = _linkTopicId;
    if (topicId == null) {
      _snack('Selecciona un tablón de hermandad');
      return;
    }

    setState(() => _assigning = true);
    try {
      final profileId = _selectedProfile?.id ??
          await ref.read(permissionsRepositoryProvider).fetchProfileIdByHandle(
                _linkHandleController.text,
              );

      if (profileId == null) {
        _snack(
          'Selecciona una cuenta de la lista o escribe un handle válido',
        );
        return;
      }

      await ref.read(permissionsRepositoryProvider).assignHermandadTopic(
            profileId: profileId,
            topicId: topicId,
          );
      ref.invalidate(hermandadAssignmentsProvider);
      ref.invalidate(hermandadTopicIdsProvider);
      final assignedHandle = _selectedProfile?.handleLabel ??
          '@${_linkHandleController.text.trim().replaceFirst('@', '')}';
      _linkHandleController.clear();
      setState(() {
        _selectedProfile = null;
        _linkTopicId = null;
      });
      _snack('$assignedHandle asignado al tablón');
    } catch (_) {
      _snack('No se pudo asignar. La cuenta debe estar verificada.');
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  Future<void> _remove(HermandadTopicAssignment assignment) async {
    try {
      await ref.read(permissionsRepositoryProvider).removeHermandadAssignment(
            profileId: assignment.profileId,
            topicId: assignment.topicId,
          );
      ref.invalidate(hermandadAssignmentsProvider);
      ref.invalidate(hermandadTopicIdsProvider);
    } catch (_) {
      _snack('No se pudo quitar la asignación');
    }
  }

  Future<void> _showCredentialsDialog(CreatedHermandadAccount account) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Cuenta creada', style: JuntaUi.cardTitle()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pásale estos datos a la hermandad en privado. '
                'Recomiéndale cambiar la contraseña al entrar.',
                style: JuntaUi.body(),
              ),
              const SizedBox(height: 12),
              _CredentialRow(label: 'Handle', value: account.handleLabel),
              _CredentialRow(label: 'Email', value: account.email),
              _CredentialRow(
                label: 'Contraseña temporal',
                value: account.temporaryPassword,
              ),
              if (account.topicId != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Ya quedó vinculada al tablón seleccionado.',
                  style: JuntaUi.caption(color: AppColors.burgundy),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final text =
                    '${account.handleLabel}\n${account.email}\n${account.temporaryPassword}';
                await Clipboard.setData(ClipboardData(text: text));
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Credenciales copiadas')),
                  );
                }
              },
              child: const Text('Copiar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.burgundy,
                foregroundColor: AppColors.textOnDark,
              ),
              child: const Text('Listo'),
            ),
          ],
        );
      },
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _functionErrorMessage(FunctionException e) {
    final details = e.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    if (details is String && details.isNotEmpty) return details;
    final reason = e.reasonPhrase;
    if (reason != null && reason.isNotEmpty) return reason;
    return 'Error al crear la cuenta hermandad';
  }

  Widget _topicDropdown({
    required AsyncValue<List<({String id, String title})>> topicsAsync,
    required String? value,
    required ValueChanged<String?> onChanged,
    required String labelText,
    bool allowEmpty = false,
  }) {
    return topicsAsync.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (_, _) =>
          Text('No se pudieron cargar los tablones', style: JuntaUi.body()),
      data: (topics) => DropdownButtonFormField<String?>(
        key: ValueKey('topic-$labelText-${value ?? 'none'}'),
        initialValue: value,
        style: JuntaUi.body(color: AppColors.textPrimary),
        decoration: JuntaUi.inputDecoration(labelText: labelText),
        items: [
          if (allowEmpty)
            DropdownMenuItem<String?>(
              value: null,
              child: Text(
                'Sin vincular ahora',
                style: JuntaUi.body(color: AppColors.textMuted),
              ),
            ),
          for (final topic in topics)
            DropdownMenuItem<String?>(
              value: topic.id,
              child: Text(
                topic.title,
                overflow: TextOverflow.ellipsis,
                style: JuntaUi.body(color: AppColors.textPrimary),
              ),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topicsAsync = ref.watch(hermandadBoardTopicsProvider);
    final assignmentsAsync = ref.watch(hermandadAssignmentsProvider);

    return ListView(
      padding: JuntaUi.listPadding,
      children: [
        const JuntaSectionHeader(
          title: 'Crear cuenta oficial',
          subtitle:
              'Tras hablar con la hermandad: genera usuario, verifica y '
              'opcionalmente vincula su tablón. Sin registro abierto.',
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _createDisplayName,
          style: JuntaUi.body(color: AppColors.textPrimary),
          textCapitalization: TextCapitalization.words,
          decoration: JuntaUi.inputDecoration(
            labelText: 'Nombre oficial',
            hintText: 'Pino Montano',
          ),
          onChanged: (value) {
            if (_createHandle.text.trim().isNotEmpty) return;
            final suggested = value
                .trim()
                .toLowerCase()
                .replaceAll(RegExp(r'[^a-z0-9áéíóúüñ\s_]'), '')
                .replaceAll(RegExp(r'\s+'), '_')
                .replaceAll('á', 'a')
                .replaceAll('é', 'e')
                .replaceAll('í', 'i')
                .replaceAll('ó', 'o')
                .replaceAll('ú', 'u')
                .replaceAll('ü', 'u')
                .replaceAll('ñ', 'n');
            if (suggested.isEmpty) return;
            _createHandle.value = TextEditingValue(
              text: 'hdad_$suggested',
              selection: TextSelection.collapsed(
                offset: 'hdad_$suggested'.length,
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _createHandle,
          style: JuntaUi.body(color: AppColors.textPrimary),
          decoration: JuntaUi.inputDecoration(
            labelText: 'Handle',
            hintText: '@hdad_pinomontano',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _createEmail,
          keyboardType: TextInputType.emailAddress,
          style: JuntaUi.body(color: AppColors.textPrimary),
          decoration: JuntaUi.inputDecoration(
            labelText: 'Email de acceso',
            hintText: 'secretaria@hermandad.es',
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(
            'Generar contraseña temporal',
            style: JuntaUi.body(color: AppColors.textPrimary),
          ),
          value: _autoPassword,
          activeThumbColor: AppColors.burgundy,
          onChanged: (value) => setState(() => _autoPassword = value),
        ),
        if (!_autoPassword) ...[
          const SizedBox(height: 4),
          TextField(
            controller: _createPassword,
            obscureText: true,
            style: JuntaUi.body(color: AppColors.textPrimary),
            decoration: JuntaUi.inputDecoration(
              labelText: 'Contraseña',
              hintText: 'Mínimo 8 caracteres',
            ),
          ),
        ],
        const SizedBox(height: 10),
        _topicDropdown(
          topicsAsync: topicsAsync,
          value: _createTopicId,
          labelText: 'Vincular tablón (opcional)',
          allowEmpty: true,
          onChanged: (value) => setState(() => _createTopicId = value),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _creating ? null : _createAccount,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.burgundy,
            foregroundColor: AppColors.textOnDark,
          ),
          icon: _creating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.textOnDark,
                  ),
                )
              : const Icon(Icons.person_add_alt_1_outlined, size: 18),
          label: Text(_creating ? 'Creando…' : 'Crear cuenta hermandad'),
        ),
        const SizedBox(height: JuntaUi.sectionGap),
        const JuntaSectionHeader(
          title: 'Vincular cuenta existente',
          subtitle:
              'Si la cuenta ya existe y está verificada, asígnala a su tablón.',
        ),
        const SizedBox(height: 10),
        JuntaHandleSearchField(
          controller: _linkHandleController,
          labelText: 'Handle de la hermandad',
          hintText: '@hdad_ejemplo',
          onSelected: (profile) => setState(() => _selectedProfile = profile),
        ),
        const SizedBox(height: 10),
        _topicDropdown(
          topicsAsync: topicsAsync,
          value: _linkTopicId,
          labelText: 'Tablón de hermandad',
          onChanged: (value) => setState(() => _linkTopicId = value),
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
              : const Text('Asignar cuenta'),
        ),
        const SizedBox(height: JuntaUi.sectionGap),
        const JuntaSectionHeader(title: 'Asignaciones activas'),
        const SizedBox(height: 10),
        assignmentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e', style: JuntaUi.body()),
          data: (assignments) {
            if (assignments.isEmpty) {
              return Text(
                'Aún no hay hermandades asignadas a tablones.',
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
                      title: Text(
                        '@${assignment.handle}',
                        style: JuntaUi.cardTitle(),
                      ),
                      subtitle: Text(
                        assignment.topicTitle,
                        style: JuntaUi.caption(),
                      ),
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

class _CredentialRow extends StatelessWidget {
  const _CredentialRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: JuntaUi.caption()),
          SelectableText(
            value,
            style: JuntaUi.body(
              color: AppColors.textPrimary,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
