import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Bloque gris animado (base de skeletons).
class CofradeoSkeletonBone extends StatefulWidget {
  const CofradeoSkeletonBone({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = 8,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<CofradeoSkeletonBone> createState() => _CofradeoSkeletonBoneState();
}

class _CofradeoSkeletonBoneState extends State<CofradeoSkeletonBone>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        final color = Color.lerp(
          AppColors.border.withValues(alpha: 0.55),
          AppColors.goldPale.withValues(alpha: 0.85),
          t,
        )!;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// Skeleton del home de Foros (hero + banner + tarjetas).
class ForumsHomeSkeleton extends StatelessWidget {
  const ForumsHomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: top + 96,
          color: AppColors.burgundyDark.withValues(alpha: 0.85),
          padding: EdgeInsets.fromLTRB(20, top + 12, 20, 16),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CofradeoSkeletonBone(width: 120, height: 28, borderRadius: 6),
              SizedBox(height: 10),
              CofradeoSkeletonBone(width: 200, height: 14, borderRadius: 6),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: CofradeoSkeletonBone(height: 148, borderRadius: 16),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: CofradeoSkeletonBone(width: 140, height: 18, borderRadius: 6),
        ),
        Expanded(
          child: ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(height: 5),
            itemBuilder: (_, _) => const CofradeoSkeletonBone(
              height: 128,
              borderRadius: 16,
            ),
          ),
        ),
      ],
    );
  }
}

/// Skeleton del calendario (cabecera + rejilla + filas).
class CalendarHomeSkeleton extends StatelessWidget {
  const CalendarHomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const CofradeoSkeletonBone(height: 36, borderRadius: 10),
        const SizedBox(height: 16),
        const CofradeoSkeletonBone(height: 280, borderRadius: 16),
        const SizedBox(height: 20),
        const CofradeoSkeletonBone(width: 160, height: 18, borderRadius: 6),
        const SizedBox(height: 12),
        ...List.generate(
          4,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: CofradeoSkeletonBone(height: 72, borderRadius: 14),
          ),
        ),
      ],
    );
  }
}

/// Skeleton del perfil propio (banner + avatar + tabs).
class ProfileHomeSkeleton extends StatelessWidget {
  const ProfileHomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const CofradeoSkeletonBone(height: 120, borderRadius: 0),
        Transform.translate(
          offset: const Offset(0, -36),
          child: const Column(
            children: [
              CofradeoSkeletonBone(width: 72, height: 72, borderRadius: 36),
              SizedBox(height: 12),
              CofradeoSkeletonBone(width: 140, height: 20, borderRadius: 6),
              SizedBox(height: 8),
              CofradeoSkeletonBone(width: 100, height: 14, borderRadius: 6),
              SizedBox(height: 16),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    CofradeoSkeletonBone(width: 48, height: 36, borderRadius: 8),
                    CofradeoSkeletonBone(width: 48, height: 36, borderRadius: 8),
                    CofradeoSkeletonBone(width: 48, height: 36, borderRadius: 8),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: CofradeoSkeletonBone(height: 40, borderRadius: 20),
              ),
              SizedBox(height: 16),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: CofradeoSkeletonBone(height: 160, borderRadius: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Skeleton de listado de temas de un foro.
class ForumTopicsListSkeleton extends StatelessWidget {
  const ForumTopicsListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      sliver: SliverList.separated(
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, _) => const CofradeoSkeletonBone(
          height: 92,
          borderRadius: 14,
        ),
      ),
    );
  }
}

/// Skeleton de la bandeja de notificaciones.
class NotificationsListSkeleton extends StatelessWidget {
  const NotificationsListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: 8,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => const CofradeoSkeletonBone(
        height: 76,
        borderRadius: 14,
      ),
    );
  }
}

/// Lista genérica de filas (personas, siguiendo, actividad…).
class PeopleListSkeleton extends StatelessWidget {
  const PeopleListSkeleton({super.key, this.itemCount = 8});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => const Row(
        children: [
          CofradeoSkeletonBone(width: 44, height: 44, borderRadius: 22),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CofradeoSkeletonBone(width: 140, height: 14, borderRadius: 6),
                SizedBox(height: 8),
                CofradeoSkeletonBone(width: 90, height: 12, borderRadius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grid 2×1 de cards de hermandad (Siguiendo / directorio).
class HermandadCardsSkeleton extends StatelessWidget {
  const HermandadCardsSkeleton({
    super.key,
    this.showChrome = true,
  });

  /// Cabecera + chips falsos (carga de la pestaña Siguiendo).
  final bool showChrome;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showChrome) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: CofradeoSkeletonBone(width: 148, height: 16, borderRadius: 6),
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                CofradeoSkeletonBone(width: 118, height: 28, borderRadius: 14),
                SizedBox(width: 8),
                CofradeoSkeletonBone(width: 64, height: 28, borderRadius: 14),
                SizedBox(width: 8),
                CofradeoSkeletonBone(width: 84, height: 28, borderRadius: 14),
              ],
            ),
            const SizedBox(height: 10),
            const Align(
              alignment: Alignment.centerRight,
              child: CofradeoSkeletonBone(width: 96, height: 14, borderRadius: 6),
            ),
            const SizedBox(height: 10),
          ],
          const Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _HermandadCardBone()),
                SizedBox(width: 8),
                Expanded(child: _HermandadCardBone()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HermandadCardBone extends StatelessWidget {
  const _HermandadCardBone();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CofradeoSkeletonBone(
          height: constraints.maxHeight,
          borderRadius: 14,
        );
      },
    );
  }
}

/// Hub Cuaresma / SS / Glorias.
class HubScreenSkeleton extends StatelessWidget {
  const HubScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
        children: [
          const CofradeoSkeletonBone(height: 160, borderRadius: 18),
          const SizedBox(height: 16),
          const CofradeoSkeletonBone(width: 180, height: 18, borderRadius: 6),
          const SizedBox(height: 12),
          ...List.generate(
            4,
            (_) => const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: CofradeoSkeletonBone(height: 88, borderRadius: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sección dentro de un hub (lista corta).
class HubSectionListSkeleton extends StatelessWidget {
  const HubSectionListSkeleton({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (_) => const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: CofradeoSkeletonBone(height: 72, borderRadius: 12),
        ),
      ),
    );
  }
}

/// Detalle de tema (OP + respuestas) — contenido de body.
class TopicDetailSkeleton extends StatelessWidget {
  const TopicDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        const CofradeoSkeletonBone(height: 120, borderRadius: 14),
        const SizedBox(height: 16),
        const CofradeoSkeletonBone(width: 160, height: 14, borderRadius: 6),
        const SizedBox(height: 12),
        ...List.generate(
          5,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: CofradeoSkeletonBone(height: 84, borderRadius: 12),
          ),
        ),
      ],
    );
  }
}

/// Respuestas del hilo (sliver).
class TopicRepliesSkeleton extends StatelessWidget {
  const TopicRepliesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      sliver: SliverList.separated(
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, _) => const CofradeoSkeletonBone(
          height: 84,
          borderRadius: 12,
        ),
      ),
    );
  }
}

/// Feed en directo / resultados de búsqueda.
class LiveFeedSkeleton extends StatelessWidget {
  const LiveFeedSkeleton({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => const CofradeoSkeletonBone(
        height: 96,
        borderRadius: 14,
      ),
    );
  }
}

/// Preferencias (filas tipo switch).
class PrefsFormSkeleton extends StatelessWidget {
  const PrefsFormSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: 8,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CofradeoSkeletonBone(width: 160, height: 14, borderRadius: 6),
                SizedBox(height: 8),
                CofradeoSkeletonBone(width: 220, height: 12, borderRadius: 6),
              ],
            ),
          ),
          CofradeoSkeletonBone(width: 44, height: 28, borderRadius: 14),
        ],
      ),
    );
  }
}

/// Quiz play / ranking.
class QuizScreenSkeleton extends StatelessWidget {
  const QuizScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const CofradeoSkeletonBone(width: 120, height: 16, borderRadius: 6),
      ),
      body: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: const [
          CofradeoSkeletonBone(height: 40, borderRadius: 10),
          SizedBox(height: 20),
          CofradeoSkeletonBone(height: 120, borderRadius: 16),
          SizedBox(height: 16),
          CofradeoSkeletonBone(height: 56, borderRadius: 12),
          SizedBox(height: 10),
          CofradeoSkeletonBone(height: 56, borderRadius: 12),
          SizedBox(height: 10),
          CofradeoSkeletonBone(height: 56, borderRadius: 12),
          SizedBox(height: 10),
          CofradeoSkeletonBone(height: 56, borderRadius: 12),
        ],
      ),
    );
  }
}
