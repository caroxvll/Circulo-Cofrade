import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/event_type_icon.dart';
import '../../../shared/models/calendar_event.dart';
import '../../auth/auth_provider.dart';
import '../../forums/viewer_id_provider.dart';
import '../calendar_provider.dart';
import '../utils/calendar_event_utils.dart';
import 'calendar_event_image.dart';
import 'event_compose_sheet.dart';

Future<void> showEventDetailSheet(
  BuildContext context,
  WidgetRef ref, {
  required CalendarEvent event,
  required DateTime focusedMonth,
}) async {
  var display = event;
  final eventId = event.id;
  if (eventId != null && eventId.isNotEmpty) {
    try {
      final viewerId = ref.read(viewerIdProvider);
      final count = await ref
          .read(calendarRepositoryProvider)
          .incrementEventView(eventId, viewerId: viewerId);
      if (count != null && count >= 0) {
        display = event.copyWith(viewCount: count);
      }
    } catch (_) {}
  }

  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) =>
        _EventDetailSheet(event: display, focusedMonth: focusedMonth),
  );
}

class _EventDetailSheet extends ConsumerWidget {
  const _EventDetailSheet({required this.event, required this.focusedMonth});

  final CalendarEvent event;
  final DateTime focusedMonth;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar evento?'),
        content: Text('Se borrará «${event.title}» del calendario.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(calendarRepositoryProvider).deleteEvent(event.id!);
      invalidateCalendarMonth(ref, focusedMonth);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Evento eliminado')));
      }
    } on CalendarEventDeleteFailedException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(calendarDeleteErrorMessage(e))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(calendarDeleteErrorMessage(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserProvider)?.id;
    final isAdmin = ref.watch(isCalendarAdminProvider);
    final canManage = canManageCalendarEvent(
      event: event,
      currentUserId: userId,
      isAdmin: isAdmin,
    );
    final logos = ref.watch(organizerLogosMapProvider).asData?.value;
    final shieldUrl = resolvedOrganizerShieldUrl(logos, event);
    final organizer = resolvedOrganizerLabel(logos, event);
    final dateLabel = DateFormat("EEEE d 'de' MMMM", 'es').format(event.date);
    final formattedDate = dateLabel[0].toUpperCase() + dateLabel.substring(1);
    final hasCover = CalendarEventImage.hasDisplayableCover(event);
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * (hasCover ? 0.88 : 0.72);
    final bottomPad = media.padding.bottom + 16;
    final location = event.location?.trim().isNotEmpty == true
        ? event.location!.trim()
        : null;
    final description = _eventDescription(
      event: event,
      organizer: organizer,
      location: location,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Material(
          color: AppColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    _MediaHeader(
                      event: event,
                      hasCover: hasCover,
                      onClose: () => Navigator.pop(context),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPad),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _AuthorRow(
                            event: event,
                            organizer: organizer,
                            shieldUrl: shieldUrl,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            event.title,
                            style: AppTypography.displaySmall().copyWith(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _MetaBlock(
                            dateLabel: formattedDate,
                            time: event.time,
                            location: location,
                          ),
                          if (event.viewCount > 0) ...[
                            const SizedBox(height: 10),
                            Text(
                              event.viewCount == 1
                                  ? '1 visita'
                                  : '${event.viewCount} visitas',
                              style: AppTypography.labelSmall(
                                color: AppColors.textMuted,
                              ).copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                          if (description != null) ...[
                            const SizedBox(height: 18),
                            Text(
                              description,
                              style: AppTypography.bodyMedium().copyWith(
                                fontSize: 15.5,
                                height: 1.45,
                                color: AppColors.textPrimary.withValues(
                                  alpha: 0.92,
                                ),
                              ),
                            ),
                          ],
                          if (canManage) ...[
                            const SizedBox(height: 22),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      await showEventComposeSheet(
                                        context,
                                        ref,
                                        existing: event,
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('Editar'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _delete(context, ref),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                    ),
                                    label: const Text('Eliminar'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.accentRed,
                                      side: const BorderSide(
                                        color: AppColors.accentRed,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Evita repetir hermandad/ubicación cuando el subtitle es solo un fallback.
String? _eventDescription({
  required CalendarEvent event,
  required String? organizer,
  required String? location,
}) {
  final raw = event.subtitle.trim();
  if (raw.isEmpty) return null;

  final org = organizer?.trim() ?? '';
  final loc = location?.trim() ?? '';
  final fallbacks = <String>{
    if (org.isNotEmpty) org,
    if (loc.isNotEmpty) loc,
    if (org.isNotEmpty && loc.isNotEmpty) '$org · $loc',
    if (org.isNotEmpty && loc.isNotEmpty) '$org ·$loc',
  };
  if (fallbacks.contains(raw)) return null;
  return raw;
}

/// Cabecera visual: imagen a sangre + pill de tipo + cerrar.
class _MediaHeader extends StatelessWidget {
  const _MediaHeader({
    required this.event,
    required this.hasCover,
    required this.onClose,
  });

  final CalendarEvent event;
  final bool hasCover;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final height = hasCover ? 240.0 : 132.0;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasCover)
            CalendarEventImage(
              event: event,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              showTypeFallback: false,
            )
          else
            _FallbackHeader(event: event),
          if (hasCover)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x66000000),
                    Color(0x00000000),
                    Color(0x00000000),
                    Color(0x73000000),
                  ],
                  stops: [0.0, 0.28, 0.55, 1.0],
                ),
              ),
            ),
          // Asa del sheet
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: hasCover
                      ? Colors.white.withValues(alpha: 0.55)
                      : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Positioned(
            top: 14,
            right: 12,
            child: _CircleIconButton(
              icon: Icons.close_rounded,
              onTap: onClose,
              light: hasCover,
            ),
          ),
          Positioned(
            left: 16,
            bottom: 14,
            child: _TypePill(
              label: event.type.cellLabel.toUpperCase(),
              onDark: hasCover,
            ),
          ),
        ],
      ),
    );
  }
}

class _FallbackHeader extends StatelessWidget {
  const _FallbackHeader({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3D0008),
            Color(0xFF5A0610),
            Color(0xFF7A0814),
          ],
        ),
      ),
      child: Center(
        child: Opacity(
          opacity: 0.45,
          child: EventTypeIcon(
            type: event.type,
            size: 64,
            customIconUrl: event.customIconUrl,
          ),
        ),
      ),
    );
  }
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({
    required this.event,
    required this.organizer,
    required this.shieldUrl,
  });

  final CalendarEvent event;
  final String? organizer;
  final String? shieldUrl;

  @override
  Widget build(BuildContext context) {
    final name = (organizer?.trim().isNotEmpty == true)
        ? organizer!.trim()
        : (event.organizerLabel?.trim().isNotEmpty == true
              ? event.organizerLabel!.trim()
              : event.type.label);
    final handle = event.publisherHandle?.trim();

    return Row(
      children: [
        EventTypeIcon(
          type: event.type,
          size: 42,
          customIconUrl: shieldUrl ?? event.customIconUrl,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: AppTypography.bodyMedium().copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (handle != null && handle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  handle.startsWith('@') ? handle : '@$handle',
                  style: AppTypography.labelSmall(
                    color: AppColors.textMuted,
                  ).copyWith(fontSize: 12.5, height: 1.1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MetaBlock extends StatelessWidget {
  const _MetaBlock({
    required this.dateLabel,
    this.time,
    this.location,
  });

  final String dateLabel;
  final String? time;
  final String? location;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MetaRow(icon: Icons.calendar_today_outlined, text: dateLabel),
        if (time != null && time!.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          _MetaRow(icon: Icons.schedule_outlined, text: time!.trim()),
        ],
        if (location != null) ...[
          const SizedBox(height: 10),
          _MetaRow(icon: Icons.location_on_outlined, text: location!),
        ],
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.burgundy),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyMedium().copyWith(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              height: 1.25,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.label, required this.onDark});

  final String label;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: onDark
            ? Colors.black.withValues(alpha: 0.38)
            : AppColors.burgundy.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: onDark
              ? Colors.white.withValues(alpha: 0.28)
              : AppColors.gold.withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall(
          color: onDark ? Colors.white : AppColors.burgundy,
        ).copyWith(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    required this.light,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: light
          ? Colors.black.withValues(alpha: 0.35)
          : AppColors.surface.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 20,
            color: light ? Colors.white : AppColors.burgundy,
          ),
        ),
      ),
    );
  }
}
