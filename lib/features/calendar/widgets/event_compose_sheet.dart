import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_upload_compress.dart';
import '../../../core/widgets/cofradeo_bottom_nav.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../../../core/widgets/event_type_icon.dart';
import '../../../shared/models/calendar_event.dart';
import '../../auth/auth_provider.dart';
import '../../auth/email_verification_gate.dart';
import '../../permissions/permissions_provider.dart';
import '../../profile/profile_provider.dart';
import '../calendar_provider.dart';
import '../data/calendar_repository.dart';
import '../utils/calendar_event_utils.dart';
import 'organizer_picker_sheet.dart';

Future<void> showEventComposeSheet(
  BuildContext context,
  WidgetRef ref, {
  DateTime? initialDate,
  CalendarEvent? existing,
}) async {
  final isAuth = ref.read(isAuthenticatedProvider);
  if (!isAuth) {
    if (context.mounted) {
      await context.push(
        '/login?redirect=${Uri.encodeComponent('/calendario')}',
      );
    }
    return;
  }

  if (!await ensureEmailVerifiedForEngage(context, ref)) return;

  if (!ref.read(isCalendarEditorProvider)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Solo moderadores de foro pueden proponer eventos al calendario.',
          ),
        ),
      );
    }
    return;
  }

  if (ref.read(isCurrentUserSuspendedProvider)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu cuenta está suspendida. No puedes crear eventos.'),
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
            'Conecta Supabase (env.json) para publicar eventos reales.',
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
    builder: (_) =>
        _EventComposeSheet(initialDate: initialDate, existing: existing),
  );
}

class _EventComposeSheet extends ConsumerStatefulWidget {
  const _EventComposeSheet({this.initialDate, this.existing});

  final DateTime? initialDate;
  final CalendarEvent? existing;

  @override
  ConsumerState<_EventComposeSheet> createState() => _EventComposeSheetState();
}

class _EventComposeSheetState extends ConsumerState<_EventComposeSheet> {
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _locationController = TextEditingController();
  final _organizerController = TextEditingController();

  late DateTime _date;
  late TimeOfDay _time;
  late EventType _type;
  bool _submitting = false;
  String? _error;
  String? _customIconUrl;
  String? _coverImageUrl;
  String? _selectedIconName;
  String? _selectedIconExtension;
  String? _selectedIconContentType;
  Uint8List? _selectedIconBytes;
  String? _selectedCoverName;
  String? _selectedCoverExtension;
  String? _selectedCoverContentType;
  Uint8List? _selectedCoverBytes;
  Timer? _organizerDebounce;
  var _shieldFromLibrary = false;
  var _shieldManualOverride = false;
  String? _shieldSkipAutoLoadKey;
  var _loadingOrganizerShield = false;
  var _processingImagePick = false;
  String? _initialOrganizerKey;

  bool get _isEditing => widget.existing?.id != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;

    if (existing != null) {
      _titleController.text = existing.title;
      _subtitleController.text = existing.subtitle;
      _locationController.text = existing.location ?? '';
      _organizerController.text = existing.organizerLabel ?? '';
      _date = existing.date;
      _type = existing.type;
      _customIconUrl = existing.customIconUrl;
      _coverImageUrl = existing.coverImageUrl;
      final parts = existing.time?.split(':');
      _time = parts != null && parts.length >= 2
          ? TimeOfDay(
              hour: int.tryParse(parts[0]) ?? 12,
              minute: int.tryParse(parts[1]) ?? 0,
            )
          : const TimeOfDay(hour: 12, minute: 0);
    } else {
      _date = DateTime(
        (widget.initialDate ?? DateTime.now()).year,
        (widget.initialDate ?? DateTime.now()).month,
        (widget.initialDate ?? DateTime.now()).day,
      );
      _time = defaultTimeForEventDate(_date);
      _type = EventType.procesion;
      // No pre-rellenar con el handle del perfil; el organizador es la hermandad/banda.
      _organizerController.text = '';
    }

    _initialOrganizerKey = normalizeOrganizerKey(_organizerController.text);

    _organizerController.addListener(_onOrganizerChanged);
    _scheduleOrganizerShieldLookup();
  }

  void _onOrganizerChanged() {
    final key = normalizeOrganizerKey(_organizerController.text);
    if (_shieldSkipAutoLoadKey != null && _shieldSkipAutoLoadKey != key) {
      _shieldSkipAutoLoadKey = null;
    }
    _scheduleOrganizerShieldLookup();
  }

  void _scheduleOrganizerShieldLookup() {
    _organizerDebounce?.cancel();
    _organizerDebounce = Timer(const Duration(milliseconds: 420), () {
      unawaited(_tryLoadOrganizerShield());
    });
  }

  Future<void> _tryLoadOrganizerShield() async {
    if (_shieldManualOverride || _selectedIconBytes != null) return;

    final organizer = _organizerController.text.trim();
    if (organizer.length < 3) return;

    final key = normalizeOrganizerKey(organizer);
    if (_shieldSkipAutoLoadKey == key) return;

    if (_isEditing &&
        widget.existing?.customIconUrl?.trim().isNotEmpty == true &&
        key == _initialOrganizerKey) {
      return;
    }

    setState(() => _loadingOrganizerShield = true);

    try {
      final logoUrl = await ref
          .read(calendarRepositoryProvider)
          .fetchOrganizerLogo(organizer);
      if (!mounted) return;
      if (logoUrl == null || logoUrl.isEmpty) {
        setState(() => _loadingOrganizerShield = false);
        return;
      }
      if (_shieldManualOverride || _selectedIconBytes != null) return;

      setState(() {
        _customIconUrl = logoUrl;
        _shieldFromLibrary = true;
        _selectedIconName = null;
        _selectedIconBytes = null;
        _selectedIconExtension = null;
        _selectedIconContentType = null;
        _loadingOrganizerShield = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingOrganizerShield = false);
    }
  }

  Future<void> _openOrganizerLibrary() async {
    final picked = await OrganizerPickerSheet.show(context);
    if (picked == null || !mounted) return;

    setState(() {
      _organizerController.text = picked.displayLabel;
      _shieldSkipAutoLoadKey = null;
      _shieldManualOverride = false;
      _selectedIconName = null;
      _selectedIconBytes = null;
      _selectedIconExtension = null;
      _selectedIconContentType = null;
      _initialOrganizerKey = picked.organizerKey;

      if (picked.hasLogo) {
        _customIconUrl = picked.logoUrl;
        _shieldFromLibrary = true;
      } else {
        _customIconUrl = null;
        _shieldFromLibrary = false;
      }
    });
  }

  void _ensureTimeNotInPast() {
    if (_isEditing) return;
    ensureEventTimeNotInPast(
      date: _date,
      time: _time,
      onAdjusted: (adjusted) => _time = adjusted,
    );
  }

  @override
  void dispose() {
    _organizerDebounce?.cancel();
    _organizerController.removeListener(_onOrganizerChanged);
    _titleController.dispose();
    _subtitleController.dispose();
    _locationController.dispose();
    _organizerController.dispose();
    super.dispose();
  }

  DateTime get _startsAt =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035, 12, 31),
      locale: const Locale('es'),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _ensureTimeNotInPast();
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) {
      setState(() {
        _time = picked;
        _ensureTimeNotInPast();
      });
    }
  }

  Future<void> _pickCover() async {
    if (_processingImagePick) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'webp', 'jpg', 'jpeg'],
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;

    final extension = (file.extension ?? '').toLowerCase();
    final contentType = _contentTypeForExtension(extension);
    if (contentType == null || extension == 'svg') {
      setState(() => _error = 'La portada debe ser PNG, WebP o JPG.');
      return;
    }
    if (bytes.length > ImageUploadLimits.eventCoverPickMaxBytes) {
      setState(
        () => _error = 'La portada es demasiado grande. Prueba con otra foto.',
      );
      return;
    }

    setState(() {
      _processingImagePick = true;
      _error = null;
    });

    try {
      final prepared = await prepareImageUploadAsync(
        rawBytes: bytes,
        extension: extension,
        contentType: contentType,
        maxBytes: ImageUploadLimits.eventCoverMaxBytes,
        maxSide: ImageUploadLimits.eventCoverMaxSide,
      );
      if (!mounted) return;

      if (prepared.wasCompressed && prepared.originalBytes != null) {
        _showOptimizedSnackBar(
          prepared.originalBytes!,
          prepared.bytes.length,
        );
      }

      setState(() {
        _selectedCoverBytes = prepared.bytes;
        _selectedCoverName = file.name;
        _selectedCoverExtension = prepared.extension;
        _selectedCoverContentType = prepared.contentType;
        _coverImageUrl = null;
        _processingImagePick = false;
      });
    } on ImageTooLargeAfterCompressException {
      if (mounted) {
        setState(() {
          _error = 'La portada es demasiado grande. Prueba con otra foto.';
          _processingImagePick = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo procesar la portada.';
          _processingImagePick = false;
        });
      }
    }
  }

  void _clearCover() {
    setState(() {
      _coverImageUrl = null;
      _selectedCoverBytes = null;
      _selectedCoverName = null;
      _selectedCoverExtension = null;
      _selectedCoverContentType = null;
    });
  }

  Future<void> _pickIcon() async {
    if (_processingImagePick) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['svg', 'png', 'webp', 'jpg', 'jpeg'],
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;

    final extension = (file.extension ?? '').toLowerCase();
    final contentType = _contentTypeForExtension(extension);
    if (contentType == null) {
      setState(() => _error = 'El icono debe ser SVG, PNG, WebP o JPG.');
      return;
    }
    if (bytes.length > ImageUploadLimits.eventIconPickMaxBytes) {
      setState(
        () => _error = 'El escudo es demasiado grande. Prueba con otra imagen.',
      );
      return;
    }

    setState(() {
      _processingImagePick = true;
      _error = null;
    });

    try {
      final prepared = await prepareImageUploadAsync(
        rawBytes: bytes,
        extension: extension,
        contentType: contentType,
        maxBytes: ImageUploadLimits.eventIconMaxBytes,
        maxSide: ImageUploadLimits.eventIconMaxSide,
      );
      if (!mounted) return;

      if (prepared.wasCompressed && prepared.originalBytes != null) {
        _showOptimizedSnackBar(
          prepared.originalBytes!,
          prepared.bytes.length,
        );
      }

      setState(() {
        _selectedIconBytes = prepared.bytes;
        _selectedIconName = file.name;
        _selectedIconExtension = prepared.extension;
        _selectedIconContentType = prepared.contentType;
        _customIconUrl = null;
        _shieldManualOverride = true;
        _shieldFromLibrary = false;
        _processingImagePick = false;
      });
    } on ImageTooLargeAfterCompressException {
      if (mounted) {
        setState(() {
          _error = 'El escudo es demasiado grande. Prueba con otra imagen.';
          _processingImagePick = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo procesar el escudo.';
          _processingImagePick = false;
        });
      }
    }
  }

  void _showOptimizedSnackBar(int originalBytes, int compressedBytes) {
    if (!mounted || compressedBytes >= originalBytes) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Imagen optimizada (${formatImageSize(originalBytes)} → '
          '${formatImageSize(compressedBytes)})',
        ),
      ),
    );
  }

  void _clearCustomIcon() {
    final key = normalizeOrganizerKey(_organizerController.text.trim());
    setState(() {
      _customIconUrl = null;
      _selectedIconBytes = null;
      _selectedIconName = null;
      _selectedIconExtension = null;
      _selectedIconContentType = null;
      _shieldManualOverride = false;
      _shieldFromLibrary = false;
      if (key.length >= 3) _shieldSkipAutoLoadKey = key;
    });
  }

  String? _contentTypeForExtension(String extension) {
    return switch (extension) {
      'svg' => 'image/svg+xml',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => null,
    };
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final subtitle = _subtitleController.text.trim();
    final location = _locationController.text.trim();
    final organizer = _organizerController.text.trim();

    if (title.length < 3) {
      setState(() => _error = 'El título debe tener al menos 3 caracteres.');
      return;
    }

    if (_startsAt.isBefore(DateTime.now())) {
      setState(
        () => _error = 'La fecha y hora del evento deben ser futuras.',
      );
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final repo = ref.read(calendarRepositoryProvider);
      final profile = ref.read(currentUserProfileProvider).asData?.value;
      final handle = profile?.handle;
      var customIconUrl = _customIconUrl;
      var coverImageUrl = _coverImageUrl;

      if (_selectedIconBytes != null &&
          _selectedIconExtension != null &&
          _selectedIconContentType != null) {
        customIconUrl = await repo.uploadEventIcon(
          userId: user.id,
          bytes: _selectedIconBytes!,
          extension: _selectedIconExtension!,
          contentType: _selectedIconContentType!,
        );
      }

      if (_selectedCoverBytes != null &&
          _selectedCoverExtension != null &&
          _selectedCoverContentType != null) {
        coverImageUrl = await repo.uploadEventCover(
          userId: user.id,
          bytes: _selectedCoverBytes!,
          extension: _selectedCoverExtension!,
          contentType: _selectedCoverContentType!,
        );
      }

      if (organizer.length >= 3 && customIconUrl?.trim().isNotEmpty == true) {
        await repo.saveOrganizerLogo(
          userId: user.id,
          organizerLabel: organizer,
          logoUrl: customIconUrl!.trim(),
        );
      }

      if (_isEditing) {
        await repo.updateEvent(
          eventId: widget.existing!.id!,
          title: title,
          subtitle: subtitle,
          type: _type,
          startsAt: _startsAt,
          dayLabel: _type.cellLabel,
          location: location,
          organizerLabel: organizer,
          customIconUrl: customIconUrl,
          coverImageUrl: coverImageUrl,
        );
      } else {
        await repo.createEvent(
          userId: user.id,
          title: title,
          subtitle: subtitle,
          type: _type,
          startsAt: _startsAt,
          dayLabel: _type.cellLabel,
          location: location,
          organizerLabel: organizer,
          publisherHandle: handle,
          customIconUrl: customIconUrl,
          coverImageUrl: coverImageUrl,
        );
      }

      invalidateCalendarMonth(ref, _date);
      if (mounted) {
        Navigator.pop(context);
        final isAdmin = ref.read(isAdminProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Evento actualizado'
                  : isAdmin
                      ? 'Evento publicado en el calendario'
                      : 'Evento enviado a la Junta para aprobación',
            ),
          ),
        );
      }
    } on CalendarRemoteUnavailableException {
      setState(() => _error = 'Supabase no disponible.');
    } on CalendarIconTooLargeException {
      setState(() => _error = 'El escudo no puede superar 1 MB.');
    } on CalendarCoverTooLargeException {
      setState(() => _error = 'La portada no puede superar 3 MB.');
    } on ImageTooLargeAfterCompressException {
      setState(() => _error = 'La imagen es demasiado grande. Prueba con otra.');
    } on PostgrestException catch (e) {
      setState(() => _error = calendarSaveErrorMessage(e));
    } catch (_) {
      setState(() => _error = 'No se pudo guardar el evento. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('d MMMM yyyy', 'es').format(_date);
    final timeLabel = _time.format(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, cofradeoSheetBottomPadding(context)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isEditing ? 'Editar evento' : 'Nuevo evento',
                    style: AppTypography.displaySmall(),
                  ),
                ),
                IconButton(
                  onPressed: _submitting ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.burgundy),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<EventType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: EventType.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onChanged: _submitting ? null : (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _organizerController,
              decoration: InputDecoration(
                labelText: 'Hermandad / organizador',
                hintText: 'Hermandad de la Macarena',
                suffixIcon: IconButton(
                  onPressed: _submitting ? null : _openOrganizerLibrary,
                  tooltip: 'Biblioteca de escudos',
                  icon: const Icon(Icons.account_balance_outlined),
                  color: AppColors.burgundy,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _submitting ? null : _openOrganizerLibrary,
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Elegir de la biblioteca'),
              ),
            ),
            const SizedBox(height: 12),
            _IconPickerSection(
              type: _type,
              customIconUrl: _customIconUrl,
              pickedIconBytes: _selectedIconBytes,
              selectedIconName: _selectedIconName,
              loading: _loadingOrganizerShield,
              processing: _processingImagePick,
              fromLibrary: _shieldFromLibrary,
              onPickIcon: _submitting || _processingImagePick ? null : _pickIcon,
              onClearIcon: _submitting ? null : _clearCustomIcon,
            ),
            const SizedBox(height: 12),
            _CoverPickerSection(
              coverImageUrl: _coverImageUrl,
              pickedCoverBytes: _selectedCoverBytes,
              selectedCoverName: _selectedCoverName,
              processing: _processingImagePick,
              onPickCover: _submitting || _processingImagePick ? null : _pickCover,
              onClearCover: _submitting ? null : _clearCover,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Título',
                hintText: 'Salida de procesión',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subtitleController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                hintText: 'Detalle del acto cofrade…',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Lugar',
                hintText: 'Parroquia, calle, templo…',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _submitting ? null : _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(dateLabel, overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _submitting ? null : _pickTime,
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(timeLabel),
                ),
              ],
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
                  : Text(_isEditing ? 'Guardar cambios' : 'Publicar evento'),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconPickerSection extends StatelessWidget {
  const _IconPickerSection({
    required this.type,
    required this.customIconUrl,
    required this.pickedIconBytes,
    required this.selectedIconName,
    required this.fromLibrary,
    required this.loading,
    required this.processing,
    required this.onPickIcon,
    required this.onClearIcon,
  });

  final EventType type;
  final String? customIconUrl;
  final Uint8List? pickedIconBytes;
  final String? selectedIconName;
  final bool fromLibrary;
  final bool loading;
  final bool processing;
  final VoidCallback? onPickIcon;
  final VoidCallback? onClearIcon;

  @override
  Widget build(BuildContext context) {
    final hasCustomIcon =
        customIconUrl?.trim().isNotEmpty == true || selectedIconName != null;

    final subtitle = processing
        ? 'Optimizando imagen…'
        : loading
        ? 'Buscando escudo guardado…'
        : selectedIconName ??
            (fromLibrary
                ? 'Escudo guardado de esta hermandad'
                : customIconUrl?.trim().isNotEmpty == true
                ? 'Escudo del evento'
                : 'Opcional: se reutiliza al publicar de nuevo');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          if (pickedIconBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(27),
              child: Image.memory(
                pickedIconBytes!,
                width: 54,
                height: 54,
                fit: BoxFit.cover,
              ),
            )
          else
            EventTypeIcon(type: type, size: 54, customIconUrl: customIconUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Escudo del organizador',
                  style: AppTypography.titleLarge().copyWith(fontSize: 15),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: AppTypography.labelSmall(
                    color: fromLibrary ? AppColors.burgundy : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(onPressed: onPickIcon, child: const Text('Subir')),
              if (hasCustomIcon)
                TextButton(onPressed: onClearIcon, child: const Text('Quitar')),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoverPickerSection extends StatelessWidget {
  const _CoverPickerSection({
    required this.coverImageUrl,
    required this.pickedCoverBytes,
    required this.selectedCoverName,
    required this.processing,
    required this.onPickCover,
    required this.onClearCover,
  });

  final String? coverImageUrl;
  final Uint8List? pickedCoverBytes;
  final String? selectedCoverName;
  final bool processing;
  final VoidCallback? onPickCover;
  final VoidCallback? onClearCover;

  @override
  Widget build(BuildContext context) {
    final hasCover =
        coverImageUrl?.trim().isNotEmpty == true || selectedCoverName != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 72,
              height: 52,
              child: pickedCoverBytes != null
                  ? Image.memory(
                      pickedCoverBytes!,
                      fit: BoxFit.cover,
                      width: 72,
                      height: 52,
                    )
                  : coverImageUrl?.trim().isNotEmpty == true
                  ? CofradeoNetworkImage(
                      url: coverImageUrl!,
                      fit: BoxFit.cover,
                      width: 72,
                      height: 52,
                      cacheSize: 72,
                      errorWidget: _placeholder(),
                    )
                  : _placeholder(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Portada del evento',
                  style: AppTypography.titleLarge().copyWith(fontSize: 15),
                ),
                const SizedBox(height: 3),
                Text(
                  processing
                      ? 'Optimizando imagen…'
                      : selectedCoverName ??
                          (hasCover
                              ? 'Portada actual'
                              : 'Opcional: foto para carrusel y listado'),
                  style: AppTypography.labelSmall(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(onPressed: onPickCover, child: const Text('Subir')),
              if (hasCover)
                TextButton(onPressed: onClearCover, child: const Text('Quitar')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.burgundyDark,
      child: const Icon(Icons.image_outlined, color: AppColors.goldPale),
    );
  }
}
