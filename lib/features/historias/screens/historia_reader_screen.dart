import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/chronicler_badge.dart';
import '../../../core/widgets/cofradeo_avatar.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../historias_provider.dart';
import '../models/historia.dart';
import '../widgets/historia_comments_sheet.dart';

class HistoriaReaderScreen extends ConsumerStatefulWidget {
  const HistoriaReaderScreen({super.key, required this.historiaId});

  final String historiaId;

  @override
  ConsumerState<HistoriaReaderScreen> createState() =>
      _HistoriaReaderScreenState();
}

class _HistoriaReaderScreenState extends ConsumerState<HistoriaReaderScreen> {
  final _pager = PageController();
  var _page = 0;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(historiaByIdProvider(widget.historiaId));

    return async.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFFF3E6D0),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('No se pudo abrir esta historia.')),
      ),
      data: (historia) {
        if (historia == null || historia.pages.isEmpty) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Esta historia ya no está.')),
          );
        }
        return _ReaderBody(
          historia: historia,
          pager: _pager,
          page: _page,
          onPage: (value) => setState(() => _page = value),
        );
      },
    );
  }
}

class _ReaderBody extends StatelessWidget {
  const _ReaderBody({
    required this.historia,
    required this.pager,
    required this.page,
    required this.onPage,
  });

  final Historia historia;
  final PageController pager;
  final int page;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final pages = historia.pages;
    return Scaffold(
      backgroundColor: const Color(0xFFF3E6D0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3E6D0),
        foregroundColor: AppColors.burgundyDark,
        elevation: 0,
        title: Text(
          historia.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.hermandadName().copyWith(fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: 'Comentarios',
            onPressed: () => showHistoriaCommentsSheet(
              context,
              historiaId: historia.id,
            ),
            icon: Badge(
              isLabelVisible: historia.commentCount > 0,
              label: Text('${historia.commentCount}'),
              child: const Icon(Icons.chat_bubble_outline_rounded),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                CofradeoAvatar(
                  imageUrl: historia.authorAvatarUrl,
                  size: 28,
                  backgroundColor: AppColors.backgroundElevated,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          historia.authorDisplayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMedium(
                            color: AppColors.textPrimary,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const ChroniclerIcon(size: 14),
                    ],
                  ),
                ),
                Text(
                  '${page + 1} / ${pages.length}',
                  style: AppTypography.labelSmall(color: AppColors.goldDark)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: pager,
              itemCount: pages.length,
              onPageChanged: onPage,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBF6EA),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.burgundyDark.withValues(alpha: 0.12),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(22, 28, 22, 32),
                      child: _BookPage(page: pages[index]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BookPage extends StatelessWidget {
  const _BookPage({required this.page});

  final HistoriaPage page;

  @override
  Widget build(BuildContext context) {
    final imageUrl = page.imageUrl?.trim();
    final caption = page.caption?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (imageUrl != null && imageUrl.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CofradeoNetworkImage(
              url: imageUrl,
              fit: BoxFit.cover,
              height: 220,
            ),
          ),
          if (caption != null && caption.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              caption,
              textAlign: TextAlign.center,
              style: AppTypography.bookCaption(),
            ),
          ],
          const SizedBox(height: 18),
        ],
        if (page.hasText)
          Text(
            page.body,
            style: AppTypography.bookBody(),
          ),
      ],
    );
  }
}
