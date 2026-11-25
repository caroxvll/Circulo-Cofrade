import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_ago.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../../forums/utils/hermandad_board_display.dart';
import '../../forums/utils/official_post_categories.dart';
import '../admin_provider.dart';
import '../data/admin_repository.dart';
import '../junta_ui.dart';

const _intervals = [15, 30, 60, 120, 360];

class JuntaXIngestTab extends ConsumerStatefulWidget {
  const JuntaXIngestTab({super.key});

  @override
  ConsumerState<JuntaXIngestTab> createState() => _JuntaXIngestTabState();
}

class _JuntaXIngestTabState extends ConsumerState<JuntaXIngestTab> {
  var _busy = false;
  String? _topicId;
  final _handle = TextEditingController();

  @override
  void dispose() {
    _handle.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(xIngestSettingsProvider);
    ref.invalidate(xIngestAccountsProvider);
    ref.invalidate(xIngestDraftsProvider);
    ref.invalidate(hermandadBoardTopicsProvider);
    await Future.wait([
      ref.read(xIngestSettingsProvider.future),
      ref.read(xIngestAccountsProvider.future),
      ref.read(xIngestDraftsProvider.future),
    ]);
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _run({
    bool skipBacklog = false,
    String? accountId,
  }) async {
    setState(() => _busy = true);
    try {
      final result = await ref.read(adminRepositoryProvider).runXIngestPull(
            force: true,
            skipBacklog: skipBacklog,
            accountId: accountId,
          );
      await _refresh();
      if (skipBacklog) {
        _snack('Cursor al día: no se han creado borradores.');
        return;
      }
      if (result['skipped'] == true) {
        _snack(result['message']?.toString() ?? 'Job omitido');
        return;
      }
      final n = (result['newPosts'] as num?)?.toInt() ?? 0;
      _snack(
        n == 0
            ? 'Sin posts nuevos.'
            : n == 1
                ? '1 borrador nuevo.'
                : '$n borradores nuevos.',
      );
    } on XIngestException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack(
        'No se pudo lanzar. ¿Desplegaste x-ingest-pull y ejecutaste x_ingest.sql?',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveSettings(XIngestSettings current, {bool? enabled}) async {
    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).saveXIngestSettings(
            enabled: enabled ?? current.enabled,
            intervalMinutes: current.intervalMinutes,
            maxPostsPerAccount: current.maxPostsPerAccount,
          );
      ref.invalidate(xIngestSettingsProvider);
    } catch (_) {
      _snack('No se pudieron guardar los ajustes.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addAccount() async {
    final topicId = _topicId;
    final handle = _handle.text.trim();
    if (topicId == null) {
      _snack('Elige el tablón de la hermandad');
      return;
    }
    if (handle.replaceFirst(RegExp(r'^@+'), '').isEmpty) {
      _snack('Indica el @ de X');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).upsertXIngestAccount(
            topicId: topicId,
            handle: handle,
          );
      _handle.clear();
      setState(() => _topicId = null);
      ref.invalidate(xIngestAccountsProvider);
    } catch (_) {
      _snack('No se pudo guardar la cuenta.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(xIngestSettingsProvider);
    final accountsAsync = ref.watch(xIngestAccountsProvider);
    final draftsAsync = ref.watch(xIngestDraftsProvider);
    final boardsAsync = ref.watch(hermandadBoardTopicsProvider);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: JuntaUi.listPadding,
        children: [
          const JuntaSectionHeader(
            title: 'Job de X',
            subtitle:
                'Apágalo en un traslado masivo. Lanzar ahora pregunta ya, '
                'aunque esté apagado. El cron solo corre si está encendido.',
          ),
          const SizedBox(height: 8),
          settingsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const JuntaInfoBanner(
              text:
                  'No se cargaron los ajustes. Ejecuta supabase/x_ingest.sql '
                  'en PRE y PROD.',
            ),
            data: (settings) {
              if (settings == null) {
                return const JuntaInfoBanner(
                  text: 'Solo un admin puede gestionar Redes X.',
                );
              }
              return _JobCard(
                settings: settings,
                busy: _busy,
                onEnabled: (value) => _saveSettings(settings, enabled: value),
                onInterval: (minutes) async {
                  setState(() => _busy = true);
                  try {
                    await ref.read(adminRepositoryProvider).saveXIngestSettings(
                          enabled: settings.enabled,
                          intervalMinutes: minutes,
                          maxPostsPerAccount: settings.maxPostsPerAccount,
                        );
                    ref.invalidate(xIngestSettingsProvider);
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
                onRun: () => _run(),
                onSkipAll: () => _run(skipBacklog: true),
              );
            },
          ),
          const SizedBox(height: JuntaUi.sectionGap),
          const JuntaSectionHeader(
            title: 'Cuentas',
            subtitle:
                'Un @ por tablón. Pausa una hermandad si está en traslado '
                'y no quieres esa avalancha.',
          ),
          const SizedBox(height: 8),
          boardsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (boards) => _AddAccountRow(
              boards: boards,
              accounts: accountsAsync.asData?.value ?? const [],
              topicId: _topicId,
              handleController: _handle,
              busy: _busy,
              onTopic: (id) => setState(() => _topicId = id),
              onAdd: _addAccount,
            ),
          ),
          const SizedBox(height: 8),
          accountsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => Text(
              'No se pudieron cargar las cuentas.',
              style: JuntaUi.body(),
            ),
            data: (accounts) {
              if (accounts.isEmpty) {
                return Text(
                  'Aún no hay cuentas. Enlaza el @ de cada hermandad.',
                  style: JuntaUi.caption(),
                );
              }
              return Column(
                children: [
                  for (final account in accounts)
                    _AccountTile(
                      account: account,
                      busy: _busy,
                      onEnabled: (enabled) async {
                        await ref
                            .read(adminRepositoryProvider)
                            .setXIngestAccountEnabled(
                              id: account.id,
                              enabled: enabled,
                            );
                        ref.invalidate(xIngestAccountsProvider);
                      },
                      onSkip: () => _run(
                        skipBacklog: true,
                        accountId: account.id,
                      ),
                      onDelete: () async {
                        await ref
                            .read(adminRepositoryProvider)
                            .deleteXIngestAccount(account.id);
                        ref.invalidate(xIngestAccountsProvider);
                      },
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: JuntaUi.sectionGap),
          JuntaSectionHeader(
            title: 'Borradores',
            subtitle: draftsAsync.asData?.value.isEmpty ?? true
                ? 'Cuando el job traiga posts, saldrán aquí para publicar o descartar.'
                : 'Revisa, elige sección del tablón y publica.',
          ),
          const SizedBox(height: 8),
          draftsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => Text(
              'No se pudieron cargar los borradores.',
              style: JuntaUi.body(),
            ),
            data: (drafts) {
              if (drafts.isEmpty) {
                return Text('Cola vacía.', style: JuntaUi.caption());
              }
              return Column(
                children: [
                  for (final draft in drafts)
                    _DraftCard(
                      draft: draft,
                      busy: _busy,
                      boards: boardsAsync.asData?.value ?? const [],
                      onDone: _refresh,
                      onBusy: (value) => setState(() => _busy = value),
                      onSnack: _snack,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.settings,
    required this.busy,
    required this.onEnabled,
    required this.onInterval,
    required this.onRun,
    required this.onSkipAll,
  });

  final XIngestSettings settings;
  final bool busy;
  final ValueChanged<bool> onEnabled;
  final ValueChanged<int> onInterval;
  final VoidCallback onRun;
  final VoidCallback onSkipAll;

  @override
  Widget build(BuildContext context) {
    final last = settings.lastRunAt;
    final lastLabel = last == null
        ? 'Aún no ha corrido'
        : 'Última pasada ${formatTimeAgo(last)}'
            '${settings.lastRunForced ? ' · a mano' : ''}'
            '${settings.lastRunNewPosts > 0 ? ' · ${settings.lastRunNewPosts} nuevos' : ''}';

    return Container(
      padding: JuntaUi.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(JuntaUi.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(
              settings.enabled ? 'Job encendido' : 'Job apagado',
              style: JuntaUi.body(color: AppColors.textPrimary),
            ),
            subtitle: Text(
              settings.enabled
                  ? 'Pregunta solo posts nuevos cada ${settings.intervalMinutes} min.'
                  : 'El cron no corre. Sigue pudiendo lanzarlo a mano.',
              style: JuntaUi.caption(),
            ),
            value: settings.enabled,
            activeThumbColor: AppColors.burgundy,
            onChanged: busy ? null : onEnabled,
          ),
          const SizedBox(height: 4),
          Text('Intervalo', style: JuntaUi.caption()),
          const SizedBox(height: 4),
          DropdownButtonFormField<int>(
            key: ValueKey(settings.intervalMinutes),
            initialValue: _intervals.contains(settings.intervalMinutes)
                ? settings.intervalMinutes
                : 60,
            decoration: JuntaUi.inputDecoration(labelText: 'Cada cuánto'),
            items: [
              for (final minutes in _intervals)
                DropdownMenuItem(
                  value: minutes,
                  child: Text(
                    minutes < 60
                        ? '$minutes min'
                        : minutes == 60
                            ? '1 hora'
                            : '${minutes ~/ 60} horas',
                  ),
                ),
            ],
            onChanged: busy
                ? null
                : (value) {
                    if (value != null) onInterval(value);
                  },
          ),
          const SizedBox(height: 8),
          Text(lastLabel, style: JuntaUi.caption()),
          if (settings.lastRunError != null) ...[
            const SizedBox(height: 4),
            Text(
              settings.lastRunError!,
              style: JuntaUi.caption(color: AppColors.accentRed),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy ? null : onRun,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Lanzar ahora'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onSkipAll,
                  child: const Text('Al día (sin importar)'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddAccountRow extends StatelessWidget {
  const _AddAccountRow({
    required this.boards,
    required this.accounts,
    required this.topicId,
    required this.handleController,
    required this.busy,
    required this.onTopic,
    required this.onAdd,
  });

  final List<({String id, String title})> boards;
  final List<XIngestAccount> accounts;
  final String? topicId;
  final TextEditingController handleController;
  final bool busy;
  final ValueChanged<String?> onTopic;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final taken = {for (final a in accounts) a.topicId};
    final options = boards.where((b) => !taken.contains(b.id)).toList();
    return Column(
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(topicId),
          initialValue:
              options.any((b) => b.id == topicId) ? topicId : null,
          decoration: JuntaUi.inputDecoration(labelText: 'Tablón'),
          items: [
            for (final board in options)
              DropdownMenuItem(
                value: board.id,
                child: Text(
                  parseHermandadTopicTitle(board.title).hermandadName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: busy ? null : onTopic,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: handleController,
          enabled: !busy,
          decoration: JuntaUi.inputDecoration(
            labelText: 'Handle de X',
            hintText: '@macarena',
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: busy ? null : onAdd,
            child: const Text('Enlazar'),
          ),
        ),
      ],
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.busy,
    required this.onEnabled,
    required this.onSkip,
    required this.onDelete,
  });

  final XIngestAccount account;
  final bool busy;
  final ValueChanged<bool> onEnabled;
  final VoidCallback onSkip;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final name = account.topicTitle == null
        ? account.handleLabel
        : parseHermandadTopicTitle(account.topicTitle!).hermandadName;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(JuntaUi.cardRadius),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: JuntaUi.cardTitle()),
                      Text(account.handleLabel, style: JuntaUi.caption()),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: account.ingestEnabled,
                  activeThumbColor: AppColors.burgundy,
                  onChanged: busy ? null : onEnabled,
                ),
              ],
            ),
            if (!account.ingestEnabled)
              Text(
                'Pausada · no se consulta (traslado, etc.)',
                style: JuntaUi.caption(color: AppColors.goldDark),
              ),
            if (account.lastCapped)
              Text(
                'Última pasada recortada: hay más posts de los que importamos.',
                style: JuntaUi.caption(color: AppColors.accentRed),
              ),
            if (account.lastError != null)
              Text(
                account.lastError!,
                style: JuntaUi.caption(color: AppColors.accentRed),
              ),
            Row(
              children: [
                TextButton(
                  onPressed: busy ? null : onSkip,
                  child: const Text('Al día'),
                ),
                TextButton(
                  onPressed: busy ? null : onDelete,
                  child: const Text('Quitar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftCard extends ConsumerStatefulWidget {
  const _DraftCard({
    required this.draft,
    required this.busy,
    required this.boards,
    required this.onDone,
    required this.onBusy,
    required this.onSnack,
  });

  final XIngestDraft draft;
  final bool busy;
  final List<({String id, String title})> boards;
  final Future<void> Function() onDone;
  final ValueChanged<bool> onBusy;
  final ValueChanged<String> onSnack;

  @override
  ConsumerState<_DraftCard> createState() => _DraftCardState();
}

class _DraftCardState extends ConsumerState<_DraftCard> {
  late final TextEditingController _body;
  late String _category;
  late String _topicId;

  @override
  void initState() {
    super.initState();
    _body = TextEditingController(text: widget.draft.body);
    _category = widget.draft.suggestedCategory;
    _topicId = widget.draft.topicId;
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    widget.onBusy(true);
    try {
      await ref.read(adminRepositoryProvider).publishXIngestDraft(
            draftId: widget.draft.id,
            topicId: _topicId,
            category: _category,
            body: _body.text,
          );
      await widget.onDone();
      widget.onSnack('Publicado en el tablón');
    } catch (e) {
      widget.onSnack(
        e.toString().contains('cuenta oficial')
            ? 'Ese tablón no tiene cuenta oficial de hermandad.'
            : 'No se pudo publicar el borrador.',
      );
    } finally {
      widget.onBusy(false);
    }
  }

  Future<void> _discard() async {
    widget.onBusy(true);
    try {
      await ref.read(adminRepositoryProvider).discardXIngestDraft(widget.draft.id);
      await widget.onDone();
    } catch (_) {
      widget.onSnack('No se pudo descartar.');
    } finally {
      widget.onBusy(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.draft.imageUrl;
    final name = widget.draft.topicTitle == null
        ? widget.draft.handle
        : parseHermandadTopicTitle(widget.draft.topicTitle!).hermandadName;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(JuntaUi.cardRadius),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: JuntaUi.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('$name · @${widget.draft.handle}', style: JuntaUi.cardTitle()),
            if (widget.draft.postedAt != null)
              Text(
                formatTimeAgo(widget.draft.postedAt!),
                style: JuntaUi.caption(),
              ),
            if (image != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CofradeoNetworkImage(url: image),
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _body,
              minLines: 3,
              maxLines: 8,
              enabled: !widget.busy,
              decoration: JuntaUi.inputDecoration(labelText: 'Texto'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: JuntaUi.inputDecoration(labelText: 'Sección'),
              items: [
                for (final cat in officialPostCategories)
                  DropdownMenuItem(value: cat.value, child: Text(cat.label)),
              ],
              onChanged: widget.busy
                  ? null
                  : (value) {
                      if (value != null) setState(() => _category = value);
                    },
            ),
            if (widget.boards.isNotEmpty) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey(_topicId),
                initialValue: widget.boards.any((b) => b.id == _topicId)
                    ? _topicId
                    : widget.draft.topicId,
                decoration: JuntaUi.inputDecoration(labelText: 'Hermandad'),
                items: [
                  for (final board in widget.boards)
                    DropdownMenuItem(
                      value: board.id,
                      child: Text(
                        parseHermandadTopicTitle(board.title).hermandadName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: widget.busy
                    ? null
                    : (value) {
                        if (value != null) setState(() => _topicId = value);
                      },
              ),
            ],
            if (widget.draft.sourceUrl != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    final uri = Uri.tryParse(widget.draft.sourceUrl!);
                    if (uri != null) launchUrl(uri);
                  },
                  child: const Text('Ver en X'),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.busy ? null : _discard,
                    child: const Text('Descartar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: widget.busy ? null : _publish,
                    child: const Text('Publicar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
