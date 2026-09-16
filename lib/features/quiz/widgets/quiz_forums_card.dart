import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../quiz_provider.dart';

/// Botón flotante de la pregunta en vivo (Foros).
/// Pegado abajo-derecha del contenido; anuncio y nav van en el shell debajo.
class QuizForumsFab extends ConsumerStatefulWidget {
  const QuizForumsFab({super.key});

  @override
  ConsumerState<QuizForumsFab> createState() => _QuizForumsFabState();
}

class _QuizForumsFabState extends ConsumerState<QuizForumsFab>
    with SingleTickerProviderStateMixin {
  static const double _size = 72;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liveAsync = ref.watch(quizLivePayloadProvider);

    final live = liveAsync.asData?.value.isLive == true &&
        liveAsync.asData?.value.isAnswered != true;
    final answered = liveAsync.asData?.value.isAnswered == true;

    final tooltip = live
        ? '¡Pregunta en vivo! 15 segundos'
        : answered
            ? 'Ver ranking de la pregunta'
            : 'Pregunta en vivo';

    return Positioned(
      right: 14,
      bottom: 10,
      width: _size + 16,
      height: _size + 16,
      child: Tooltip(
        message: tooltip,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final pulse = live ? _pulseController.value : 0.0;

            return Center(
              child: SizedBox(
                width: _size + 16,
                height: _size + 16,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    if (live) ...[
                      // Anillo exterior pulsante (solo borde dorado).
                      Container(
                        width: _size + 10 + (pulse * 6),
                        height: _size + 10 + (pulse * 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: AppColors.gold.withValues(
                              alpha: 0.35 - (pulse * 0.18),
                            ),
                            width: 1.5,
                          ),
                        ),
                      ),
                      // Halo suave acotado al botón.
                      Container(
                        width: _size + 4,
                        height: _size + 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withValues(
                                alpha: 0.28 + (pulse * 0.22),
                              ),
                              blurRadius: 10 + (pulse * 8),
                              spreadRadius: 0.5,
                            ),
                          ],
                        ),
                      ),
                    ],
                    child!,
                  ],
                ),
              ),
            );
          },
          child: Material(
            color: Colors.transparent,
            elevation: live ? 4 : 2,
            shadowColor: AppColors.gold.withValues(alpha: live ? 0.35 : 0.18),
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                if (answered) {
                  context.push('/quiz/ranking');
                } else {
                  context.push('/quiz');
                }
              },
              child: Ink(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: live
                        ? AppColors.gold
                        : AppColors.goldDark.withValues(alpha: 0.28),
                    width: live ? 2.2 : 1.1,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16.5),
                        child: Image.asset(
                          AppAssets.quizLiveLogo,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    if (live)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF3D0008),
                              width: 1.3,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
