import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../../forums/topic_detail_typography.dart';
import '../../forums/widgets/hermandad_post_image_picker.dart';
import '../../profile/profile_provider.dart';
import '../data/ss_live_updates_repository.dart';
import '../models/ss_live_update.dart';
import '../semana_santa_provider.dart';
import '../utils/ss_informar_helpers.dart';
import '../widgets/ss_live_design.dart';

/// Paso 2: redactar y publicar el aviso.
class SsInformarComposeScreen extends ConsumerStatefulWidget {
  const SsInformarComposeScreen({
    super.key,
    required this.forumId,
    required this.topicId,
    required this.kind,
  });

  final String forumId;
  final String topicId;
  final SsLiveUpdateKind kind;

  @override
  ConsumerState<SsInformarComposeScreen> createState() =>
      _SsInformarComposeScreenState();
}

class _SsInformarComposeScreenState
    extends ConsumerState<SsInformarComposeScreen> {
  final _messageController = TextEditingController();
  final _placeController = TextEditingController();
  SsDayHermandadOption? _selected;
  double? _latitude;
  double? _longitude;
  Uint8List? _imageBytes;
  var _isLocating = false;
  var _isPosting = false;

  static const _maxChars = 200;

  @override
  void dispose() {
    _messageController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation() async {
    setState(() => _isLocating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activa la ubicación para compartir el lugar'),
          ),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        if (_placeController.text.trim().isEmpty) {
          _placeController.text = 'Mi ubicación';
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ubicación lista. Se enviará con el aviso.'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo obtener la ubicación')),
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _clearGps() {
    setState(() {
      _latitude = null;
      _longitude = null;
    });
  }

  Future<void> _submit() async {
    final profile = ref.read(currentUserProfileProvider).asData?.value;
    if (profile == null || profile.isSuspended) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicia sesión para publicar')),
      );
      return;
    }

    final gate = ref.read(ssLiveGateProvider).asData?.value;
    if (gate != null && !gate.isOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            gate.closedMessage.isEmpty
                ? 'El en directo está cerrado ahora'
                : gate.closedMessage,
          ),
        ),
      );
      return;
    }

    final canInform = await ref.read(ssCanInformProvider.future);
    if (!mounted) return;
    if (!canInform) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Solo reporteros de confianza y hermandades pueden informar.',
          ),
        ),
      );
      return;
    }

    final hermandad = _selected?.name.trim() ?? '';
    if (hermandad.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elige la hermandad')),
      );
      return;
    }

    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cuenta qué está ocurriendo')),
      );
      return;
    }

    setState(() => _isPosting = true);
    try {
      final repo = ref.read(ssLiveUpdatesRepositoryProvider);
      String? imageUrl;
      if (_imageBytes != null) {
        imageUrl = await repo.uploadLiveImage(
          userId: profile.id,
          bytes: _imageBytes!,
        );
      }
      final created = await repo.postUpdate(
            userId: profile.id,
            kind: widget.kind,
            message: message,
            authorHandle: profile.handle,
            hermandadLabel: hermandad,
            placeLabel: _placeController.text.trim(),
            imageUrl: imageUrl,
            latitude: _latitude,
            longitude: _longitude,
            isOfficial: profile.isOfficialHermandad,
          );
      ref.read(ssLiveRawFeedProvider.notifier).upsert(created);
      ref.read(ssLiveEngagementProvider.notifier).seedUpdate(created.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            profile.isOfficialHermandad
                ? 'Aviso oficial publicado · avisamos a tus seguidores'
                : 'Aviso publicado',
          ),
        ),
      );
      // Vuelve al hub de Semana Santa (no a la pantalla antigua de compose).
      context.go('/foros/${widget.forumId}/tema/${widget.topicId}');
    } on SsLiveUpdateRateLimitedException catch (err) {
      if (!mounted) return;
      final secs = err.waitSeconds.clamp(1, 45);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            secs == 1
                ? 'Espera 1 segundo antes de publicar otro aviso'
                : 'Espera $secs segundos antes de publicar otro aviso',
          ),
        ),
      );
    } on SsLiveUpdateImageTooLargeException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La imagen es demasiado grande')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo publicar el aviso')),
      );
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  Future<void> _pickHermandad(List<SsDayHermandadOption> options) async {
    final selected = await showModalBottomSheet<SsDayHermandadOption>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final maxH = MediaQuery.sizeOf(ctx).height * 0.7;
        return SizedBox(
          height: maxH,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Hermandad',
                        style: AppTypography.displaySmall().copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: options.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No hay hermandades listadas para esta jornada.',
                            textAlign: TextAlign.center,
                            style: TopicDetailTypography.meta(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        itemCount: options.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final option = options[index];
                          final isSelected = _selected?.name == option.name;
                          return Material(
                            color: isSelected
                                ? AppColors.burgundy.withValues(alpha: 0.08)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: () => Navigator.pop(ctx, option),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  12,
                                  10,
                                ),
                                child: Row(
                                  children: [
                                    _HermandadAvatar(option: option),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        option.name,
                                        style: TopicDetailTypography.body()
                                            .copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(
                                        Icons.check_rounded,
                                        color: AppColors.burgundy,
                                        size: 20,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
    if (selected != null && mounted) {
      setState(() => _selected = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = ssKindColor(widget.kind);
    final hermandadesAsync = ref.watch(ssDayHermandadesProvider);
    final options = hermandadesAsync.asData?.value ?? const [];
    final chars = _messageController.text.characters.length;
    final hasGps = _latitude != null && _longitude != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.chevron_left, color: AppColors.burgundy),
        ),
        title: Text(
          'Informar',
          style: AppTypography.displaySmall().copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          ssKindIcon(widget.kind),
                          color: color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.kind.label,
                              style: TopicDetailTypography.body(
                                color: AppColors.burgundy,
                              ).copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              ssInformarKindDescription(widget.kind),
                              style: TopicDetailTypography.meta(
                                color: AppColors.textSecondary,
                              ).copyWith(fontSize: 12.5, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    child: Ink(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.border.withValues(alpha: 0.8),
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Hermandad',
                            style: TopicDetailTypography.meta(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Material(
                            color: AppColors.backgroundElevated,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: hermandadesAsync.isLoading
                                  ? null
                                  : () => _pickHermandad(options),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  12,
                                  10,
                                  12,
                                ),
                                child: Row(
                                  children: [
                                    if (_selected != null) ...[
                                      _HermandadAvatar(
                                        option: _selected!,
                                        size: 28,
                                      ),
                                      const SizedBox(width: 10),
                                    ] else
                                      Icon(
                                        Icons.church_outlined,
                                        size: 20,
                                        color: AppColors.burgundy.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                    if (_selected == null)
                                      const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _selected?.name ??
                                            'Elige hermandad del día',
                                        style: TopicDetailTypography.body(
                                          color: _selected == null
                                              ? AppColors.textMuted
                                              : AppColors.textPrimary,
                                        ).copyWith(
                                          fontWeight: _selected == null
                                              ? FontWeight.w500
                                              : FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    if (_selected != null)
                                      IconButton(
                                        onPressed: () =>
                                            setState(() => _selected = null),
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 18,
                                        ),
                                      ),
                                    const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: AppColors.textMuted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            '¿Qué está ocurriendo?',
                            style: TopicDetailTypography.meta(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _messageController,
                            maxLength: _maxChars,
                            minLines: 3,
                            maxLines: 5,
                            onChanged: (_) => setState(() {}),
                            style: TopicDetailTypography.body().copyWith(
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  'Ej. Retraso de unos 15 minutos en Campana…',
                              hintStyle: TopicDetailTypography.meta(
                                color: AppColors.textMuted,
                              ),
                              filled: true,
                              fillColor: AppColors.backgroundElevated,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.all(12),
                              counterText: '$chars/$_maxChars',
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Lugar',
                            style: TopicDetailTypography.meta(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _placeController,
                            maxLength: 120,
                            style: TopicDetailTypography.body().copyWith(
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Calle, plaza o tramo…',
                              hintStyle: TopicDetailTypography.meta(
                                color: AppColors.textMuted,
                              ),
                              prefixIcon: const Icon(
                                Icons.place_outlined,
                                color: AppColors.burgundy,
                                size: 20,
                              ),
                              filled: true,
                              fillColor: AppColors.backgroundElevated,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              counterText: '',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          HermandadPostImagePicker(
                            enabled: !_isPosting,
                            sectionTitle: 'FOTO',
                            sectionSubtitle:
                                'Opcional · se verá compacta en el chat',
                            maxBytes: SsLiveUpdatesRepository.maxImageBytes,
                            onChanged: ({bytes, mimeType, existingUrl}) {
                              setState(() => _imageBytes = bytes);
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: _isLocating ? null : _useMyLocation,
                                icon: _isLocating
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.my_location_rounded,
                                        size: 16,
                                      ),
                                label: Text(
                                  hasGps
                                      ? 'Ubicación añadida'
                                      : 'Usar mi ubicación actual',
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.burgundy,
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                              if (hasGps)
                                TextButton(
                                  onPressed: _clearGps,
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.textMuted,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text('Quitar GPS'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 48,
                            child: FilledButton(
                              onPressed: _isPosting ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.burgundy,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isPosting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Publicar aviso',
                                      style: TopicDetailTypography.body(
                                        color: Colors.white,
                                      ).copyWith(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HermandadAvatar extends StatelessWidget {
  const _HermandadAvatar({required this.option, this.size = 32});

  final SsDayHermandadOption option;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = option.iconImageUrl?.trim();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.burgundy.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null && url.isNotEmpty
          ? CofradeoNetworkImage(
              url: url,
              fit: BoxFit.contain,
              width: size,
              height: size,
              cacheSize: size * 2,
              errorWidget: Icon(
                Icons.church_outlined,
                size: size * 0.5,
                color: AppColors.burgundy,
              ),
            )
          : Icon(
              Icons.church_outlined,
              size: size * 0.5,
              color: AppColors.burgundy,
            ),
    );
  }
}
