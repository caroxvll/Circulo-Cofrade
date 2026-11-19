import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/cofradeo_badge.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../../../shared/models/forum.dart';
import '../../forums/forums_provider.dart';
import '../../forums/para_ti_pulse_provider.dart';
import '../../forums/utils/editorial_post.dart';
import '../../forums/widgets/editorial_photo_stack.dart';
import '../../forums/widgets/forum_compose_field.dart';
import '../../forums/widgets/forum_compose_sheet_header.dart';
import '../../forums/widgets/forum_compose_sheet_layout.dart';
import '../admin_provider.dart';
import '../junta_ui.dart';

Future<bool> showEditorialComposeSheet(BuildContext context) async {
  return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: true,
        enableDrag: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) => const _EditorialComposeSheet(),
      ) ??
      false;
}

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
    final created = await showEditorialComposeSheet(context);
    if (created && mounted) {
      await _reload();
      ref.invalidate(pendingTopicsProvider);
      ref.invalidate(forumTopicsProvider(editorialForumId));
      ref.invalidate(publishedEditorialPostsProvider);
      ref.invalidate(paraTiRiverProvider);
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
                  const AppLogo(size: 36, useIconVariant: true, circular: true),
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
              if (topic.hasEditorialVideoMedia) ...[
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
              ] else if (topic.editorialImageUrls.length > 1) ...[
                const SizedBox(height: 10),
                EditorialPhotoStack.network(
                  urls: topic.editorialImageUrls,
                  onTap: () => openEditorialPhotoGallery(
                    context,
                    topic.editorialImageUrls,
                    shareText: topic.title,
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
                  if (topic.hasProcessingEditorialVideo)
                    'Optimizando'
                  else if (topic.hasReadyEditorialVideo)
                    'Vídeo',
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
  final _photos = <Uint8List>[];
  Uint8List? _videoBytes;
  String? _videoMime;
  String? _videoName;
  var _saving = false;
  double? _uploadProgress;
  var _uploadAttempt = 0;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    if (_videoBytes != null) {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1920,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photos
          ..clear()
          ..add(bytes);
      });
      return;
    }

    final remaining = editorialGalleryMaxImages - _photos.length;
    if (remaining <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Máximo 4 fotos')),
      );
      return;
    }
    final files = await ImagePicker().pickMultiImage(
      imageQuality: 88,
      maxWidth: 1920,
      limit: remaining,
    );
    if (files.isEmpty) return;
    final next = <Uint8List>[];
    for (final file in files) {
      if (_photos.length + next.length >= editorialGalleryMaxImages) break;
      next.add(await file.readAsBytes());
    }
    if (!mounted) return;
    setState(() => _photos.addAll(next));
    if (files.length > next.length && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo caben 4 fotos. La primera queda delante.'),
        ),
      );
    }
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
        const SnackBar(content: Text('El vídeo supera 500 MB')),
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
    final hadPile = _photos.length > 1;
    setState(() {
      _videoBytes = bytes;
      _videoMime = mime;
      _videoName = file.name;
      if (hadPile) _photos.clear();
    });
    if (hadPile && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El vídeo va con una sola portada, no con el montón.'),
        ),
      );
    }
  }

  Future<bool> _uploadVideoWithRetries({
    required String uploadUrl,
    required String uploadMethod,
    required Uint8List bytes,
    required String contentType,
    String? fileName,
  }) async {
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (!mounted) return false;
      setState(() {
        _uploadAttempt = attempt;
        _uploadProgress = 0;
      });
      try {
        if (uploadMethod.toUpperCase() == 'TUS') {
          final uploaded = await _uploadTus(uploadUrl: uploadUrl, bytes: bytes);
          if (uploaded) return true;
        } else if (uploadMethod.toUpperCase() == 'POST') {
          // Cloudflare Stream: multipart POST a uploadURL de un solo uso.
          final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: fileName ?? 'video.mp4',
              contentType: MediaType.parse(contentType),
            ),
          );
          if (mounted) setState(() => _uploadProgress = 0.15);
          final response = await request.send().timeout(
                const Duration(minutes: 12),
              );
          if (mounted) setState(() => _uploadProgress = 1);
          if (response.statusCode >= 200 && response.statusCode < 300) {
            return true;
          }
          if (response.statusCode < 500 &&
              response.statusCode != 408 &&
              response.statusCode != 429) {
            return false;
          }
        } else {
          final request = http.StreamedRequest('PUT', Uri.parse(uploadUrl))
            ..headers['Content-Type'] = contentType
            ..contentLength = bytes.length;
          final responseFuture = request.send().timeout(
                const Duration(minutes: 8),
              );
          const chunkSize = 256 * 1024;
          for (var offset = 0; offset < bytes.length; offset += chunkSize) {
            final end = (offset + chunkSize < bytes.length)
                ? offset + chunkSize
                : bytes.length;
            request.sink.add(Uint8List.sublistView(bytes, offset, end));
            if (mounted) {
              setState(() => _uploadProgress = end / bytes.length);
            }
            await Future<void>.delayed(Duration.zero);
          }
          await request.sink.close();
          final response = await responseFuture;
          if (response.statusCode >= 200 && response.statusCode < 300) {
            return true;
          }
          if (response.statusCode < 500 &&
              response.statusCode != 408 &&
              response.statusCode != 429) {
            return false;
          }
        }
      } catch (_) {
        // Un corte breve se reintenta automáticamente.
      }
      if (attempt < maxAttempts) {
        await Future<void>.delayed(Duration(seconds: attempt * 2));
      }
    }
    return false;
  }

  /// Subida a Stream por trozos. El POST simple se corta en 200 MB; tus no.
  /// Cada trozo intermedio mide 50 MB (múltiplo de 256 KiB). El último puede ser menor.
  Future<bool> _uploadTus({
    required String uploadUrl,
    required Uint8List bytes,
  }) async {
    const chunkSize = 50 * 1024 * 1024;
    const maxChunkAttempts = 3;
    var offset = await _tusOffset(uploadUrl);
    if (offset < 0 || offset > bytes.length) return false;

    while (offset < bytes.length) {
      final end = offset + chunkSize < bytes.length
          ? offset + chunkSize
          : bytes.length;
      var sent = false;
      for (var attempt = 1; attempt <= maxChunkAttempts && offset < end; attempt++) {
        if (!mounted) return false;
        try {
          final request = http.Request('PATCH', Uri.parse(uploadUrl))
            ..headers['Tus-Resumable'] = '1.0.0'
            ..headers['Upload-Offset'] = '$offset'
            ..headers['Content-Type'] = 'application/offset+octet-stream'
            ..bodyBytes = Uint8List.sublistView(bytes, offset, end);
          final response = await request.send().timeout(
                const Duration(minutes: 8),
              );
          await response.stream.drain<void>();
          if (response.statusCode >= 200 && response.statusCode < 300) {
            offset =
                int.tryParse(response.headers['upload-offset'] ?? '') ?? end;
            sent = true;
            if (mounted && bytes.isNotEmpty) {
              setState(() => _uploadProgress = offset / bytes.length);
            }
            break;
          }
          if (response.statusCode == 409) {
            final resumed = await _tusOffset(uploadUrl);
            if (resumed > offset) offset = resumed;
            if (offset >= end) {
              sent = true;
              break;
            }
          } else if (response.statusCode < 500 &&
              response.statusCode != 408 &&
              response.statusCode != 429) {
            return false;
          }
        } catch (_) {
          // El siguiente intento retoma por el offset que Stream ya tenga.
        }
        if (!sent && attempt < maxChunkAttempts) {
          await Future<void>.delayed(Duration(seconds: attempt * 2));
          final resumed = await _tusOffset(uploadUrl);
          if (resumed > offset) offset = resumed;
        }
      }
      if (!sent || offset < end) return false;
    }
    return true;
  }

  Future<int> _tusOffset(String uploadUrl) async {
    try {
      final request = http.Request('HEAD', Uri.parse(uploadUrl))
        ..headers['Tus-Resumable'] = '1.0.0';
      final response = await request.send().timeout(const Duration(seconds: 20));
      await response.stream.drain<void>();
      if (response.statusCode < 200 || response.statusCode >= 300) return 0;
      return int.tryParse(response.headers['upload-offset'] ?? '') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _waitForStreamReady({
    required String topicId,
  }) async {
    final repo = ref.read(adminRepositoryProvider);
    for (var i = 0; i < 10; i++) {
      if (!mounted) return;
      final ready = await repo.finalizeEditorialVideo(topicId: topicId);
      if (ready) return;
      await Future<void>.delayed(Duration(seconds: 2 + (i ~/ 2)));
    }
  }

  String _publishErrorMessage(Object error) {
    if (error is FunctionException) {
      final details = error.details;
      if (details is Map) {
        final message = details['error']?.toString().trim() ?? '';
        if (message.isNotEmpty) return message;
      }
      if (details is String && details.trim().isNotEmpty) return details.trim();
    }
    if (error is StateError && error.message.contains('portada')) {
      return 'Sin Cloudflare Stream el vídeo necesita portada y no puede pasar de 150 MB.';
    }
    if (_uploadAttempt > 0) {
      return 'No se pudo subir el vídeo tras $_uploadAttempt intentos.';
    }
    return 'No se pudo publicar. Revisa la conexión y la configuración.';
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
    if (body.isEmpty && _photos.isEmpty && _videoBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escribe un texto, añade una imagen o un vídeo'),
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
      if (_photos.isNotEmpty) {
        final forums = ref.read(forumsRepositoryProvider);
        final urls = <String>[];
        for (var i = 0; i < _photos.length; i++) {
          urls.add(
            await forums.uploadEditorialImage(
              topicId: topic.id,
              bytes: _photos[i],
              index: i,
            ),
          );
        }
        coverUrl = urls.first;
        if (urls.length == 1) {
          await repo.setEditorialCover(
            topicId: topic.id,
            coverImageUrl: coverUrl,
          );
        } else {
          await repo.setEditorialGallery(
            topicId: topic.id,
            coverImageUrl: coverUrl,
            galleryImageUrls: urls.sublist(1),
          );
        }
      }

      var videoProcessing = false;
      if (_videoBytes != null && _videoBytes!.isNotEmpty) {
        final contentType = _videoMime ?? 'video/mp4';
        await repo.setEditorialVideo(
          topicId: topic.id,
          videoStatus: 'uploading',
          videoPosterUrl: coverUrl,
        );
        final upload = await repo.requestEditorialVideoUpload(
          topicId: topic.id,
          contentType: contentType,
          byteLength: _videoBytes!.length,
        );
        final streamMode = upload.mode == 'stream';
        final poster = coverUrl ?? upload.posterUrl;
        final uploaded = await _uploadVideoWithRetries(
          uploadUrl: upload.uploadUrl,
          uploadMethod: upload.uploadMethod,
          bytes: _videoBytes!,
          contentType: contentType,
          fileName: _videoName,
        );
        if (!uploaded) {
          await repo.setEditorialVideo(
            topicId: topic.id,
            videoStatus: 'failed',
            videoPosterUrl: poster,
            videoProvider: upload.mode,
            videoExternalId: upload.externalId,
          );
          throw StateError('video upload failed');
        }
        if (streamMode) {
          // HLS: poster automático de Stream; listo cuando finalize/webhook.
          await repo.setEditorialVideo(
            topicId: topic.id,
            videoUrl: upload.publicUrl,
            videoPosterUrl: poster,
            videoStatus: 'processing',
            videoProvider: 'stream',
            videoExternalId: upload.externalId,
          );
          videoProcessing = true;
          await _waitForStreamReady(topicId: topic.id);
        } else {
          if (poster == null || poster.isEmpty) {
            throw StateError('R2 requiere portada manual');
          }
          await repo.setEditorialVideo(
            topicId: topic.id,
            videoUrl: upload.publicUrl,
            videoPosterUrl: poster,
            videoStatus: 'ready',
            videoProvider: 'r2',
            videoExternalId: upload.externalId,
          );
        }
      }

      if (!mounted) return;
      final pending = topic.isPending;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            pending
                ? 'Enviada a revisión de la Junta'
                : videoProcessing
                    ? 'Publicada · optimizando vídeo (HLS)'
                    : 'Publicada en Para ti',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_publishErrorMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _uploadProgress = null;
          _uploadAttempt = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);

    return PopScope(
      canPop: !_saving,
      child: ForumComposeSheetLayout(
        header: ForumComposeSheetTitleBar(
          closeEnabled: !_saving,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAdmin ? 'Nueva publicación oficial' : 'Proponer publicación',
                style: JuntaUi.cardTitle(),
              ),
              const SizedBox(height: 4),
              Text(
                'Se publicará como $editorialPublicName',
                style: JuntaUi.caption(),
              ),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
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
            if (_photos.length > 1)
              EditorialPhotoStack.memory(images: _photos)
            else if (_photos.length == 1)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.memory(_photos.single, fit: BoxFit.cover),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickPhotos,
                icon: Icon(
                  _videoBytes == null
                      ? Icons.photo_library_outlined
                      : Icons.image_outlined,
                ),
                label: Text(
                  _videoBytes == null
                      ? 'Añadir fotos'
                      : 'Portada (opcional · Stream la genera)',
                ),
              ),
            if (_photos.isNotEmpty) ...[
              if (_photos.length > 1) ...[
                const SizedBox(height: 8),
                Text(
                  'Hasta 4. La primera queda delante.',
                  style: JuntaUi.caption(),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 76,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photos.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      return SizedBox(
                        width: 76,
                        height: 76,
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                _photos[index],
                                width: 76,
                                height: 76,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: Material(
                                color: Colors.black54,
                                shape: const CircleBorder(),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: _saving
                                      ? null
                                      : () => setState(
                                            () => _photos.removeAt(index),
                                          ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(2),
                                    child: Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  if (_videoBytes == null &&
                      _photos.length < editorialGalleryMaxImages)
                    TextButton(
                      onPressed: _saving ? null : _pickPhotos,
                      child: const Text('Añadir más'),
                    ),
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => setState(_photos.clear),
                    child: Text(
                      _photos.length > 1 ? 'Quitar fotos' : 'Quitar imagen',
                    ),
                  ),
                ],
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
            else if (_photos.length <= 1)
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickVideo,
                icon: const Icon(Icons.videocam_outlined),
                label: const Text('Añadir vídeo (HLS, máx. 500 MB / 10 min)'),
              ),
            if (_saving && _uploadProgress != null) ...[
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: _uploadProgress,
                color: AppColors.burgundy,
                backgroundColor: AppColors.backgroundElevated,
              ),
              const SizedBox(height: 6),
              Text(
                'Subiendo vídeo · ${(_uploadProgress! * 100).round()}%'
                '${_uploadAttempt > 1 ? ' · intento $_uploadAttempt de 3' : ''}',
                textAlign: TextAlign.center,
                style: JuntaUi.caption(),
              ),
            ],
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
