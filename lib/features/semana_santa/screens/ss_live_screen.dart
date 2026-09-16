import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../forums/topic_detail_typography.dart';
import '../../profile/profile_provider.dart';
import '../../profile/widgets/suspended_account_banner.dart';
import '../models/ss_live_update.dart';
import '../semana_santa_provider.dart';
import '../widgets/ss_live_design.dart';

class SsLiveScreen extends ConsumerStatefulWidget {
  const SsLiveScreen({
    super.key,
    required this.forumId,
    required this.topicId,
  });

  final String forumId;
  final String topicId;

  @override
  ConsumerState<SsLiveScreen> createState() => _SsLiveScreenState();
}

class _SsLiveScreenState extends ConsumerState<SsLiveScreen> {
  final _messageController = TextEditingController();
  final _hermandadController = TextEditingController();
  final _placeController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _refreshTimer;
  var _kind = SsLiveUpdateKind.posicion;
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      ref.invalidate(ssLiveRawFeedProvider);
      ref.invalidate(ssLiveGateProvider);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    _hermandadController.dispose();
    _placeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(ssLiveRawFeedProvider);
    ref.invalidate(ssLiveGateProvider);
    await Future.wait([
      ref.read(ssLiveRawFeedProvider.future),
      ref.read(ssLiveGateProvider.future),
    ]);
  }

  Future<void> _submit() async {
    final profile = ref.read(currentUserProfileProvider).asData?.value;
    if (profile == null || profile.isSuspended) return;

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

    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe qué está pasando')),
      );
      return;
    }

    setState(() => _isPosting = true);
    try {
      await ref.read(ssLiveUpdatesRepositoryProvider).postUpdate(
            userId: profile.id,
            kind: _kind,
            message: message,
            hermandadLabel: _hermandadController.text.trim(),
            placeLabel: _placeController.text.trim(),
          );
      _messageController.clear();
      ref.invalidate(ssLiveRawFeedProvider);
      ref.invalidate(ssLiveEngagementProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aviso publicado')),
        );
      }
    } on SsLiveUpdateRateLimitedException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Espera un momento antes de publicar otro aviso'),
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

  @override
  Widget build(BuildContext context) {
    final updatesAsync = ref.watch(ssLiveFeedProvider);
    final filter = ref.watch(ssLiveFeedFilterProvider);
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final isSuspended = profile?.isSuspended ?? false;
    final gate = ref.watch(ssLiveGateProvider).asData?.value;
    final liveOpen = gate?.isOpen ?? true;
    final canPost = profile != null && !isSuspended && liveOpen;
    final jornadaLabel = gate?.activeDay?.label;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'En directo',
          style: TopicDetailTypography.appBarTitle(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _TodosFilterChip(
                    selected: filter == null,
                    onTap: () =>
                        ref.read(ssLiveFeedFilterProvider.notifier).setFilter(null),
                  ),
                  const SizedBox(width: 6),
                  for (final k in SsLiveUpdateKind.values) ...[
                    SsKindChip(
                      kind: k,
                      selected: filter == k,
                      compact: true,
                      onTap: () =>
                          ref.read(ssLiveFeedFilterProvider.notifier).setFilter(k),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),
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
                      child: Text(
                        [
                          if (jornadaLabel != null) 'Jornada: $jornadaLabel',
                          updatesAsync.maybeWhen(
                            data: (u) => u.isEmpty
                                ? (liveOpen
                                    ? 'Sé el primero en avisar desde la calle'
                                    : 'En directo cerrado')
                                : '${u.length} avisos · últimas 12 h',
                            orElse: () => 'Avisos de la Semana Santa',
                          ),
                        ].whereType<String>().join(' · '),
                        style: TopicDetailTypography.meta(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  updatesAsync.when(
                    data: (updates) {
                      if (updates.isEmpty) {
                        return SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'Todavía no hay avisos${filter == null ? '' : ' de este tipo'}.',
                                style: TopicDetailTypography.meta(
                                  color: AppColors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        );
                      }
                      return SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => SsLiveUpdateTile(
                              update: updates[index],
                              isLatest: index == 0,
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
          if (!liveOpen && profile != null && !isSuspended)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                gate?.closedMessage.isNotEmpty == true
                    ? gate!.closedMessage
                    : 'El en directo está cerrado ahora.',
                textAlign: TextAlign.center,
                style: TopicDetailTypography.meta(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          if (canPost)
            SsLiveComposeBar(
              controller: _messageController,
              hermandadController: _hermandadController,
              placeController: _placeController,
              kind: _kind,
              onKindChanged: (k) => setState(() => _kind = k),
              isPosting: _isPosting,
              onSubmit: _submit,
            ),
        ],
      ),
    );
  }
}

class _TodosFilterChip extends StatelessWidget {
  const _TodosFilterChip({
    required this.selected,
    required this.onTap,
  });

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.burgundy : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.burgundy.withValues(alpha: 0.12)
              : AppColors.backgroundElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.burgundy.withValues(alpha: 0.4)
                : AppColors.border,
          ),
        ),
        child: Text(
          'Todos',
          style: TopicDetailTypography.meta(
            color: color,
            fontWeight: FontWeight.w700,
          ).copyWith(fontSize: 11),
        ),
      ),
    );
  }
}
