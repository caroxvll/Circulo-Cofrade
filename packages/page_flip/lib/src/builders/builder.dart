import 'dart:ui' as ui;

import 'package:flutter/material.dart';

Map<int, ui.Image?> imageData = {};
ValueNotifier<int> currentPage = ValueNotifier(-1);
ValueNotifier<Widget> currentWidget = ValueNotifier(Container());
ValueNotifier<int> currentPageIndex = ValueNotifier(0);

class PageFlipBuilder extends StatefulWidget {
  const PageFlipBuilder({
    Key? key,
    required this.amount,
    this.backgroundColor,
    required this.child,
    required this.pageIndex,
    required this.isRightSwipe,
  }) : super(key: key);

  final Animation<double> amount;
  final int pageIndex;
  final Color? backgroundColor;
  final Widget child;
  final bool isRightSwipe;

  @override
  State<PageFlipBuilder> createState() => PageFlipBuilderState();
}

class PageFlipBuilderState extends State<PageFlipBuilder> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: currentPageIndex,
      builder: (context, index, child) {
        // La hoja viva se queda en pantalla. La captura del rizo sustituía
        // el texto por un bitmap y, si fallaba, la página quedaba en blanco.
        if (widget.pageIndex == index) {
          return ColoredBox(
            color: widget.backgroundColor ?? Colors.black12,
            child: widget.child,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
