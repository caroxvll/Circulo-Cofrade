import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/cofradeo_badge.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../../../shared/models/forum.dart';
import '../../forums/forums_provider.dart';
import '../../forums/utils/editorial_post.dart';
import '../../forums/widgets/forum_compose_field.dart';
import '../admin_provider.dart';
import '../junta_ui.dart';

class JuntaEditorialTab extends ConsumerStatefulWidget {
  const JuntaEditorialTab({super.key});

  @override
  ConsumerState<JuntaEditorialTab> createState() => _JuntaEditorialTabState();
}

class _JuntaEditorialTabState extends ConsumerState<JuntaEditorialTab> {
  Future<void> _reload() async {
    ref.invalidate(editorialPostsProvider);
    await ref.read(editorialPostsProvider.future);
  }

  Future<void> _compose() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      builder: (context) => const _EditorialComposeSheet(),
    );
    if (created == true && mounted) {
      await _reload();
      ref.invalidate(pendingTopicsProvider);
      ref.invalidate(forumTopicsProvider(editorialForumId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(editorialPostsProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return postsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => JuntaEmptyPanel(
        icon: Icons.error_outline,
        message: 'No se pudieron cargar las publicaciones.',
        onRetry: () => ref.invalidate(editorialPostsProvider),
      ),
      data: (posts) {
        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: _reload,
              child: posts.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: JuntaUi.listPadding,
                      children: [
                        const JuntaInfoBanner(
                          text:
                              'Publicaciones de Círculo Cofrade para Para ti. '
                              'El admin publica al momento; el moderador envía a revisión.',
                        ),
                        const SizedBox(height: 48),
                        JuntaEmptyPanel(
                          icon: Icons.campaign_outlined,
                          message: 'Aún no hay publicaciones oficiales',
                          subtitle: isAdmin
                              ? 'Crea la primera para dar vida a Para ti.'
                              : 'Redacta una y la Junta la revisará.',
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: JuntaUi.listPadding,
                      itemCount: posts.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return const JuntaInfoBanner(
                            text:
                                'Salen en Para ti como Círculo Cofrade. '
                                'Debajo aparece «Vía» con quien las redactó.',
                          );
                        }
                        return _EditorialPostCard(topic: posts[index - 1]);
                      },
                    ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                onPressed: _compose,
                backgroundColor: AppColors.burgundy,
                foregroundColor: AppColors.textOnDark,
                icon: const Icon(Icons.add),
                label: Text(isAdmin ? 'Nueva' : 'Proponer'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EditorialPostCard extends ConsumerWidget {
  const _EditorialPostCard({required this.topic});

  final ForumTopic topic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final via = editorialViaLabel(topic);
    final cover = topic.coverImageUrl?.trim();

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/foros/${topic.forumId}/tema/${topic.id}'),
        child: Container(
          padding: JuntaUi.cardPadding,
          decoration: JuntaUi.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const AppLogo(size: 36, useIconVariant: true),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(editorialPublicName, style: JuntaUi.cardTitle()),
                        if (via.isNotEmpty)
                          Text(via, style: JuntaUi.caption()),
                      ],
                    ),
                  ),
                  CofradeoBadge(
                    label: switch (topic.status) {
                      TopicStatus.published => 'Publicada',
                      TopicStatus.pending => 'Pendiente',
                      TopicStatus.rejected => 'Rechazada',
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(topic.title, style: JuntaUi.sectionTitle()),
              if (topic.excerpt.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  topic.excerpt,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: JuntaUi.body(),
                ),
              ],
              if (topic.hasReadyEditorialVideo) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if ((topic.editorialPosterUrl ?? cover)?.isNotEmpty ==
                            true)
                          CofradeoNetworkImage(
                            url: topic.editorialPosterUrl ?? cover!,
                            fit: BoxFit.cover,
                            cacheSize: 640,
                          )
                        else
                          const ColoredBox(color: AppColors.backgroundElevated),
                        const Center(
                          child: Icon(
                            Icons.play_circle_fill,
                            size: 44,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (cover != null && cover.isNotEmpty) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CofradeoNetworkImage(
                      url: cover,
                      fit: BoxFit.cover,
                      cacheSize: 640,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                [
                  if (topic.hasReadyEditorialVideo) 'Vídeo',
                  topic.timeAgo,
                ].join(' · '),
                style: JuntaUi.caption(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorialComposeSheet extends ConsumerStatefulWidget {
  const _EditorialComposeSheet();

  @override
  ConsumerState<_EditorialComposeSheet> createState() =>
      _EditorialComposeSheetState();
}

class _EditorialComposeSheetState extends ConsumerState<_EditorialComposeSheet> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  Uint8List? _coverBytes;
  String? _coverMime;
  Uint8List? _videoBytes;
  String? _videoMime;
  String? _videoName;
  var _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1920,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final mime = switch (file.name.split('.').last.toLowerCase()) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    if (!mounted) return;
    setState(() {
      _coverBytes = bytes;
      _coverMime = mime;
    });
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) return;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo leer el vídeo')),
      );
      return;
    }
    if (bytes.length > editorialVideoMaxBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El vídeo supera 80 MB')),
      );
      return;
    }
    final ext = (file.extension ?? '').toLowerCase();
    final mime = switch (ext) {
      'webm' => 'video/webm',
      'mov' => 'video/quicktime',
      _ => 'video/mp4',
    };
    if (!mounted) return;
    setState(() {
      _videoBytes = bytes;
      _videoMime = mime;
      _videoName = file.name;
    });
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El título es demasiado corto')),
      );
      return;
    }
    if (body.isEmpty && _coverBytes == null && _videoBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escribe un texto, añade una imagen o un vídeo'),
        ),
      );
      return;
    }
    if (_videoBytes != null && (_coverBytes == null || _coverBytes!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Añade una imagen de portada para el vídeo'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      final topic = await repo.createEditorialPost(
        title: title,
        body: body.isEmpty ? title : body,
      );

      String? coverUrl;
      if (_coverBytes != null && _coverBytes!.isNotEmpty) {
        coverUrl = await ref.read(forumsRepositoryProvider).uploadTopicCover(
              topicId: topic.id,
              bytes: _coverBytes!,
              mimeType: _coverMime ?? 'image/jpeg',
            );
        await repo.setEditorialCover(
          topicId: topic.id,
          coverImageUrl: coverUrl,
        );
      }

      if (_videoBytes != null && _videoBytes!.isNotEmpty) {
        await repo.setEditorialVideo(
          topicId: topic.id,
          videoStatus: 'uploading',
          videoPosterUrl: coverUrl,
        );
        final upload = await repo.requestEditorialVideoUpload(
          topicId: topic.id,
          contentType: _videoMime ?? 'video/mp4',
          byteLength: _videoBytes!.length,
        );
        final put = await http.put(
          Uri.parse(upload.uploadUrl),
          headers: {
            'Content-Type': _videoMime ?? 'video/mp4',
            'Content-Length': '${_videoBytes!.length}',
          },
          body: _videoBytes,
        );
        if (put.statusCode < 200 || put.statusCode >= 300) {
          await repo.setEditorialVideo(
            topicId: topic.id,
            videoStatus: 'failed',
            videoPosterUrl: coverUrl,
          );
          throw StateError('upload failed ${put.statusCode}');
        }
        await repo.setEditorialVideo(
          topicId: topic.id,
          videoUrl: upload.publicUrl,
          videoPosterUrl: coverUrl,
          videoStatus: 'ready',
        );
      }

      if (!mounted) return;
      final pending = topic.isPending;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            pending
                ? 'Enviada a revisión de la Junta'
                : 'Publicada en Para ti',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo publicar. ¿SQL + Edge Function R2 listos?',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isAdmin ? 'Nueva publicación oficial' : 'Proponer publicación',
              style: JuntaUi.cardTitle(),
            ),
            const SizedBox(height: 4),
            Text(
              'Se publicará como $editorialPublicName',
              style: JuntaUi.caption(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: JuntaUi.inputDecoration(labelText: 'Título'),
            ),
            const SizedBox(height: 12),
            Text(
              'TEXTO',
              style: JuntaUi.caption().copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            ForumComposeField(
              controller: _bodyController,
              minLines: 5,
              maxLines: 10,
              toolbar: ForumComposeToolbar.editorial,
              hintText:
                  'Redacta con párrafos, negrita, listas o citas…',
            ),
            const SizedBox(height: 12),
            if (_coverBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.memory(_coverBytes!, fit: BoxFit.cover),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickCover,
                icon: const Icon(Icons.image_outlined),
                label: Text(
                  _videoBytes == null
                      ? 'Añadir imagen'
                      : 'Portada del vídeo (obligatoria)',
                ),
              ),
            if (_coverBytes != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _saving
                    ? null
                    : () => setState(() {
                          _coverBytes = null;
                          _coverMime = null;
                        }),
                child: const Text('Quitar imagen'),
              ),
            ],
            const SizedBox(height: 8),
            if (_videoBytes != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.videocam_outlined),
                title: Text(
                  _videoName ?? 'Vídeo adjunto',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${(_videoBytes!.length / (1024 * 1024)).toStringAsFixed(1)} MB',
                ),
                trailing: IconButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                            _videoBytes = null;
                            _videoMime = null;
                            _videoName = null;
                          }),
                  icon: const Icon(Icons.close),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickVideo,
                icon: const Icon(Icons.videocam_outlined),
                label: const Text('Añadir vídeo (R2, máx. 80 MB)'),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.burgundy,
                foregroundColor: AppColors.textOnDark,
                minimumSize: const Size.fromHeight(48),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isAdmin ? 'Publicar' : 'Enviar a revisión'),
            ),
          ],
        ),
      ),
    );
  }
}
