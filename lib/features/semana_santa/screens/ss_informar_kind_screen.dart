import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../forums/topic_detail_typography.dart';
import '../models/ss_live_update.dart';
import '../semana_santa_provider.dart';
import '../utils/ss_informar_helpers.dart';
import '../widgets/ss_live_design.dart';

/// Paso 1: elegir tipo de aviso.
class SsInformarKindScreen extends ConsumerWidget {
  const SsInformarKindScreen({
    super.key,
    required this.forumId,
    required this.topicId,
  });

  final String forumId;
  final String topicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canInform = ref.watch(ssCanInformProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.chevron_left, color: AppColors.burgundy),
        ),
        title: Text(
          'Informar',
          style: AppTypography.displaySmall().copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: canInform.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('No se pudo comprobar el permiso.'),
          ),
        ),
        data: (allowed) {
          if (!allowed) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Solo reporteros de confianza y hermandades pueden informar en Semana Santa.\n\nPuedes seguir el directo, reaccionar y responder.',
                  textAlign: TextAlign.center,
                  style: TopicDetailTypography.meta(
                    color: AppColors.textSecondary,
                  ).copyWith(fontSize: 14, height: 1.4),
                ),
              ),
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight - 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '¿Qué quieres informar?',
                        textAlign: TextAlign.center,
                        style: AppTypography.displaySmall(
                          color: AppColors.textPrimary,
                        ).copyWith(fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Selecciona el tipo de aviso',
                        textAlign: TextAlign.center,
                        style: TopicDetailTypography.meta(
                          color: AppColors.textSecondary,
                        ).copyWith(fontSize: 13.5),
                      ),
                      const SizedBox(height: 18),
                      for (final kind in SsLiveUpdateKind.values) ...[
                        _KindOptionCard(
                          kind: kind,
                          onTap: () => context.push(
                            '/foros/$forumId/tema/$topicId/informar/${kind.dbValue}',
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _KindOptionCard extends StatelessWidget {
  const _KindOptionCard({required this.kind, required this.onTap});

  final SsLiveUpdateKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = ssKindColor(kind);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.85)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(ssKindIcon(kind), color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kind.label,
                      style: TopicDetailTypography.body().copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ssInformarKindDescription(kind),
                      style: TopicDetailTypography.meta(
                        color: AppColors.textSecondary,
                      ).copyWith(fontSize: 12.5, height: 1.3),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted.withValues(alpha: 0.9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
