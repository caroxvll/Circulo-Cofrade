import 'package:flutter/material.dart';

import '../../../shared/models/forum.dart';
import '../data/forum_pillar_icons.dart';

/// Alias de compatibilidad: el icono del foro es siempre un asset fijo.
class ForumPillarIconMark extends StatelessWidget {
  const ForumPillarIconMark({
    super.key,
    required this.forum,
    this.size = 54,
    this.locked = false,
    this.borderRadius,
  });

  final ForumCategory forum;
  final double size;
  final bool locked;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return ForumPillarIconImage(
      forum: forum,
      size: size,
      locked: locked,
      borderRadius: borderRadius,
    );
  }
}
