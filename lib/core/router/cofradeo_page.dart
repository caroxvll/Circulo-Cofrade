import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

/// Empuje de pantallas con el gesto de volver desde el borde izquierdo.
/// La pantalla sigue el dedo, como en el sistema.
Page<void> cofradeoFadePage({
  required GoRouterState state,
  required Widget child,
}) {
  return CupertinoPage<void>(
    key: state.pageKey,
    name: state.name,
    child: child,
  );
}

/// Auth (splash / bienvenida / login / registro): fade + leve subida.
/// Evita el slide Cupertino arrastrando el mismo fondo entre pantallas.
Page<void> cofradeoAuthPage({
  required GoRouterState state,
  required Widget child,
}) {
  final isWeb = kIsWeb;
  return CustomTransitionPage<void>(
    key: state.pageKey,
    name: state.name,
    child: CofradeoEdgeBack(child: child),
    transitionDuration: Duration(milliseconds: isWeb ? 160 : 340),
    reverseTransitionDuration: Duration(milliseconds: isWeb ? 120 : 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.028),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Tabs del shell: sin animación (IndexedStack ya mantiene el estado).
Page<void> cofradeoTabPage({
  required GoRouterState state,
  required Widget child,
}) {
  return NoTransitionPage<void>(
    key: state.pageKey,
    name: state.name,
    child: child,
  );
}

/// Vuelta atrás arrastrando desde el borde izquierdo.
/// En iOS y Android lo hace la propia ruta Cupertino; aquí cubre la web
/// y las pantallas de acceso, que no usan ese deslizamiento.
class CofradeoEdgeBack extends StatelessWidget {
  const CofradeoEdgeBack({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        const Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 28,
          child: _EdgeBackZone(),
        ),
      ],
    );
  }
}

class _EdgeBackZone extends StatefulWidget {
  const _EdgeBackZone();

  @override
  State<_EdgeBackZone> createState() => _EdgeBackZoneState();
}

class _EdgeBackZoneState extends State<_EdgeBackZone> {
  double _dx = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => _dx = 0,
      onHorizontalDragUpdate: (details) => _dx += details.delta.dx,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        final goBack = _dx > 72 || velocity > 700;
        _dx = 0;
        if (!goBack) return;
        final navigator = Navigator.of(context);
        if (navigator.canPop()) navigator.maybePop();
      },
    );
  }
}
