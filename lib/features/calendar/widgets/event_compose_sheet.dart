import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/calendar_event.dart';
import '../../auth/auth_provider.dart';
import '../../auth/email_verification_gate.dart';
import '../../profile/profile_provider.dart';
import '../calendar_provider.dart';
import '../data/calendar_repository.dart';

Future<void> showEventComposeSheet(
  BuildContext context,
  WidgetRef ref, {
  DateTime? initialDate,
  CalendarEvent? existing,
}) async {
  final isAuth = ref.read(isAuthenticatedProvider);
  if (!isAuth) {
    if (context.mounted) {
      await context.push('/login?redirect=${Uri.encodeComponent('/calendario')}');
    }
    return;
  }

  if (!await ensureEmailVerifiedForEngage(context, ref)) return;

  if (!ref.read(isCalendarEditorProvider)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo editores del calendario pueden publicar eventos.'),
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
          content: Text('Conecta Supabase (env.json) para publicar eventos reales.'),
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
    builder: (_) => _EventComposeSheet(
      initialDate: initialDate,
      existing: existing,
    ),
  );
}

class _EventComposeSheet extends ConsumerStatefulWidget {
  const _EventComposeSheet({
    this.initialDate,
    this.existing,
  });

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

  bool get _isEditing => widget.existing?.id != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final profile = ref.read(currentUserProfileProvider).asData?.value;

    if (existing != null) {
      _titleController.text = existing.title;
      _subtitleController.text = existing.subtitle;
      _locationController.text = existing.location ?? '';
      _organizerController.text = existing.organizerLabel ?? '';
      _date = existing.date;
      _type = existing.type;
      final parts = existing.time?.split(':');
      _time = parts != null && parts.length >= 2
          ? TimeOfDay(
              hour: int.tryParse(parts[0]) ?? 12,
              minute: int.tryParse(parts[1]) ?? 0,
            )
          : const TimeOfDay(hour: 12, minute: 0);
    } else {
      _date = widget.initialDate ?? DateTime.now();
      _time = const TimeOfDay(hour: 20, minute: 0);
      _type = EventType.procesion;
      _organizerController.text = profile?.displayName ?? '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _locationController.dispose();
    _organizerController.dispose();
    super.dispose();
  }

  DateTime get _startsAt => DateTime(
        _date.year,
        _date.month,
        _date.day,
        _time.hour,
        _time.minute,
      );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035, 12, 31),
      locale: const Locale('es'),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) setState(() => _time = picked);
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
        );
      }

      invalidateCalendarMonth(ref, _date);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Evento actualizado' : 'Evento publicado'),
          ),
        );
      }
    } on CalendarRemoteUnavailableException {
      setState(() => _error = 'Supabase no disponible.');
    } catch (_) {
      setState(
        () => _error = 'No se pudo guardar. ¿Ejecutaste calendar_events.sql?',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final dateLabel = DateFormat('d MMMM yyyy', 'es').format(_date);
    final timeLabel = _time.format(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? 'Editar evento' : 'Nuevo evento',
              style: AppTypography.displaySmall(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<EventType>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: EventType.values
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.label),
                    ),
                  )
                  .toList(),
              onChanged: _submitting ? null : (v) => setState(() => _type = v!),
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
              controller: _organizerController,
              decoration: const InputDecoration(
                labelText: 'Hermandad / organizador',
                hintText: 'Hermandad de la Macarena',
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
