import 'package:flutter/material.dart';

/// Tag estable para el vuelo del escudo tarjeta → header del tablón.
String hermandadCrestHeroTag(String topicId) => 'hermandad-crest-$topicId';

/// Shared element del escudo entre listas y [HermandadBoardHeader].
class HermandadCrestHero extends StatelessWidget {
  const HermandadCrestHero({
    super.key,
    required this.topicId,
    required this.child,
    this.enabled = true,
  });

  final String topicId;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final id = topicId.trim();
    if (!enabled || id.isEmpty) return child;
    return Hero(
      tag: hermandadCrestHeroTag(id),
      createRectTween: (begin, end) =>
          MaterialRectArcTween(begin: begin, end: end),
      child: Material(
        type: MaterialType.transparency,
        child: child,
      ),
    );
  }
}
