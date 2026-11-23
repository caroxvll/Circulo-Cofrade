import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/app_network_status_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/forum_text_format.dart';
import '../../../core/utils/minute_clock.dart';
import '../../../core/utils/street_from_coordinates.dart';
import '../../../core/utils/time_ago.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../../../core/widgets/cofradeo_skeleton.dart';
import '../../../shared/models/calendar_event.dart';
import '../../../shared/models/forum.dart';
import '../../calendar/calendar_provider.dart'
    show calendarEventByIdProvider, calendarRepositoryProvider;
import '../../admin/widgets/junta_editorial_tab.dart';
import '../../forums/para_ti_pulse_provider.dart';
import '../../forums/topic_detail_typography.dart';
import '../../forums/utils/editorial_post.dart';
import '../../permissions/permissions_provider.dart';
import '../../profile/profile_provider.dart';
import '../../profile/widgets/suspended_account_banner.dart';
import '../cuaresma_ensayos_provider.dart';
import '../models/event_live_update.dart';
import '../widgets/ensayo_live_design.dart';

class EnsayoLiveScreen extends ConsumerStatefulWidget {
  const EnsayoLiveScreen({
    super.key,
    required this.forumId,
    required this.topicId,
    required this.eventId,
  });

  final String forumId;
  final String topicId;
  final String eventId;

  @override
  ConsumerState<EnsayoLiveScreen> createState() => _EnsayoLiveScreenState();
}

class _EnsayoLiveScreenState extends ConsumerState<EnsayoLiveScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _refreshTimer;
  bool _isPosting = false;
  bool _isLocating = false;
  bool _isClosingLive = false;
  double? _latitude;
  double? _longitude;
  String? _placeLabel;

  @override
  void initState() {
    super.initState();
    // Respaldo suave si Realtime falla; el feed vive por websocket.
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!mounted) return;
      unawaited(
        ref
            .read(eventLiveUpdatesProvider(widget.eventId).notifier)
            .reload(quiet: true),
      );
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(calendarEventByIdProvider(widget.eventId));
    ref.invalidate(eventEditorialPostsProvider(widget.eventId));
    await ref
        .read(eventLiveUpdatesProvider(widget.eventId).notifier)
        .reload(quiet: true);
  }

  Future<void> _publishNews(CalendarEvent event) async {
    final created = await showEditorialComposeSheet(
      context,
      calendarEventId: event.id,
      initialTitle: event.title,
    );
    if (!created || !mounted) return;
    ref.invalidate(eventEditorialPostsProvider(widget.eventId));
    ref.invalidate(publishedEditorialPostsProvider);
    ref.invalidate(paraTiRiverProvider);
  }

  Future<void> _toggleLiveForce(
    CalendarEvent event, {
    required bool close,
  }) async {
    final id = event.id;
    if (id == null || id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(close ? '¿Cerrar el live?' : '¿Reabrir el live?'),
        content: Text(
          close
              ? 'Nadie podrá publicar más avisos. Úsalo si el ensayo termina '
                  'antes (lluvia, cancelación, etc.).'
              : 'Se volverá a permitir publicar avisos según la ventana horaria '
                  '(o forzado abierto).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(close ? 'Cerrar live' : 'Reabrir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isClosingLive = true);
    try {
      await ref.read(calendarRepositoryProvider).setEventLiveForceState(
            eventId: id,
            state: close
                ? EventLiveForceState.closed
                : EventLiveForceState.auto,
          );
      ref.invalidate(calendarEventByIdProvider(widget.eventId));
      ref.invalidate(todayEnsayosProvider);
      ref.invalidate(todayCuaresmaAgendaProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            close ? 'Live cerrado por la Junta' : 'Live reabierto',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar el live')),
      );
    } finally {
      if (mounted) setState(() => _isClosingLive = false);
    }
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
            content: Text(
              'Activa la ubicación para compartir dónde está el ensayo',
            ),
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
      final street = await streetNameForCoordinates(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _placeLabel = street ?? 'Mi ubicación';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              street == null
                  ? 'Ubicación añadida. Se enviará con tu aviso.'
                  : 'Ubicación añadida: $street',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo obtener la ubicación')),
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _clearLocation() {
    setState(() {
      _latitude = null;
      _longitude = null;
      _placeLabel = null;
    });
  }

  Future<void> _submit() async {
    final profile = ref.read(currentUserProfileProvider).asData?.value;
    if (profile == null || profile.isSuspended) return;

    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe dónde va el ensayo')),
      );
      return;
    }

    final net = ref.read(appNetworkStatusProvider);
    if (net.isOffline) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(net.liveSendBlockedMessage)),
      );
      return;
    }

    final event = ref.read(calendarEventByIdProvider(widget.eventId)).asData?.value;
    if (event == null || !ensayoLiveAllowsPosting(event)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aún no ha empezado el ensayo. Espera al inicio.'),
        ),
      );
      return;
    }

    setState(() => _isPosting = true);
    try {
      final created = await ref.read(eventLiveUpdatesRepositoryProvider).postUpdate(
            eventId: widget.eventId,
            userId: profile.id,
            message: message,
            authorHandle: profile.handle,
            placeLabel: _placeLabel,
            latitude: _latitude,
            longitude: _longitude,
          );
      _messageController.clear();
      _clearLocation();
      ref.read(eventLiveUpdatesProvider(widget.eventId).notifier).upsert(created);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aviso publicado')),
        );
      }
    } on EventLiveUpdateRateLimitedException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Espera un minuto antes de publicar otro aviso'),
        ),
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

  Future<void> _toggleParaTi(EventLiveUpdate update) async {
    final show = !update.shownInParaTi;
    try {
      final featuredAt = await ref
          .read(eventLiveUpdatesRepositoryProvider)
          .setShownInParaTi(id: update.id, show: show);
      ref.read(eventLiveUpdatesProvider(widget.eventId).notifier).upsert(
            update.copyWith(featuredAt: featuredAt, clearFeatured: !show),
          );
      ref.invalidate(todayCuaresmaLiveTweetsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(show ? 'Visible en Para ti' : 'Quitado de Para ti'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar Para ti')),
      );
    }
  }

  Future<void> _deleteUpdate(EventLiveUpdate update) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar aviso'),
        content: const Text(
          'Se quita del hilo de este evento. No se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref
          .read(eventLiveUpdatesRepositoryProvider)
          .deleteUpdate(update.id);
      ref
          .read(eventLiveUpdatesProvider(widget.eventId).notifier)
          .removeById(update.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar el aviso')),
      );
    }
  }

  Future<void> _openMaps(EventLiveUpdate update) async {
    final uri = update.hasCoordinates
        ? Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=${update.latitude},${update.longitude}',
          )
        : update.placeLabel != null
            ? Uri.parse(
                'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(update.placeLabel!)}',
              )
            : null;

    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el mapa')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = watchMinuteClock(ref);
    final eventAsync = ref.watch(calendarEventByIdProvider(widget.eventId));
    final updatesAsync = ref.watch(eventLiveUpdatesProvider(widget.eventId));
    ref.watch(eventLiveUpdatesRealtimeProvider(widget.eventId));
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final isSuspended = profile?.isSuspended ?? false;
    final isStaff = ref.watch(isStaffProvider);
    final isClosing = _isClosingLive;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        title: Text(
          '¿Dónde está ahora?',
          style: TopicDetailTypography.appBarTitle(),
        ),
        actions: [
          if (isStaff)
            eventAsync.maybeWhen(
              data: (event) {
                if (event == null) return const SizedBox.shrink();
                final closed =
                    event.liveForceState == EventLiveForceState.closed;
                return TextButton(
                  onPressed: isClosing
                      ? null
                      : () => _toggleLiveForce(
                            event,
                            close: !closed,
                          ),
                  child: Text(
                    isClosing
                        ? '…'
                        : closed
                            ? 'Reabrir'
                            : 'Cerrar live',
                    style: TextStyle(
                      color: closed
                          ? AppColors.burgundy
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      body: eventAsync.when(
        skipLoadingOnReload: true,
        loading: () => const LiveFeedSkeleton(),
        error: (_, _) => _ErrorState(onBack: () => context.pop()),
        data: (event) {
          if (event == null || !event.type.opensCuaresmaLive) {
            return _ErrorState(onBack: () => context.pop());
          }

          final isFinished = ensayoStatusLabel(event, now: now) == 'Finalizado';
          final isLive = ensayoLiveAllowsPosting(event, now: now);
          final canPost = profile != null && !isSuspended && isLive;

          return Column(
            children: [
              EnsayoLiveEventHero(event: event),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _EventNewsStrip(
                          eventId: widget.eventId,
                          eventTitle: event.title,
                          isStaff: isStaff,
                          onPublish: () => _publishNews(event),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                          child: EnsayoLiveSectionHeader(
                            title: 'Avisos en directo',
                            subtitle: updatesAsync.maybeWhen(
                              data: (updates) => ensayoLiveFeedSubtitle(
                                event: event,
                                updateCount: updates.length,
                              ),
                              orElse: () => ensayoLiveFeedSubtitle(
                                event: event,
                                updateCount: 0,
                              ),
                            ),
                          ),
                        ),
                      ),
                      updatesAsync.when(
                        data: (updates) {
                          if (updates.isEmpty) {
                            return SliverToBoxAdapter(
                              child: EnsayoLiveEmptyState(event: event),
                            );
                          }

                          return SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => EnsayoLiveUpdateTile(
                                  update: updates[index],
                                  isLatest: index == 0,
                                  onOpenMaps: () => _openMaps(updates[index]),
                                  onDelete: isStaff
                                      ? () => _deleteUpdate(updates[index])
                                      : null,
                                  onToggleParaTi: isStaff
                                      ? () => _toggleParaTi(updates[index])
                                      : null,
                                ),
                                childCount: updates.length,
                              ),
                            ),
                          );
                        },
                        loading: () => const SliverFillRemaining(
                          child: LiveFeedSkeleton(),
                        ),
                        error: (_, _) => SliverFillRemaining(
                          child: Center(
                            child: Text(
                              'No se pudieron cargar los avisos',
                              style: TopicDetailTypography.meta(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isSuspended)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: SuspendedAccountBanner(compact: true),
                ),
              if (canPost)
                EnsayoLiveComposeBar(
                  controller: _messageController,
                  isPosting: _isPosting,
                  isLocating: _isLocating,
                  hasLocation: _latitude != null && _longitude != null,
                  placeLabel: _placeLabel,
                  hintText: ensayoLiveComposeHint(event),
                  onUseLocation: _useMyLocation,
                  onClearLocation: _clearLocation,
                  onSubmit: _submit,
                )
              else if (isFinished)
                const EnsayoLiveClosedBar()
              else if (!isLive)
                EnsayoLiveWaitingBar(event: event),
            ],
          );
        },
      ),
    );
  }
}

class _EventNewsStrip extends ConsumerWidget {
  const _EventNewsStrip({
    required this.eventId,
    required this.eventTitle,
    required this.isStaff,
    required this.onPublish,
  });

  final String eventId;
  final String eventTitle;
  final bool isStaff;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(eventEditorialPostsProvider(eventId));
    final items = posts.asData?.value ?? const <ForumTopic>[];
    if (!isStaff && items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isStaff)
            OutlinedButton.icon(
              onPressed: onPublish,
              icon: const Icon(Icons.campaign_outlined, size: 18),
              label: const Text('Publicar noticia'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.burgundy,
                side: BorderSide(
                  color: AppColors.burgundy.withValues(alpha: 0.35),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          if (items.isNotEmpty) ...[
            if (isStaff) const SizedBox(height: 12),
            EnsayoLiveSectionHeader(
              title: 'Noticias oficiales',
              subtitle: items.length == 1
                  ? 'Círculo Cofrade · este acto'
                  : '${items.length} de Círculo Cofrade · más reciente arriba',
            ),
            const SizedBox(height: 10),
            for (final topic in items) ...[
              _EventNewsTile(topic: topic, eventTitle: eventTitle),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _EventNewsTile extends StatelessWidget {
  const _EventNewsTile({
    required this.topic,
    required this.eventTitle,
  });

  final ForumTopic topic;
  final String eventTitle;

  @override
  Widget build(BuildContext context) {
    final cover = topic.editorialPosterUrl;
    final when = topic.createdAt;
    final stamp = when != null ? formatLiveStamp(when) : topic.timeAgo;
    final excerpt = plainTextForExcerpt(
      topic.excerpt.trim().isNotEmpty ? topic.excerpt : topic.body,
      maxLength: 120,
    );
    final title = topic.title.trim();
    final repeatsEvent = title.toLowerCase() == eventTitle.trim().toLowerCase();
    final headline = repeatsEvent && excerpt.isNotEmpty ? excerpt : title;
    final sub = !repeatsEvent &&
            excerpt.isNotEmpty &&
            excerpt.toLowerCase() != title.toLowerCase()
        ? excerpt
        : null;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/foros/${topic.forumId}/tema/${topic.id}'),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.burgundy.withValues(alpha: 0.16),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 3, color: AppColors.burgundy),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
                    child: cover != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CofradeoNetworkImage(
                              url: cover,
                              width: 56,
                              height: 56,
                            ),
                          )
                        : const AppLogo(
                            size: 40,
                            useIconVariant: true,
                            circular: true,
                          ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 10, 4, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  editorialPublicName.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TopicDetailTypography.meta(
                                    color: AppColors.burgundy,
                                    fontWeight: FontWeight.w700,
                                  ).copyWith(
                                    fontSize: 10,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                stamp,
                                style: TopicDetailTypography.meta(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w800,
                                ).copyWith(
                                  fontSize: 12,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            headline,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TopicDetailTypography.body().copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              height: 1.25,
                            ),
                          ),
                          if (sub != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              sub,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TopicDetailTypography.meta(
                                color: AppColors.textSecondary,
                              ).copyWith(fontSize: 12, height: 1.3),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.chevron_right,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_busy_outlined, size: 40),
            const SizedBox(height: 12),
            Text(
              'No encontramos este ensayo',
              style: TopicDetailTypography.title(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onBack, child: const Text('Volver')),
          ],
        ),
      ),
    );
  }
}
