import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:page_flip/page_flip.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/chronicler_badge.dart';
import '../../../core/widgets/cofradeo_avatar.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../../auth/auth_provider.dart';
import '../../permissions/permissions_provider.dart';
import '../cronicon_brand.dart';
import '../historias_provider.dart';
import '../models/historia.dart';
import '../widgets/cronicon_mark.dart';
import '../widgets/historia_comments_sheet.dart';
import '../widgets/historia_compose_sheet.dart';

const _paper = Color(0xFFFBF6EA);
const _desk = Color(0xFFE4D2B8);

class HistoriaReaderScreen extends ConsumerWidget {
  const HistoriaReaderScreen({super.key, required this.historiaId});

  final String historiaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(historiaByIdProvider(historiaId));

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
        return _BookReader(
          key: ValueKey(
            '${historia.id}|${historia.title}|${historia.coverImageUrl}|'
            '${historia.pages.map((p) => '${p.body.length}:${p.imageUrl}').join(',')}',
          ),
          historia: historia,
        );
      },
    );
  }
}

class _BookReader extends ConsumerStatefulWidget {
  const _BookReader({super.key, required this.historia});

  final Historia historia;

  @override
  ConsumerState<_BookReader> createState() => _BookReaderState();
}

class _BookReaderState extends ConsumerState<_BookReader> {
  var _page = 0;

  Historia get historia => widget.historia;

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
      backgroundColor: _desk,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 48, 10, 36),
              child: PageFlipWidget(
                backgroundColor: _paper,
                duration: const Duration(milliseconds: 520),
                onPageFlipped: (page) => setState(() => _page = page),
                lastPage: _ColophonPage(
                  historia: historia,
                  others: others,
                ),
                children: [
                  _CoverLeaf(historia: historia),
                  for (var i = 0; i < historia.pages.length; i++)
                    _PaperLeaf(
                      page: historia.pages[i],
                      dropCap: i == 0,
                    ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.burgundyDark,
                  ),
                  const Spacer(),
                  if (!onCover)
                    Flexible(
                      child: Text(
                        historia.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTypography.hermandadName().copyWith(
                          fontSize: 16,
                        ),
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
                      color: AppColors.burgundyDark,
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
                    color: AppColors.burgundyDark,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTypography.labelSmall(color: AppColors.goldDark)
                      .copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.6),
                ),
              ),
            ),
          ),
        ],
      ),
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
      color: const Color(0xFF3A1A16),
      child: cover != null && cover.isNotEmpty
          ? CofradeoNetworkImage(url: cover, fit: BoxFit.cover)
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
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
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
    return ColoredBox(
      color: _paper,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 32, 26, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              CofradeoNetworkImage(
                url: imageUrl,
                fit: BoxFit.cover,
                height: 210,
              ),
              if (caption != null && caption.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: AppTypography.bookCaption(),
                ),
              ],
              const SizedBox(height: 20),
            ],
            if (page.hasText)
              dropCap
                  ? _DropCapText(page.body)
                  : Text(page.body, style: AppTypography.bookBody()),
          ],
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
        padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
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
    );
  }
}
