import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:page_flip/page_flip.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/chronicler_badge.dart';
import '../../../core/widgets/cofradeo_avatar.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../../../core/widgets/forum_post_content.dart';
import '../../auth/auth_provider.dart';
import '../../permissions/permissions_provider.dart';
import '../cronicon_brand.dart';
import '../historias_provider.dart';
import '../models/historia.dart';
import '../models/historia_reading_progress.dart';
import '../widgets/cronicon_mark.dart';
import '../widgets/historia_comments_sheet.dart';
import '../widgets/historia_compose_sheet.dart';

const _paper = Color(0xFFFBF6EA);
const _desk = Color(0xFFE4D2B8);

class HistoriaReaderScreen extends ConsumerStatefulWidget {
  const HistoriaReaderScreen({
    super.key,
    required this.historiaId,
    this.resumePage,
  });

  final String historiaId;
  final int? resumePage;

  @override
  ConsumerState<HistoriaReaderScreen> createState() =>
      _HistoriaReaderScreenState();
}

class _HistoriaReaderScreenState extends ConsumerState<HistoriaReaderScreen> {
  /// Se fija al abrir. Si no, guardar la hoja reconstruye el libro.
  int? _openedAtPage;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(historiaByIdProvider(widget.historiaId));
    final progress = _openedAtPage == null
        ? ref.watch(historiaReadingPageProvider(widget.historiaId))
        : const AsyncValue<int>.data(0);

    return async.when(
      loading: () => const Scaffold(
        backgroundColor: _desk,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('No se pudo abrir esta obra.')),
      ),
      data: (historia) {
        if (historia == null || historia.pages.isEmpty) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Esta obra ya no está.')),
          );
        }
        if (_openedAtPage == null) {
          if (widget.resumePage == null &&
              !progress.hasValue &&
              !progress.hasError) {
            return const Scaffold(
              backgroundColor: _desk,
              body: Center(child: CircularProgressIndicator()),
            );
          }
          _openedAtPage = historiaReaderStartPage(
            widget.resumePage ?? progress.asData?.value ?? 0,
            historia.pages.length,
          );
        }
        return _BookReader(
          key: ValueKey(
            '${historia.id}|${historia.title}|${historia.coverImageUrl}|'
            '${historia.pages.map((p) => '${p.body.length}:${p.imageUrl}').join(',')}',
          ),
          historia: historia,
          initialPage: _openedAtPage!,
        );
      },
    );
  }
}

class _BookReader extends ConsumerStatefulWidget {
  const _BookReader({
    super.key,
    required this.historia,
    this.initialPage = 0,
  });

  final Historia historia;
  final int initialPage;

  @override
  ConsumerState<_BookReader> createState() => _BookReaderState();
}

class _BookReaderState extends ConsumerState<_BookReader>
    with WidgetsBindingObserver {
  late int _page = widget.initialPage;
  Timer? _saveTimer;

  Historia get historia => widget.historia;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      unawaited(_persist(_page, refreshShelf: true));
    }
  }

  @override
  void deactivate() {
    _saveTimer?.cancel();
    // El container sigue vivo en la estantería; `mounted` ya no, tras el pop.
    try {
      final container = ProviderScope.containerOf(context);
      unawaited(_persist(_page, refreshShelf: true, container: container));
    } catch (_) {}
    super.deactivate();
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/foros');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    super.dispose();
  }

  void _onFlipped(int page) {
    setState(() => _page = page);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 450), () {
      unawaited(_persist(page));
    });
  }

  Future<void> _persist(
    int page, {
    bool refreshShelf = false,
    ProviderContainer? container,
  }) async {
    final host = container;
    try {
      final repo = host != null
          ? host.read(historiasRepositoryProvider)
          : ref.read(historiasRepositoryProvider);
      await repo.saveReadingProgress(
        historiaId: historia.id,
        page: page,
        pageCount: historia.pages.length,
      );
      if (refreshShelf) {
        if (host != null) {
          host.invalidate(continueReadingProvider);
        } else if (mounted) {
          ref.invalidate(continueReadingProvider);
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final others = ref
            .watch(publishedHistoriasByAuthorProvider(historia.authorId))
            .asData
            ?.value
            .where((item) => item.id != historia.id)
            .toList(growable: false) ??
        const <Historia>[];
    final paperCount = historia.pages.length;
    final onCover = _page == 0;
    final me = ref.watch(currentUserProvider);
    final canEdit = me != null &&
        (me.id == historia.authorId || ref.watch(isJuntaMemberProvider));
    final label = onCover
        ? 'Portada'
        : _page > paperCount
            ? 'Fin'
            : '$_page / $paperCount';

    return Scaffold(
      backgroundColor: onCover ? const Color(0xFF2A1210) : _desk,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _leave,
                    icon: Icon(
                      Icons.close_rounded,
                      color: onCover ? AppColors.goldPale : AppColors.burgundyDark,
                    ),
                    label: Text(
                      'Salir',
                      style: AppTypography.labelSmall(
                        color: onCover
                            ? AppColors.goldPale
                            : AppColors.burgundyDark,
                      ).copyWith(fontWeight: FontWeight.w800),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: onCover
                          ? Colors.black.withValues(alpha: 0.35)
                          : _paper.withValues(alpha: 0.92),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const Spacer(),
                  if (!onCover)
                    Flexible(
                      child: Text(
                        historia.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium(
                          color: AppColors.textPrimary,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  const Spacer(),
                  if (canEdit)
                    IconButton(
                      tooltip: 'Editar',
                      onPressed: () async {
                        final saved = await showHistoriaComposeSheet(
                          context,
                          existing: historia,
                        );
                        if (saved) {
                          ref.invalidate(historiaByIdProvider(historia.id));
                          ref.invalidate(publishedHistoriasFeedProvider);
                          ref.invalidate(publishedHistoriasProvider);
                          ref.invalidate(myHistoriasProvider);
                        }
                      },
                      icon: const Icon(Icons.edit_outlined),
                      color: onCover
                          ? AppColors.goldPale
                          : AppColors.burgundyDark,
                    ),
                  IconButton(
                    tooltip: 'Comentarios',
                    onPressed: () => showHistoriaCommentsSheet(
                      context,
                      historiaId: historia.id,
                      commentCount: historia.commentCount,
                    ),
                    icon: Badge(
                      isLabelVisible: historia.commentCount > 0,
                      label: Text('${historia.commentCount}'),
                      child: const Icon(Icons.chat_bubble_outline_rounded),
                    ),
                    color: onCover
                        ? AppColors.goldPale
                        : AppColors.burgundyDark,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _TurningPages(
                initialPage: widget.initialPage.clamp(
                  0,
                  historia.pages.length,
                ),
                onPageChanged: _onFlipped,
                pages: [
                  _CoverLeaf(historia: historia),
                  for (var i = 0; i < historia.pages.length; i++)
                    _PaperLeaf(
                      page: historia.pages[i],
                      dropCap: i == 0,
                    ),
                  _ColophonPage(historia: historia, others: others),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppTypography.labelSmall(
                  color: onCover ? AppColors.goldPale : AppColors.goldDark,
                ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rizo de la hoja con el dedo. Quieta, se pinta el texto vivo.
/// El bitmap solo existe mientras el papel se está doblando.
class _TurningPages extends StatefulWidget {
  const _TurningPages({
    required this.initialPage,
    required this.onPageChanged,
    required this.pages,
  });

  final int initialPage;
  final ValueChanged<int> onPageChanged;
  final List<Widget> pages;

  @override
  State<_TurningPages> createState() => _TurningPagesState();
}

class _TurningPagesState extends State<_TurningPages>
    with SingleTickerProviderStateMixin {
  late int _index = widget.initialPage.clamp(0, widget.pages.length - 1);
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  final _dragN = ValueNotifier<double>(0);
  final _curKey = GlobalKey();
  final _prevKey = GlobalKey();
  ui.Image? _sheet;
  Future<void>? _captureJob;
  bool _forward = true;
  bool _turning = false;
  bool _fallback = false;
  bool _busy = false;
  double _drag = 0;
  double _pending = 0;

  @override
  void dispose() {
    _turn.dispose();
    _dragN.dispose();
    _sheet?.dispose();
    _sheet = null;
    super.dispose();
  }

  void _setDrag(double value) {
    if (!mounted) return;
    _drag = value.clamp(0.0, 1.0);
    _dragN.value = _drag;
    if (_fallback) setState(() {});
  }

  Future<void> _animateTo(double target) async {
    if ((_drag - target).abs() < 0.001) {
      _setDrag(target);
      return;
    }
    final start = _drag;
    void tick() {
      if (!mounted) return;
      final t = Curves.easeOutCubic.transform(_turn.value);
      _setDrag(start + (target - start) * t);
    }

    _turn.addListener(tick);
    _turn.reset();
    try {
      await _turn.forward();
    } on TickerCanceled {
      // El lector se cerró a mitad del rizo.
    } finally {
      try {
        _turn.removeListener(tick);
      } catch (_) {}
    }
  }

  Future<ui.Image?> _snap(GlobalKey key) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final boundary = key.currentContext?.findRenderObject();
      if (boundary is RenderRepaintBoundary &&
          boundary.hasSize &&
          !boundary.size.isEmpty) {
        try {
          final ratio =
              MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.0);
          final image = await boundary.toImage(pixelRatio: ratio);
          if (image.width > 0 && image.height > 0) return image;
          image.dispose();
        } catch (_) {
          // La hoja aún no estaba pintada. Se reintenta un frame.
        }
      }
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return null;
    }
    return null;
  }

  Future<void> _ensureSheet() async {
    if (_sheet != null || _fallback) return;
    final forward = _forward;
    final last = widget.pages.length - 1;
    if (forward && _index >= last) return;
    if (!forward && _index <= 0) return;
    if (mounted) setState(() => _turning = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final image = await _snap(forward ? _curKey : _prevKey);
    if (!mounted) {
      image?.dispose();
      return;
    }
    if (image == null) {
      setState(() => _fallback = true);
      return;
    }
    setState(() => _sheet = image);
  }

  void _dropSheet(ui.Image? image) {
    if (image == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => image.dispose());
  }

  void _commit(bool forward) {
    final image = _sheet;
    final next = (_index + (forward ? 1 : -1)).clamp(
      0,
      widget.pages.length - 1,
    );
    setState(() {
      _index = next;
      _drag = 0;
      _turning = false;
      _fallback = false;
      _sheet = null;
      _captureJob = null;
    });
    _dragN.value = 0;
    widget.onPageChanged(_index);
    _dropSheet(image);
  }

  void _resetTurn() {
    final image = _sheet;
    setState(() {
      _drag = 0;
      _turning = false;
      _fallback = false;
      _sheet = null;
      _captureJob = null;
    });
    _dragN.value = 0;
    _dropSheet(image);
  }

  Future<void> _finishTurn(bool forward) async {
    if (_busy || _turning) return;
    if (forward && _index >= widget.pages.length - 1) return;
    if (!forward && _index <= 0) return;
    _busy = true;
    _forward = forward;
    _turning = true;
    _captureJob = _ensureSheet();
    try {
      await _captureJob;
      if (!mounted) return;
      await _animateTo(1);
      if (!mounted) return;
      _commit(forward);
    } finally {
      _busy = false;
    }
  }

  void _onDragUpdate(DragUpdateDetails details, double width) {
    if (_busy || width <= 0) return;
    if (!_turning) {
      _pending += details.delta.dx;
      if (_pending.abs() < 10) return;
      final forward = _pending < 0;
      if (forward && _index >= widget.pages.length - 1) {
        _pending = 0;
        return;
      }
      if (!forward && _index <= 0) {
        _pending = 0;
        return;
      }
      _forward = forward;
      final seeded = _pending.abs() / width;
      _pending = 0;
      _turning = true;
      _captureJob = _ensureSheet();
      _setDrag(seeded);
      return;
    }
    final delta = details.delta.dx / width;
    _setDrag(_forward ? _drag - delta : _drag + delta);
  }

  Future<void> _onDragEnd() async {
    _pending = 0;
    if (_busy || (!_turning && _drag == 0)) return;
    _busy = true;
    try {
      final job = _captureJob;
      if (job != null) await job;
      if (!mounted) return;
      if (_drag > 0.18) {
        await _animateTo(1);
        if (!mounted) return;
        _commit(_forward);
      } else {
        await _animateTo(0);
        if (!mounted) return;
        _resetTurn();
      }
    } finally {
      _busy = false;
    }
  }

  void _onTap(TapUpDetails details, double width) {
    if (_busy || _turning || width <= 0) return;
    if (details.localPosition.dx >= width * 0.7) {
      _finishTurn(true);
    } else if (details.localPosition.dx <= width * 0.3) {
      _finishTurn(false);
    }
  }

  Widget _hinge(Widget child, double angle) {
    return Transform(
      alignment: Alignment.centerLeft,
      filterQuality: FilterQuality.medium,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0015)
        ..rotateY(angle),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final last = widget.pages.length - 1;
    final curlingForward = _sheet != null && _forward;
    final hingeForward = _fallback && _forward && _drag > 0;
    final hingeBack = _fallback && !_forward && _drag > 0;
    final showNext = _turning && _forward && _index < last;
    final showPrev = _index > 0 && _sheet == null && !hingeForward && !hingeBack;
    final showCurrent = !curlingForward && !hingeForward;

    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: (details) =>
                _onDragUpdate(details, constraints.maxWidth),
            onHorizontalDragEnd: (_) => _onDragEnd(),
            onHorizontalDragCancel: () {
              _pending = 0;
              if (_turning && !_busy) _onDragEnd();
            },
            onTapUp: (details) => _onTap(details, constraints.maxWidth),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (showNext)
                  IgnorePointer(child: widget.pages[_index + 1]),
                if (showPrev)
                  IgnorePointer(
                    child: RepaintBoundary(
                      key: _prevKey,
                      child: widget.pages[_index - 1],
                    ),
                  ),
                if (showCurrent)
                  RepaintBoundary(
                    key: _curKey,
                    child: widget.pages[_index],
                  ),
                if (hingeForward)
                  _hinge(widget.pages[_index], -_drag * math.pi / 2),
                if (hingeBack)
                  _hinge(
                    widget.pages[_index - 1],
                    -(1 - _drag) * math.pi / 2,
                  ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: ValueListenableBuilder<double>(
                      valueListenable: _dragN,
                      builder: (context, drag, _) {
                        final image = _sheet;
                        if (image == null) return const SizedBox.shrink();
                        if (!_forward && drag <= 0) {
                          return const SizedBox.shrink();
                        }
                        final amount = _forward ? (1 - drag) : drag;
                        return CustomPaint(
                          painter: PageFlipEffect(
                            amount: AlwaysStoppedAnimation(amount),
                            image: image,
                            backgroundColor: _paper,
                            isRightSwipe: false,
                          ),
                          child: const SizedBox.expand(),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CoverLeaf extends StatelessWidget {
  const _CoverLeaf({required this.historia});

  final Historia historia;

  @override
  Widget build(BuildContext context) {
    final cover = historia.coverImageUrl?.trim();
    return ColoredBox(
      color: const Color(0xFF2A1210),
      child: cover != null && cover.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 0.68,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.55),
                          blurRadius: 28,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: CofradeoNetworkImage(
                        url: cover,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        alignment: Alignment.center,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : _TitlePage(historia: historia),
    );
  }
}

class _TitlePage extends StatelessWidget {
  const _TitlePage({required this.historia});

  final Historia historia;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
      child: Column(
        children: [
          Text(
            CroniconBrand.imprintLine,
            style: AppTypography.labelSmall(color: AppColors.gold).copyWith(
              letterSpacing: 2.2,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            CroniconBrand.name,
            style: AppTypography.hermandadName(color: AppColors.goldPale)
                .copyWith(fontSize: 13, letterSpacing: 0.4),
          ),
          const SizedBox(height: 8),
          Container(width: 42, height: 1, color: AppColors.gold),
          const Spacer(),
          Text(
            historia.kind.label.toUpperCase(),
            style: AppTypography.labelSmall(color: AppColors.goldPale).copyWith(
              letterSpacing: 1.6,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            historia.title,
            textAlign: TextAlign.center,
            style: AppTypography.displayMedium(color: AppColors.textOnDark)
                .copyWith(height: 1.12),
          ),
          if (historia.excerpt.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              historia.excerpt,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bookCaption(color: AppColors.goldPale),
            ),
          ],
          const Spacer(),
          _CoverByline(historia: historia, onDark: true),
        ],
      ),
    );
  }
}

class _CoverByline extends StatelessWidget {
  const _CoverByline({required this.historia, required this.onDark});

  final Historia historia;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final nameColor = onDark ? AppColors.textOnDark : AppColors.textPrimary;
    return GestureDetector(
      onTap: () => context.push('/historias/autor/${historia.authorId}'),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CofradeoAvatar(
            imageUrl: historia.authorAvatarUrl,
            size: 22,
            backgroundColor: AppColors.backgroundElevated,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              historia.authorDisplayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium(color: nameColor)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 4),
          const ChroniclerIcon(size: 14),
        ],
      ),
    );
  }
}

class _PaperLeaf extends StatelessWidget {
  const _PaperLeaf({
    required this.page,
    required this.dropCap,
  });

  final HistoriaPage page;
  final bool dropCap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = page.imageUrl?.trim();
    final caption = page.caption?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    return ColoredBox(
      color: _desk,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _paper,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasImage) ...[
                  Expanded(
                    flex: page.hasText ? 5 : 8,
                    child: _PagePicture(
                      url: imageUrl,
                      caption: caption,
                    ),
                  ),
                  if (page.hasText) const SizedBox(height: 14),
                ],
                if (page.hasText)
                  Expanded(
                    flex: hasImage ? 5 : 8,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: SingleChildScrollView(
                        child: _HistoriaPageBody(
                          body: page.body,
                          dropCap: dropCap,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ColophonPage extends StatelessWidget {
  const _ColophonPage({
    required this.historia,
    required this.others,
  });

  final Historia historia;
  final List<Historia> others;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _paper,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            const CroniconColophonMark(),
            const SizedBox(height: 14),
            Text(
              CroniconBrand.publishedIn,
              textAlign: TextAlign.center,
              style: AppTypography.bookCaption(),
            ),
            const SizedBox(height: 8),
            Text(
              historia.title,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium(),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () =>
                  context.push('/historias/autor/${historia.authorId}'),
              child: Column(
                children: [
                  CofradeoAvatar(
                    imageUrl: historia.authorAvatarUrl,
                    size: 44,
                    backgroundColor: AppColors.backgroundElevated,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        historia.authorDisplayName,
                        style: AppTypography.bodyMedium(
                          color: AppColors.textPrimary,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 4),
                      const ChroniclerIcon(size: 14),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            if (others.isNotEmpty) ...[
              Text(
                'Más de este cronista',
                style: AppTypography.sectionTitle(),
              ),
              const SizedBox(height: 10),
              for (final item in others.take(4))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.title, maxLines: 1),
                  subtitle: Text(item.kind.label),
                  onTap: () => context.push('/historias/${item.id}'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PagePicture extends StatelessWidget {
  const _PagePicture({required this.url, this.caption});

  final String url;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final note = caption?.trim();
    return Column(
      children: [
        Expanded(
          child: SizedBox.expand(
            child: CofradeoNetworkImage(
              url: url,
              fit: BoxFit.contain,
              alignment: Alignment.center,
            ),
          ),
        ),
        if (note != null && note.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            note,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bookCaption(),
          ),
        ],
      ],
    );
  }
}

class _HistoriaPageBody extends StatelessWidget {
  const _HistoriaPageBody({
    required this.body,
    required this.dropCap,
  });

  final String body;
  final bool dropCap;

  @override
  Widget build(BuildContext context) {
    if (dropCap && !_historiaHasFormat(body)) {
      return _DropCapText(body);
    }
    return ForumPostContent(
      text: body,
      style: AppTypography.bookBody(),
      subtleLinks: true,
    );
  }
}

bool _historiaHasFormat(String body) {
  return RegExp(r'(^|\n)\s*#{1,3}\s|\*\*|_[^\s*]|\*[^*\s]').hasMatch(body);
}

class _DropCapText extends StatelessWidget {
  const _DropCapText(this.body);

  final String body;

  @override
  Widget build(BuildContext context) {
    final trimmed = body.trimLeft();
    if (trimmed.isEmpty) return const SizedBox.shrink();
    final chars = trimmed.characters;
    final first = chars.first;
    final rest = chars.skip(1).toString();
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: first,
            style: AppTypography.bookBody(color: AppColors.burgundy).copyWith(
              fontSize: 46,
              height: 0.9,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: rest, style: AppTypography.bookBody()),
        ],
      ),
      overflow: TextOverflow.fade,
    );
  }
}
