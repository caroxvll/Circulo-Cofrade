import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_upload_compress.dart';
import '../../../core/utils/pick_gallery_image.dart';
import '../../../core/widgets/cofradeo_bottom_nav.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../../../core/widgets/event_type_icon.dart';
import '../../../shared/models/calendar_event.dart';
import '../../auth/auth_provider.dart';
import '../../auth/email_verification_gate.dart';
import '../../permissions/permissions_provider.dart';
import '../../profile/profile_provider.dart';
import '../../forums/hermandad_season_acts_provider.dart';
import '../../forums/utils/hermandad_season_profile.dart';
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
            'Solo moderadores, o cuentas con acceso al calendario, pueden proponer eventos.',
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
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.74,
      minChildSize: 0.42,
      maxChildSize: 0.88,
      builder: (context, scrollController) => _EventComposeSheet(
        initialDate: initialDate,
        existing: existing,
        scrollController: scrollController,
      ),
    ),
  );
}

class _EventComposeSheet extends ConsumerStatefulWidget {
  const _EventComposeSheet({
    this.initialDate,
    this.existing,
    required this.scrollController,
  });

  final DateTime? initialDate;
  final CalendarEvent? existing;
  final ScrollController scrollController;

  @override
  ConsumerState<_EventComposeSheet> createState() => _EventComposeSheetState();
}

class _EventComposeSheetState extends ConsumerState<_EventComposeSheet> {
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _locationController = TextEditingController();
  final _admissionController = TextEditingController();
  final _organizerController = TextEditingController();

  late DateTime _date;
  late TimeOfDay _time;
  late EventType _type;
  bool _submitting = false;
  String? _error;
  String? _customIconUrl;
  String? _coverImageUrl;
  String? _hermandadTopicId;
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
  TimeOfDay? _firstEnd;
  final List<({TimeOfDay start, TimeOfDay? end})> _extraSlots = [];
  SeasonPaso _paso = SeasonPaso.ambos;
  var _ensayoN = 1;
  var _withRetranqueo = false;

  bool get _showSeasonPaso =>
      _type == EventType.iguala || _type == EventType.ensayo;
  bool get _showEnsayoN => _type == EventType.ensayo;
  bool get _showRetranqueo => _type == EventType.muda;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;

    if (existing != null) {
      _titleController.text = existing.title;
      _subtitleController.text = existing.subtitle;
      _locationController.text = existing.location ?? '';
      _admissionController.text = existing.admissionLabel ?? '';
      _organizerController.text = existing.organizerLabel ?? '';
      _date = existing.date;
      _type = existing.type;
      _customIconUrl = existing.customIconUrl;
      _coverImageUrl = existing.coverImageUrl;
      _hermandadTopicId = existing.hermandadTopicId;
      if (_hermandadTopicId != null) {
        _linkedOrganizerKey =
            normalizeOrganizerKey(existing.organizerLabel ?? '');
      }
      final parts = existing.time?.split(':');
      _time = parts != null && parts.length >= 2
          ? TimeOfDay(
              hour: int.tryParse(parts[0]) ?? 12,
              minute: int.tryParse(parts[1]) ?? 0,
            )
          : const TimeOfDay(hour: 12, minute: 0);
      _paso = existing.paso;
      _ensayoN = existing.seasonNumber ?? 1;
      _withRetranqueo = existing.withRetranqueo;
      if (existing.slots.isNotEmpty) {
        final first = existing.slots.first;
        _time = _timeFromClock(first.start) ?? _time;
        _firstEnd = _timeFromClock(first.end);
        for (final slot in existing.slots.skip(1)) {
          final start = _timeFromClock(slot.start);
          if (start == null) continue;
          _extraSlots.add((start: start, end: _timeFromClock(slot.end)));
        }
      }
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

  String? _linkedOrganizerKey;

  var _linkingOrganizer = false;

  void _onOrganizerChanged() {
    if (_linkingOrganizer) {
      _scheduleOrganizerShieldLookup();
      return;
    }
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

    final skipIcon = _isEditing &&
        widget.existing?.customIconUrl?.trim().isNotEmpty == true &&
        key == _initialOrganizerKey;

    setState(() => _loadingOrganizerShield = true);

    try {
      final repo = ref.read(calendarRepositoryProvider);
      String? logoUrl;
      if (!skipIcon) {
        logoUrl = await repo.fetchOrganizerLogo(organizer);
        logoUrl ??= await repo.fetchHermandadIconByOrganizerLabel(organizer);
      }
      if (!mounted) return;

      var topicId = _hermandadTopicId;
      var linkedKey = _linkedOrganizerKey;
      final alreadyLinked = topicId != null && topicId.trim().isNotEmpty;
      if (!alreadyLinked) {
        final resolved = await repo.findHermandadForOrganizer(organizer);
        final resolvedId = resolved?.hermandadTopicId?.trim();
        if (resolvedId != null && resolvedId.isNotEmpty) {
          topicId = resolvedId;
        }
      }
      linkedKey = key;
      if (_shieldManualOverride || _selectedIconBytes != null) {
        if (mounted) {
          setState(() {
            _loadingOrganizerShield = false;
            _hermandadTopicId = topicId;
            _linkedOrganizerKey = linkedKey;
          });
        }
        return;
      }

      setState(() {
        if (!skipIcon && logoUrl != null && logoUrl.isNotEmpty) {
          _customIconUrl = logoUrl;
          _shieldFromLibrary = true;
          _selectedIconName = null;
          _selectedIconBytes = null;
          _selectedIconExtension = null;
          _selectedIconContentType = null;
        }
        _loadingOrganizerShield = false;
        _hermandadTopicId = topicId;
        _linkedOrganizerKey = linkedKey;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingOrganizerShield = false);
    }
  }

  Future<void> _openOrganizerLibrary() async {
    final picked = await OrganizerPickerSheet.show(context);
    if (picked == null || !mounted) return;

    var topicId = picked.hermandadTopicId?.trim();
    if (topicId == null || topicId.isEmpty) {
      topicId = await ref
          .read(calendarRepositoryProvider)
          .findHermandadTopicIdForOrganizer(picked.displayLabel);
    }
    if (!mounted) return;

    setState(() {
      _linkingOrganizer = true;
      _organizerController.text = picked.displayLabel;
      _hermandadTopicId = topicId;
      _linkedOrganizerKey = picked.organizerKey;
      _shieldSkipAutoLoadKey = null;
      _shieldManualOverride = false;
      _selectedIconName = null;
      _selectedIconBytes = null;
      _selectedIconExtension = null;
      _selectedIconContentType = null;
      _initialOrganizerKey = picked.organizerKey;
      _linkingOrganizer = false;

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

  HermandadSeasonProfile _seasonProfile() {
    final topicId = _hermandadTopicId?.trim();
    if (topicId == null || topicId.isEmpty) {
      return HermandadSeasonProfile.defaults;
    }
    return ref.watch(hermandadSeasonProfileProvider(topicId)).asData?.value ??
        HermandadSeasonProfile.defaults;
  }

  String _seasonAwareDayLabel() {
    final extra = seasonActDayLabel(
      typeDb: _type.dbValue,
      paso: _paso,
      seasonN: _type == EventType.ensayo ? _ensayoN : null,
      withRetranqueo: _type == EventType.muda && _withRetranqueo,
    );
    if (extra.isNotEmpty) return extra;
    return _type.cellLabel;
  }

  int? get _seasonNumber => _type == EventType.ensayo ? _ensayoN : null;
  bool get _seasonRetranqueo => _type == EventType.muda && _withRetranqueo;

  List<Widget> _seasonActFields() {
    final profile = _seasonProfile();
    final topicId = _hermandadTopicId?.trim();
    final linked = topicId != null && topicId.isNotEmpty;
    final ensayoMax = (linked ? profile.ensayoCount : 8).clamp(1, 8);
    final showRetr = _showRetranqueo &&
        (!linked || profile.mudaMode != MudaRetranqueoMode.mudaOnly);
    if (!_showSeasonPaso && !_showEnsayoN && !showRetr) {
      return const [];
    }

    return [
      const SizedBox(height: 12),
      if (_showSeasonPaso) ...[
        Text(
          'Paso',
          style: AppTypography.labelSmall(color: AppColors.goldDark)
              .copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final paso in SeasonPaso.values)
              ChoiceChip(
                label: Text(paso.shortLabel),
                selected: _paso == paso,
                onSelected: _submitting
                    ? null
                    : (_) => setState(() => _paso = paso),
                selectedColor: AppColors.goldPale,
              ),
          ],
        ),
      ],
      if (_showEnsayoN) ...[
        const SizedBox(height: 10),
        Text(
          'Qué ensayo es',
          style: AppTypography.labelSmall(color: AppColors.goldDark)
              .copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (var n = 1; n <= ensayoMax; n++)
              ChoiceChip(
                label: Text(ordinalEnsayo(n)),
                selected: _ensayoN == n,
                onSelected: _submitting
                    ? null
                    : (_) => setState(() => _ensayoN = n),
                selectedColor: AppColors.goldPale,
              ),
          ],
        ),
      ],
      if (showRetr)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: AppColors.burgundy,
          title: Text(
            'Incluye retranqueo',
            style: AppTypography.bodyMedium(color: AppColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          subtitle: Text(
            profile.mudaMode == MudaRetranqueoMode.withRetranqueo
                ? 'El mismo día. Cierra el check de muda y retranqueo.'
                : 'Márcalo si retranqueáis el mismo día.',
            style: AppTypography.bodyMedium(color: AppColors.textSecondary)
                .copyWith(fontSize: 12),
          ),
          value: _withRetranqueo,
          onChanged: _submitting
              ? null
              : (value) => setState(() => _withRetranqueo = value),
        ),
    ];
  }

  @override
  void dispose() {
    _organizerDebounce?.cancel();
    _organizerController.removeListener(_onOrganizerChanged);
    _titleController.dispose();
    _subtitleController.dispose();
    _locationController.dispose();
    _admissionController.dispose();
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

  TimeOfDay? _timeFromClock(String? raw) {
    final text = raw?.trim() ?? '';
    final parts = text.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _clockLabel(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String? _endAfter(TimeOfDay start, TimeOfDay? end) {
    if (end == null) return null;
    final startMin = start.hour * 60 + start.minute;
    final endMin = end.hour * 60 + end.minute;
    if (endMin <= startMin) return null;
    return _clockLabel(end);
  }

  List<EventTimeSlot> _collectSlots() {
    final slots = <EventTimeSlot>[
      EventTimeSlot(
        start: _clockLabel(_time),
        end: _endAfter(_time, _firstEnd),
      ),
      for (final extra in _extraSlots)
        EventTimeSlot(
          start: _clockLabel(extra.start),
          end: _endAfter(extra.start, extra.end),
        ),
    ];
    slots.sort((a, b) => a.start.compareTo(b.start));
    final hasRange = slots.any((slot) => (slot.end ?? '').isNotEmpty);
    if (slots.length < 2 && !hasRange) return const [];
    return slots;
  }

  Future<void> _pickFirstEnd() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _firstEnd ?? _time,
    );
    if (picked != null) setState(() => _firstEnd = picked);
  }

  Future<void> _pickExtraStart(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _extraSlots[index].start,
    );
    if (picked == null) return;
    setState(() {
      _extraSlots[index] = (start: picked, end: _extraSlots[index].end);
    });
  }

  Future<void> _pickExtraEnd(int index) async {
    final current = _extraSlots[index];
    final picked = await showTimePicker(
      context: context,
      initialTime: current.end ?? current.start,
    );
    if (picked == null) return;
    setState(() {
      _extraSlots[index] = (start: current.start, end: picked);
    });
  }

  Future<void> _pickCover() async {
    if (_processingImagePick) return;

    final file = await pickGalleryImage();
    if (file == null || !mounted) return;

    final bytes = file.bytes;
    final extension = file.extension;
    final contentType = file.contentType;
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

    final file = await pickGalleryImage(maxWidth: 1200);
    if (file == null || !mounted) return;

    final bytes = file.bytes;
    final extension = file.extension;
    final contentType = file.contentType;
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

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final subtitle = _subtitleController.text.trim();
    final location = _locationController.text.trim();
    final admission = _admissionController.text.trim();
    final slots = _collectSlots();
    final organizer = _organizerController.text.trim();

    if (title.length < 3) {
      setState(() => _error = 'El título debe tener al menos 3 caracteres.');
      return;
    }
    if (title.length > 120) {
      setState(() => _error = 'El título no puede superar 120 caracteres.');
      return;
    }
    if (subtitle.length > 1000) {
      setState(
        () => _error =
            'La descripción no puede superar 1000 caracteres (${subtitle.length}/1000).',
      );
      return;
    }
    if (location.length > 160) {
      setState(() => _error = 'El lugar no puede superar 160 caracteres.');
      return;
    }

    if (!_isEditing && _startsAt.isBefore(DateTime.now())) {
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

      String? hermandadId = _hermandadTopicId?.trim();
      String? hermandadName = organizer;
      if (organizer.length >= 3 &&
          (hermandadId == null || hermandadId.isEmpty)) {
        final resolved = await repo.findHermandadForOrganizer(organizer);
        final resolvedId = resolved?.hermandadTopicId?.trim();
        if (resolvedId != null && resolvedId.isNotEmpty) {
          hermandadId = resolvedId;
          hermandadName = resolved?.displayLabel ?? organizer;
        }
      }
      if ((hermandadId == null || hermandadId.isEmpty) &&
          organizer.isNotEmpty) {
        hermandadId = widget.existing?.hermandadTopicId?.trim();
      }
      if (hermandadId != null && hermandadId.isNotEmpty) {
        _hermandadTopicId = hermandadId;
      }
      final unlinkHermandad = organizer.isEmpty;
      if (_isEditing) {
        await repo.updateEvent(
          eventId: widget.existing!.id!,
          title: title,
          subtitle: subtitle,
          type: _type,
          startsAt: _startsAt,
          dayLabel: _seasonAwareDayLabel(),
          location: location,
          organizerLabel: organizer,
          hermandadTopicId: unlinkHermandad ? null : hermandadId,
          clearHermandadTopicId: unlinkHermandad,
          customIconUrl: customIconUrl,
          coverImageUrl: coverImageUrl,
          admissionLabel: admission,
          timeSlots: slots,
          paso: _paso,
          seasonNumber: _seasonNumber,
          withRetranqueo: _seasonRetranqueo,
        );
      } else {
        await repo.createEvent(
          userId: user.id,
          title: title,
          subtitle: subtitle,
          type: _type,
          startsAt: _startsAt,
          dayLabel: _seasonAwareDayLabel(),
          location: location,
          organizerLabel: organizer,
          hermandadTopicId: hermandadId,
          publisherHandle: handle,
          customIconUrl: customIconUrl,
          coverImageUrl: coverImageUrl,
          admissionLabel: admission,
          timeSlots: slots,
          paso: _paso,
          seasonNumber: _seasonNumber,
          withRetranqueo: _seasonRetranqueo,
        );
      }

      invalidateCalendarMonth(ref, _date);
      ref.read(calendarEventsEpochProvider.notifier).bump();
      ref.invalidate(hermandadSeasonActsCoverageProvider);
      ref.invalidate(seasonActsEventsProvider);
      ref.invalidate(hermandadSeasonActsProvider);
      if (mounted) {
        Navigator.pop(context);
        final isAdmin = ref.read(isAdminProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hermandadId != null && hermandadId.isNotEmpty
                  ? _isEditing
                      ? 'Actualizado en ${hermandadName ?? organizer}'
                      : isAdmin
                          ? 'Publicado en ${hermandadName ?? organizer}'
                          : 'Enviado a la Junta · ${hermandadName ?? organizer}'
                  : _isEditing
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

    return Material(
      color: AppColors.background,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
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
            Expanded(
              child: SingleChildScrollView(
                controller: widget.scrollController,
                padding: EdgeInsets.only(
                  right: 8,
                  bottom: cofradeoSheetBottomPadding(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
            DropdownButtonFormField<EventType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: EventType.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onChanged: _submitting
                  ? null
                  : (v) => setState(() {
                        _type = v!;
                        if (_type != EventType.muda) {
                          _withRetranqueo = false;
                        }
                      }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _organizerController,
              decoration: InputDecoration(
                labelText: 'Hermandad / organizador',
                hintText: 'Elige el tablón oficial o escribe un nombre',
                helperText: _hermandadTopicId != null
                    ? 'Mismo tablón: si cambias el nombre, sigue siendo esta hermandad'
                    : 'Usa «Elegir hermandad» para guardarlo en su tablón',
                suffixIcon: IconButton(
                  onPressed: _submitting ? null : _openOrganizerLibrary,
                  tooltip: 'Elegir hermandad o escudo',
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
                label: const Text('Elegir hermandad'),
              ),
            ),
            ..._seasonActFields(),
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
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _subtitleController,
              builder: (context, value, _) {
                final len = value.text.trim().length;
                final over = len > 1000;
                return TextField(
                  controller: _subtitleController,
                  maxLines: 4,
                  maxLength: 1000,
                  buildCounter: (
                    context, {
                    required currentLength,
                    required isFocused,
                    required maxLength,
                  }) {
                    final n = _subtitleController.text.trim().length;
                    return Text(
                      '$n/1000',
                      style: TextStyle(
                        fontSize: 12,
                        color: n > 1000
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                    );
                  },
                  decoration: InputDecoration(
                    labelText: 'Descripción',
                    hintText: 'Detalle del acto cofrade…',
                    errorText: over
                        ? 'Máximo 1000 caracteres ($len/1000).'
                        : null,
                  ),
                );
              },
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
            TextField(
              controller: _admissionController,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: 'Entrada',
                hintText: '12 €, desde 8 €, donativo',
                helperText: 'Opcional. Si lo dejas vacío, no se muestra.',
                counterText: '',
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
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _submitting ? null : _pickFirstEnd,
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: Text(
                  _firstEnd == null
                      ? 'Fin del tramo (opcional)'
                      : 'Hasta ${_clockLabel(_firstEnd!)}',
                ),
              ),
            ),
            if (_firstEnd != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _submitting
                      ? null
                      : () => setState(() => _firstEnd = null),
                  child: const Text('Quitar el fin'),
                ),
              ),
            for (var i = 0; i < _extraSlots.length; i++) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting ? null : () => _pickExtraStart(i),
                      child: Text(_clockLabel(_extraSlots[i].start)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting ? null : () => _pickExtraEnd(i),
                      child: Text(
                        _extraSlots[i].end == null
                            ? 'Fin'
                            : 'Hasta ${_clockLabel(_extraSlots[i].end!)}',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _submitting
                        ? null
                        : () => setState(() => _extraSlots.removeAt(i)),
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Quitar tramo',
                  ),
                ],
              ),
            ],
            if (_extraSlots.length < 5)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _submitting
                      ? null
                      : () => setState(() {
                            _extraSlots.add((
                              start: const TimeOfDay(hour: 19, minute: 0),
                              end: null,
                            ));
                          }),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Añadir otro tramo'),
                ),
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
