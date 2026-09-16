import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cofradeo_badge.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../../../shared/models/forum.dart';
import '../../ads/ads_provider.dart';
import '../../ads/models/sponsored_ad.dart';
import '../../ads/utils/featured_topic_ads.dart';
import '../../forums/data/forum_icons.dart';
import '../../forums/data/forums_repository.dart';
import '../../forums/forums_provider.dart';
import '../../forums/widgets/forum_pillar_icon_mark.dart';
import '../../forums/widgets/topic_card.dart';
import '../admin_provider.dart';
import '../data/admin_repository.dart';
import '../junta_ui.dart';
import 'admin_ads_tab.dart';

String _slugifyPillarId(String input) {
  return input
      .toLowerCase()
      .replaceAll(RegExp(r'[áàäâ]'), 'a')
      .replaceAll(RegExp(r'[éèëê]'), 'e')
      .replaceAll(RegExp(r'[íìïî]'), 'i')
      .replaceAll(RegExp(r'[óòöô]'), 'o')
      .replaceAll(RegExp(r'[úùüû]'), 'u')
      .replaceAll(RegExp(r'ñ'), 'n')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}

Future<void> _createForum(
  BuildContext context,
  WidgetRef ref,
  List<ForumCategory> pillars,
) async {
  final nameController = TextEditingController();
  final idController = TextEditingController();
  final descriptionController = TextEditingController();
  var selectedIcon = 'church';
  var idTouched = false;

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Nuevo foro'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Ej. Círculo Cofrade',
                ),
                textCapitalization: TextCapitalization.sentences,
                onChanged: (value) {
                  if (!idTouched) {
                    idController.text = _slugifyPillarId(value);
                    setDialogState(() {});
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: idController,
                decoration: const InputDecoration(
                  labelText: 'Id (slug)',
                  hintText: 'foro-cofradiero',
                ),
                onChanged: (_) {
                  idTouched = true;
                  setDialogState(() {});
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedIcon,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Icono de respaldo',
                ),
                items: _forumIconDropdownItems(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedIcon = value);
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Crear'),
          ),
        ],
      ),
    ),
  );

  if (saved != true || !context.mounted) {
    nameController.dispose();
    idController.dispose();
    descriptionController.dispose();
    return;
  }

  try {
    await ref.read(adminRepositoryProvider).createPillar(
          id: idController.text,
          name: nameController.text,
          description: descriptionController.text,
          iconKey: selectedIcon,
        );
    ref.invalidate(adminPillarsProvider);
    invalidateForumPillarData(ref);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foro creado')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo crear. ¿Ejecutaste forum_pillar_icons.sql?',
          ),
        ),
      );
    }
  } finally {
    nameController.dispose();
    idController.dispose();
    descriptionController.dispose();
  }
}

class JuntaPillarsTab extends ConsumerWidget {
  const JuntaPillarsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pillarsAsync = ref.watch(adminPillarsProvider);
    final pinnedAsync = ref.watch(pinnedSystemTopicsProvider);

    return pillarsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _EmptyState(
        icon: Icons.error_outline,
        message: 'No se pudieron cargar los foros.',
        onRetry: () {
          ref.invalidate(adminPillarsProvider);
          ref.invalidate(pinnedSystemTopicsProvider);
        },
      ),
      data: (pillars) {
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(adminPillarsProvider);
            ref.invalidate(pinnedSystemTopicsProvider);
            invalidateForumPillarData(ref);
            await ref.read(adminPillarsProvider.future);
            await ref.read(pinnedSystemTopicsProvider.future);
          },
          child: ListView(
            padding: JuntaUi.listPadding,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.burgundy.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'Gestiona la imagen del hero de FOROS y las portadas de cada '
                  'foro (tarjeta y cabecera del detalle). Los iconos son fijos '
                  'en la app. También puedes crear foros, temas fijos y '
                  'controlar su visibilidad.',
                  style: JuntaUi.body(),
                ),
              ),
              const SizedBox(height: 16),
              const _ForumsListHeroSection(),
              const SizedBox(height: 16),
              pinnedAsync.when(
                loading: () => const _SectionHeader(
                  title: 'Temas destacados',
                  subtitle: 'Cargando…',
                ),
                error: (_, __) => const _SectionHeader(
                  title: 'Temas destacados',
                  subtitle: 'No se pudieron cargar.',
                ),
                data: (topics) => _PinnedTopicsSection(
                  topics: topics,
                  pillars: pillars,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Foros',
                style: JuntaUi.sectionTitle(),
              ),
              const SizedBox(height: 4),
              Text(
                'Muestra u oculta cada foro en FOROS, cambia su portada o crea uno nuevo.',
                style: JuntaUi.body(),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < pillars.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _PillarAdminCard(pillar: pillars[i]),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _createForum(context, ref, pillars),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nuevo foro'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.burgundy,
                  side: const BorderSide(color: AppColors.burgundy),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ForumsListHeroSection extends ConsumerStatefulWidget {
  const _ForumsListHeroSection();

  @override
  ConsumerState<_ForumsListHeroSection> createState() =>
      _ForumsListHeroSectionState();
}

class _ForumsListHeroSectionState extends ConsumerState<_ForumsListHeroSection> {
  final _picker = ImagePicker();
  var _busy = false;

  Future<void> _pickHero() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      imageQuality: 88,
    );
    if (file == null) return;

    setState(() => _busy = true);
    try {
      final bytes = await file.readAsBytes();
      final mime = switch (file.path.split('.').last.toLowerCase()) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      final repo = ref.read(adminRepositoryProvider);
      final url = await repo.uploadForumsListHero(bytes: bytes, mimeType: mime);
      await repo.setAppConfig(AdminRepository.forumsListHeroConfigKey, url);
      ref.invalidate(forumsListHeroImageProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Imagen del hero de FOROS guardada')),
        );
      }
    } on PillarCoverTooLargeException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La imagen supera 5 MB.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo subir. ¿Ejecutaste forum_pillar_covers.sql?',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearHero() async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      await repo.setAppConfig(AdminRepository.forumsListHeroConfigKey, '');
      ref.invalidate(forumsListHeroImageProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hero de FOROS restaurado al predeterminado')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo restaurar el hero.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final heroAsync = ref.watch(forumsListHeroImageProvider);
    final heroUrl = heroAsync.asData?.value;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hero de la pantalla FOROS',
              style: JuntaUi.cardTitle(),
            ),
            const SizedBox(height: 4),
            Text(
              'Imagen de fondo del listado principal de foros.',
              style: JuntaUi.body(),
            ),
            if (heroUrl != null && heroUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 16 / 7,
                  child: CofradeoNetworkImage(
                    url: heroUrl,
                    fit: BoxFit.cover,
                    cacheSize: MediaQuery.sizeOf(context).width,
                    filterQuality: FilterQuality.medium,
                    errorWidget: const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickHero,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Subir imagen'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.burgundy,
                    side: const BorderSide(color: AppColors.burgundy),
                  ),
                ),
                if (heroUrl != null && heroUrl.isNotEmpty)
                  TextButton(
                    onPressed: _busy ? null : _clearHero,
                    child: const Text('Restaurar predeterminada'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PinnedTopicsSection extends ConsumerWidget {
  const _PinnedTopicsSection({
    required this.topics,
    required this.pillars,
  });

  final List<ForumTopic> topics;
  final List<ForumCategory> pillars;

  String _forumLabel(String forumId) {
    for (final pillar in pillars) {
      if (pillar.id == forumId) return pillar.name;
    }
    return forumId;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grouped = <String, List<ForumTopic>>{};
    for (final forumId in ForumsRepository.pinnedTopicParentForumIds) {
      grouped[forumId] = [];
    }
    for (final topic in topics) {
      grouped.putIfAbsent(topic.forumId, () => []).add(topic);
    }
    for (final entry in grouped.entries) {
      entry.value.sort((a, b) => a.pinSortOrder.compareTo(b.pinSortOrder));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Temas destacados',
          subtitle:
              'Por foro: sube imagen, ordena, muestra u oculta, crea o elimina.',
        ),
        const SizedBox(height: 10),
        if (topics.isEmpty)
          Text(
            'Sin temas fijos en Supabase. Ejecuta pinned_topics.sql.',
            style: JuntaUi.body(),
          ),
        for (final forumId in ForumsRepository.pinnedTopicParentForumIds) ...[
          _PinnedForumGroup(
            forumId: forumId,
            forumName: _forumLabel(forumId),
            topics: grouped[forumId] ?? const [],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _PinnedForumGroup extends ConsumerWidget {
  const _PinnedForumGroup({
    required this.forumId,
    required this.forumName,
    required this.topics,
  });

  final String forumId;
  final String forumName;
  final List<ForumTopic> topics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: topics.isNotEmpty,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: Text(
              forumName,
              style: JuntaUi.cardTitle(),
            ),
            subtitle: Text(
              topics.isEmpty
                  ? 'Sin temas destacados'
                  : '${topics.length} tema${topics.length == 1 ? '' : 's'}',
              style: JuntaUi.caption(),
            ),
            children: [
              for (var i = 0; i < topics.length; i++)
                Padding(
                  padding: EdgeInsets.only(bottom: i < topics.length - 1 ? 10 : 12),
                  child: _PinnedTopicAdminCard(
                    topic: topics[i],
                    canMoveUp: i > 0,
                    canMoveDown: i < topics.length - 1,
                    onMoveUp: () => _swapOrder(ref, topics, i, i - 1),
                    onMoveDown: () => _swapOrder(ref, topics, i, i + 1),
                    onDelete: () => _confirmDelete(context, ref, topics[i]),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () => _createTopic(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nuevo tema destacado'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.burgundy,
                  side: const BorderSide(color: AppColors.burgundy),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _swapOrder(
    WidgetRef ref,
    List<ForumTopic> forumTopics,
    int from,
    int to,
  ) async {
    final a = forumTopics[from];
    final b = forumTopics[to];
    final repo = ref.read(forumsRepositoryProvider);
    try {
      await repo.updatePinnedTopicSettings(
        topicId: a.id,
        pinSortOrder: b.pinSortOrder,
      );
      await repo.updatePinnedTopicSettings(
        topicId: b.id,
        pinSortOrder: a.pinSortOrder,
      );
      ref.invalidate(pinnedSystemTopicsProvider);
      ref.invalidate(forumTopicsProvider(forumId));
    } catch (_) {}
  }

  Future<void> _createTopic(BuildContext context, WidgetRef ref) async {
    final titleController = TextEditingController();
    final excerptController = TextEditingController();
    String? seasonKey;
    var selectedIcon = 'church';

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Nuevo tema en $forumName'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    hintText: 'Ej. Semana Santa',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: excerptController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción corta (opcional)',
                  ),
                  maxLines: 2,
                ),
                if (forumId == 'foro-cofradiero') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: seasonKey,
                    decoration: const InputDecoration(
                      labelText: 'Temporada (opcional)',
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Ninguna')),
                      DropdownMenuItem(
                        value: 'cuaresma',
                        child: Text('Cuaresma'),
                      ),
                      DropdownMenuItem(
                        value: 'semana_santa',
                        child: Text('Semana Santa'),
                      ),
                      DropdownMenuItem(
                        value: 'glorias',
                        child: Text('Glorias'),
                      ),
                    ],
                    onChanged: (value) {
                      setDialogState(() => seasonKey = value);
                    },
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedIcon,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Icono'),
                  items: _forumIconDropdownItems(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedIcon = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !context.mounted) {
      titleController.dispose();
      excerptController.dispose();
      return;
    }

    try {
      await ref.read(forumsRepositoryProvider).createPinnedSystemTopic(
            forumId: forumId,
            title: titleController.text,
            excerpt: excerptController.text,
            seasonKey: seasonKey,
            iconKey: selectedIcon,
          );
      ref.invalidate(pinnedSystemTopicsProvider);
      ref.invalidate(forumTopicsProvider(forumId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tema creado en $forumName')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo crear el tema.')),
        );
      }
    } finally {
      titleController.dispose();
      excerptController.dispose();
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ForumTopic topic,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Eliminar «${topic.title}»?'),
        content: const Text(
          'Se borrará el tema fijo y sus respuestas. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.accentRed),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(forumsRepositoryProvider)
          .deletePinnedSystemTopic(topic.id);
      ref.invalidate(pinnedSystemTopicsProvider);
      ref.invalidate(forumTopicsProvider(forumId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('«${topic.title}» eliminado')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo eliminar el tema.')),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: JuntaUi.sectionTitle()),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: JuntaUi.body(),
        ),
      ],
    );
  }
}

class _PinnedTopicAdminCard extends ConsumerStatefulWidget {
  const _PinnedTopicAdminCard({
    required this.topic,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
  });

  final ForumTopic topic;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDelete;

  @override
  ConsumerState<_PinnedTopicAdminCard> createState() =>
      _PinnedTopicAdminCardState();
}

class _PinnedTopicAdminCardState extends ConsumerState<_PinnedTopicAdminCard> {
  final _picker = ImagePicker();
  var _busy = false;

  Future<void> _saveSettings({
    String? iconKey,
    String? coverImageUrl,
    bool? isListed,
    String? excerpt,
    String? body,
  }) async {
    setState(() => _busy = true);
    try {
      await ref.read(forumsRepositoryProvider).updatePinnedTopicSettings(
            topicId: widget.topic.id,
            iconKey: iconKey,
            coverImageUrl: coverImageUrl,
            isListed: isListed,
            excerpt: excerpt,
            body: body,
          );
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.topic.title} actualizado')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el tema.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickCover() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() => _busy = true);
    try {
      final bytes = await file.readAsBytes();
      final mime = switch (file.path.split('.').last.toLowerCase()) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      final url = await ref.read(forumsRepositoryProvider).uploadTopicCover(
            topicId: widget.topic.id,
            bytes: bytes,
            mimeType: mime,
          );
      await ref.read(forumsRepositoryProvider).updatePinnedTopicSettings(
            topicId: widget.topic.id,
            coverImageUrl: url,
          );
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imagen de ${widget.topic.title} guardada')),
        );
      }
    } on TopicCoverTooLargeException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La imagen supera 3 MB.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo subir. ¿Ejecutaste pinned_topics_admin.sql?',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPatrocinio() async {
    final ads =
        ref.read(adminAdsProvider).asData?.value ?? const <SponsoredAd>[];
    await showPatrocinioAssignSheet(
      context,
      ref,
      catalogAds: ads,
      initialPlacement: AdPlacement.featuredTopic,
      initialTopicId: widget.topic.id,
    );
  }

  Future<void> _editAppearance() async {
    if (!mounted) return;

    final result = await showDialog<_PinnedTopicEditDialogResult>(
      context: context,
      builder: (ctx) => _PinnedTopicEditDialog(topic: widget.topic),
    );

    if (!mounted || result == null) return;

    if (result is _PinnedTopicEditPickGallery) {
      await _pickCover();
      if (!mounted) return;
      return _editAppearance();
    }

    if (result is _PinnedTopicEditSaved) {
      await _saveSettings(
        iconKey: result.iconKey,
        coverImageUrl: result.coverImageUrl,
        excerpt: result.excerpt,
        body: result.body,
      );
    }
  }

  void _refresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(pinnedSystemTopicsProvider);
      ref.invalidate(forumTopicsProvider(widget.topic.forumId));
      ref.invalidate(
        forumTopicProvider(
          ForumTopicKey(
            forumId: widget.topic.forumId,
            topicId: widget.topic.id,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final topic = widget.topic;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PinnedTopicMark(topic: topic),
                const SizedBox(width: 12),
                Expanded(
                  child: JuntaCardTitleBlock(
                    title: topic.title,
                    badges: [
                      const CofradeoBadge(label: 'Fijo'),
                      if (!topic.isListed) const CofradeoBadge(label: 'Oculto'),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _busy ? null : _editAppearance,
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Editar tema',
                  color: AppColors.burgundy,
                ),
                if (isFeaturedTopicAdTarget(topic.id))
                  IconButton(
                    onPressed: _busy ? null : _openPatrocinio,
                    icon: const Icon(Icons.campaign_outlined),
                    tooltip: 'Patrocinio en este tema',
                    color: AppColors.burgundy,
                  ),
                IconButton(
                  onPressed: _busy ? null : widget.onDelete,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Eliminar tema',
                  color: AppColors.accentRed,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  onPressed: _busy || !widget.canMoveUp ? null : widget.onMoveUp,
                  icon: const Icon(Icons.arrow_upward),
                  tooltip: 'Subir orden',
                  color: AppColors.burgundy,
                ),
                IconButton(
                  onPressed:
                      _busy || !widget.canMoveDown ? null : widget.onMoveDown,
                  icon: const Icon(Icons.arrow_downward),
                  tooltip: 'Bajar orden',
                  color: AppColors.burgundy,
                ),
                Text(
                  'Orden ${topic.pinSortOrder}',
                  style: JuntaUi.caption(),
                ),
                const Spacer(),
                Text(
                  'Visible',
                  style: JuntaUi.body(),
                ),
                Switch(
                  value: topic.isListed,
                  onChanged: _busy
                      ? null
                      : (value) => _saveSettings(isListed: value),
                  activeThumbColor: AppColors.burgundy,
                ),
              ],
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
      ),
    );
  }
}

class _PillarAdminCard extends ConsumerStatefulWidget {
  const _PillarAdminCard({required this.pillar});

  final ForumCategory pillar;

  @override
  ConsumerState<_PillarAdminCard> createState() => _PillarAdminCardState();
}

class _PillarAdminCardState extends ConsumerState<_PillarAdminCard> {
  final _picker = ImagePicker();
  var _busy = false;

  void _refreshPillars() {
    ref.invalidate(adminPillarsProvider);
    invalidateForumPillarData(ref);
    ref.invalidate(forumPillarProvider(widget.pillar.id));
  }

  Future<void> _update({
    bool? isEnabled,
    bool? isActive,
    String? name,
    String? description,
    String? iconKey,
    String? coverImageUrl,
  }) async {
    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).updatePillar(
            pillarId: widget.pillar.id,
            isEnabled: isEnabled,
            isActive: isActive,
            name: name,
            description: description,
            iconKey: iconKey,
            coverImageUrl: coverImageUrl,
          );
      _refreshPillars();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${name?.trim().isNotEmpty == true ? name!.trim() : widget.pillar.name} actualizado',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo guardar. ¿Ejecutaste admin_forum_pillars.sql?',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editNameAndDescription() async {
    final pillar = widget.pillar;
    final nameController = TextEditingController(text: pillar.name);
    final descriptionController =
        TextEditingController(text: pillar.description);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nombre del foro'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Ej. Círculo Cofrade',
                ),
                textCapitalization: TextCapitalization.sentences,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Texto corto bajo el nombre',
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 8),
              Text(
                'El id (${pillar.id}) no cambia; solo el nombre visible.',
                style: JuntaUi.caption(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (saved != true || !mounted) {
      nameController.dispose();
      descriptionController.dispose();
      return;
    }

    final name = nameController.text.trim();
    final description = descriptionController.text.trim();
    nameController.dispose();
    descriptionController.dispose();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre no puede estar vacío.')),
      );
      return;
    }

    await _update(name: name, description: description);
  }

  Future<void> _pickCover() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      imageQuality: 88,
    );
    if (file == null) return;

    setState(() => _busy = true);
    try {
      final bytes = await file.readAsBytes();
      final mime = switch (file.path.split('.').last.toLowerCase()) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      final url = await ref.read(adminRepositoryProvider).uploadPillarCover(
            pillarId: widget.pillar.id,
            bytes: bytes,
            mimeType: mime,
          );
      await ref.read(adminRepositoryProvider).updatePillar(
            pillarId: widget.pillar.id,
            coverImageUrl: url,
          );
      _refreshPillars();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Portada de ${widget.pillar.name} guardada')),
        );
      }
    } on PillarCoverTooLargeException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La imagen supera 5 MB.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo subir la portada.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editAppearance() async {
    final pillar = widget.pillar;
    final coverUrlController =
        TextEditingController(text: pillar.coverImageUrl ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Portada de ${pillar.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ForumPillarIconMark(forum: pillar, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'El icono del foro es fijo en la app y no se puede cambiar.',
                      style: JuntaUi.caption(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Portada del foro',
                style: JuntaUi.sectionTitle(),
              ),
              const SizedBox(height: 4),
              Text(
                'Se usa en la tarjeta del listado y en el header del detalle.',
                style: JuntaUi.caption(),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx, false);
                  await _pickCover();
                },
                icon: const Icon(Icons.wallpaper_outlined),
                label: const Text('Subir portada desde galería'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: coverUrlController,
                decoration: const InputDecoration(
                  labelText: 'URL de portada (opcional)',
                  hintText: 'https://…',
                ),
                keyboardType: TextInputType.url,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (saved != true || !mounted) {
      coverUrlController.dispose();
      return;
    }

    await _update(coverImageUrl: coverUrlController.text);
    coverUrlController.dispose();
  }

  Future<void> _confirmDelete() async {
    final pillar = widget.pillar;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Eliminar «${pillar.name}»?'),
        content: Text(
          pillar.topicCount > 0
              ? 'Se borrarán también sus ${pillar.topicCount} temas y todas las respuestas. No se puede deshacer.'
              : 'Se eliminará el foro de la lista. No se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.accentRed),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).deletePillar(pillar.id);
      ref.invalidate(adminPillarsProvider);
      invalidateForumPillarData(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('«${pillar.name}» eliminado')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo eliminar el foro.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onEnabledChanged(bool value) async {
    if (!value) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('¿Ocultar ${widget.pillar.name}?'),
          content: const Text(
            'Dejará de verse en la lista de FOROS. '
            'Podrás volver a mostrarlo cuando quieras desde Junta.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ocultar'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await _update(isEnabled: value);
  }

  @override
  Widget build(BuildContext context) {
    final pillar = widget.pillar;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ForumPillarIconMark(forum: pillar, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      JuntaCardTitleBlock(
                        title: pillar.name,
                        badges: [
                          if (!pillar.isEnabled)
                            const CofradeoBadge(label: 'Oculto'),
                        ],
                      ),
                      if (pillar.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          pillar.description,
                          style: JuntaUi.body(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (!pillar.isEnabled &&
                          pillar.lockedLabel != null &&
                          pillar.lockedLabel!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          pillar.lockedLabel!,
                          style: JuntaUi.caption(color: AppColors.accentRed),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _busy ? null : _editNameAndDescription,
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Cambiar nombre',
                  color: AppColors.burgundy,
                ),
                IconButton(
                  onPressed: _busy ? null : _editAppearance,
                  icon: const Icon(Icons.image_outlined),
                  tooltip: 'Cambiar portada',
                  color: AppColors.burgundy,
                ),
                IconButton(
                  onPressed: _busy ? null : _confirmDelete,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Eliminar foro',
                  color: AppColors.accentRed,
                ),
              ],
            ),
            const SizedBox(height: 14),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Visible en FOROS',
                style: JuntaUi.sectionTitle(),
              ),
              subtitle: Text(
                pillar.isEnabled
                    ? 'Los usuarios lo ven en la lista'
                    : 'Oculto: no aparece en FOROS',
                style: JuntaUi.caption(),
              ),
              value: pillar.isEnabled,
              onChanged: _busy ? null : _onEnabledChanged,
              activeThumbColor: AppColors.burgundy,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Badge «Activo»',
                style: JuntaUi.sectionTitle(),
              ),
              subtitle: Text(
                'Muestra la llama en la tarjeta del foro',
                style: JuntaUi.caption(),
              ),
              value: pillar.isActive,
              onChanged: _busy || !pillar.isEnabled
                  ? null
                  : (value) => _update(isActive: value),
              activeThumbColor: AppColors.burgundy,
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(message, style: JuntaUi.emptyTitle()),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ],
        ),
      ),
    );
  }
}

List<DropdownMenuItem<String>> _forumIconDropdownItems() {
  return [
    for (final key in forumIconByKey.keys)
      DropdownMenuItem(
        value: key,
        child: Row(
          children: [
            Icon(
              forumIconFromKey(key),
              size: 20,
              color: AppColors.burgundy,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                key,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
  ];
}

sealed class _PinnedTopicEditDialogResult {}

class _PinnedTopicEditPickGallery extends _PinnedTopicEditDialogResult {}

class _PinnedTopicEditSaved extends _PinnedTopicEditDialogResult {
  _PinnedTopicEditSaved({
    required this.iconKey,
    required this.excerpt,
    required this.body,
    required this.coverImageUrl,
  });

  final String iconKey;
  final String excerpt;
  final String body;
  final String coverImageUrl;
}

class _PinnedTopicEditDialog extends StatefulWidget {
  const _PinnedTopicEditDialog({required this.topic});

  final ForumTopic topic;

  @override
  State<_PinnedTopicEditDialog> createState() => _PinnedTopicEditDialogState();
}

class _PinnedTopicEditDialogState extends State<_PinnedTopicEditDialog> {
  late final TextEditingController _excerptController;
  late final TextEditingController _bodyController;
  late final TextEditingController _coverController;
  late String _selectedIcon;

  @override
  void initState() {
    super.initState();
    final topic = widget.topic;
    _excerptController = TextEditingController(text: topic.excerpt);
    _bodyController = TextEditingController(text: topic.body);
    _coverController = TextEditingController(text: topic.coverImageUrl ?? '');
    _selectedIcon = topic.iconKey ?? 'church';
  }

  @override
  void dispose() {
    _excerptController.dispose();
    _bodyController.dispose();
    _coverController.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.pop(
      context,
      _PinnedTopicEditSaved(
        iconKey: _selectedIcon,
        excerpt: _excerptController.text,
        body: _bodyController.text,
        coverImageUrl: _coverController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topic = widget.topic;

    return AlertDialog(
      title: Text('Editar ${topic.title}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Descripción', style: JuntaUi.sectionTitle()),
              const SizedBox(height: 8),
              TextField(
                controller: _excerptController,
                decoration: const InputDecoration(
                  labelText: 'Texto corto (tarjeta del foro)',
                  hintText: 'Ensayos del día en directo y conversación…',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bodyController,
                decoration: const InputDecoration(
                  labelText: 'Texto del espacio (hub)',
                  hintText: 'Párrafo de presentación al entrar al círculo',
                ),
                maxLines: 5,
                minLines: 3,
              ),
              const SizedBox(height: 20),
              Text('Apariencia', style: JuntaUi.sectionTitle()),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context, _PinnedTopicEditPickGallery());
                },
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Subir imagen desde galería'),
              ),
              const SizedBox(height: 12),
              Text(
                'Icono de respaldo si no hay imagen.',
                style: JuntaUi.caption(),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedIcon,
                isExpanded: true,
                items: _forumIconDropdownItems(),
                selectedItemBuilder: (context) {
                  return [
                    for (final key in forumIconByKey.keys)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Icon(
                              forumIconFromKey(key),
                              size: 18,
                              color: AppColors.burgundy,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                key,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ];
                },
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedIcon = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _coverController,
                decoration: const InputDecoration(
                  labelText: 'URL de imagen (opcional)',
                  hintText: 'https://…',
                ),
                keyboardType: TextInputType.url,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
