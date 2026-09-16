import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/calendar_event.dart';
import '../../forums/topic_detail_typography.dart';
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
  double? _latitude;
  double? _longitude;
  String? _placeLabel;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      ref.invalidate(eventLiveUpdatesProvider(widget.eventId));
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
    ref.invalidate(eventLiveUpdatesProvider(widget.eventId));
    ref.invalidate(calendarEventByIdProvider(widget.eventId));
    await ref.read(eventLiveUpdatesProvider(widget.eventId).future);
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
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _placeLabel = 'Mi ubicación';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ubicación añadida. Se enviará con tu aviso.'),
            duration: Duration(seconds: 3),
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
      await ref.read(eventLiveUpdatesRepositoryProvider).postUpdate(
            eventId: widget.eventId,
            userId: profile.id,
            message: message,
            placeLabel: _placeLabel,
            latitude: _latitude,
            longitude: _longitude,
          );
      _messageController.clear();
      _clearLocation();
      ref.invalidate(eventLiveUpdatesProvider(widget.eventId));
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
    final eventAsync = ref.watch(calendarEventByIdProvider(widget.eventId));
    final updatesAsync = ref.watch(eventLiveUpdatesProvider(widget.eventId));
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final isSuspended = profile?.isSuspended ?? false;

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
      ),
      body: eventAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _ErrorState(onBack: () => context.pop()),
        data: (event) {
          if (event == null || event.type != EventType.ensayo) {
            return _ErrorState(onBack: () => context.pop());
          }

          final isFinished = ensayoStatusLabel(event) == 'Finalizado';
          final isLive = ensayoLiveAllowsPosting(event);
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
                                ),
                                childCount: updates.length,
                              ),
                            ),
                          );
                        },
                        loading: () => const SliverFillRemaining(
                          child: Center(child: CircularProgressIndicator()),
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
