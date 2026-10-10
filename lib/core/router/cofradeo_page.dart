import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Empuje de pantallas con sensación nativa.
/// - iOS / Android: slide Cupertino (como apps del sistema).
/// - Web: fade muy corto (el slide en canvas web suele sentirse peor).
Page<void> cofradeoFadePage({
  required GoRouterState state,
  required Widget child,
}) {
  if (kIsWeb) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      name: state.name,
      child: child,
      transitionDuration: const Duration(milliseconds: 90),
      reverseTransitionDuration: const Duration(milliseconds: 80),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
            reverseCurve: Curves.easeIn,
          ),
          child: child,
        );
      },
    );
  }

  return CustomTransitionPage<void>(
    key: state.pageKey,
    name: state.name,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return CupertinoPageTransition(
        primaryRouteAnimation: animation,
        secondaryRouteAnimation: secondaryAnimation,
        linearTransition: false,
        child: child,
      );
    },
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
    child: child,
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
