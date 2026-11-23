import 'dart:async';
import 'package:flutter/material.dart';
import '../page_flip.dart';

class PageFlipWidget extends StatefulWidget {
  final PageFlipController? controller;
  const PageFlipWidget({
    Key? key,
    this.duration = const Duration(milliseconds: 450),
    this.cutoffForward = 0.8,
    this.cutoffPrevious = 0.1,
    this.backgroundColor = Colors.white,
    required this.children,
    this.initialIndex = 0,
    this.lastPage,
    this.isRightSwipe = false,
    this.onPageFlipped,
    this.onFlipStart,
    this.controller,
  })  : assert(initialIndex < children.length,
            'initialIndex cannot be greater than children length'),
        super(key: key);

  final Color backgroundColor;
  final List<Widget> children;
  final Duration duration;
  final int initialIndex;
  final Widget? lastPage;
  final double cutoffForward;
  final double cutoffPrevious;
  final bool isRightSwipe;
  final void Function(int pageNumber)? onPageFlipped;
  final void Function()? onFlipStart;

  @override
  PageFlipWidgetState createState() => PageFlipWidgetState();
}

class PageFlipWidgetState extends State<PageFlipWidget>
    with TickerProviderStateMixin {
  int pageNumber = 0;
  List<Widget> pages = [];
  final List<AnimationController> _controllers = [];
  bool? _isForward;
  var _busy = false;

  @override
  void didUpdateWidget(PageFlipWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    imageData = {};
    currentPage.value = -1;
    currentWidget.value = Container();
    currentPageIndex.value = 0;
    widget.controller?._state = this;
    _setUp();
  }

  void _setUp({bool isRefresh = false}) {
    for (final c in _controllers) {
      c.dispose();
    }
    _controllers.clear();
    pages.clear();
    final items = List<Widget>.from(widget.children);
    if (widget.lastPage != null) {
      items.add(widget.lastPage!);
    }
    final lastIndex = items.isEmpty ? 0 : items.length - 1;
    pageNumber = isRefresh
        ? pageNumber.clamp(0, lastIndex)
        : widget.initialIndex.clamp(0, lastIndex);
    for (var i = 0; i < items.length; i++) {
      final controller = AnimationController(
        value: i < pageNumber ? 0 : 1,
        duration: widget.duration,
        vsync: this,
      );
      _controllers.add(controller);
      final child = PageFlipBuilder(
        amount: controller,
        backgroundColor: widget.backgroundColor,
        isRightSwipe: widget.isRightSwipe,
        pageIndex: i,
        key: Key('item$i'),
        child: items[i],
      );
      pages.add(child);
    }
    pages = pages.reversed.toList();
    currentPage.value = -1;
    currentPageIndex.value = pageNumber;
    if (pages.isNotEmpty) {
      currentWidget.value = pages[pageNumber.clamp(0, pages.length - 1)];
    }
  }

  bool get _isLastPage => (pages.length - 1) == pageNumber;
  bool get _isFirstPage => pageNumber == 0;

  void _turnPage(DragUpdateDetails details, BoxConstraints dimens) {
    if (_busy || dimens.maxWidth <= 0) return;
    final ratio = details.delta.dx / dimens.maxWidth;
    if (_isForward == null) {
      if (widget.isRightSwipe
          ? details.delta.dx < 0.0
          : details.delta.dx > 0.0) {
        _isForward = false;
      } else if (widget.isRightSwipe
          ? details.delta.dx > 0.2
          : details.delta.dx < -0.2) {
        _isForward = true;
      } else {
        _isForward = null;
      }
    }
    if (_isForward == true && !_isLastPage) {
      currentPage.value = pageNumber;
      widget.isRightSwipe
          ? _controllers[pageNumber].value -= ratio
          : _controllers[pageNumber].value += ratio;
    } else if (_isForward == false && !_isFirstPage) {
      currentPage.value = pageNumber - 1;
      widget.isRightSwipe
          ? _controllers[pageNumber - 1].value -= ratio
          : _controllers[pageNumber - 1].value += ratio;
    }
  }

  Future<void> _onDragFinish() async {
    if (_busy) {
      _isForward = null;
      return;
    }
    if (_isForward == true) {
      if (!_isLastPage &&
          _controllers[pageNumber].value <= (widget.cutoffForward + 0.15)) {
        await nextPage();
      } else if (!_isLastPage) {
        await _controllers[pageNumber].forward();
      }
    } else if (_isForward == false) {
      if (_isFirstPage) {
        await _controllers[pageNumber].forward();
      } else if (_controllers[pageNumber - 1].value >= widget.cutoffPrevious) {
        await previousPage();
      } else {
        await _controllers[pageNumber - 1].reverse();
      }
    }
    _isForward = null;
    currentPage.value = -1;
  }

  Future<void> nextPage() async {
    if (_busy || _isLastPage) return;
    _busy = true;
    widget.onFlipStart?.call();
    currentPage.value = pageNumber;
    try {
      await _controllers[pageNumber].reverse();
      if (!mounted) return;
      setState(() {
        pageNumber++;
      });
      currentPageIndex.value = pageNumber;
      widget.onPageFlipped?.call(pageNumber);
    } finally {
      _busy = false;
      currentPage.value = -1;
    }
  }

  Future<void> previousPage() async {
    if (_busy || _isFirstPage) return;
    _busy = true;
    widget.onFlipStart?.call();
    currentPage.value = pageNumber - 1;
    try {
      await _controllers[pageNumber - 1].forward();
      if (!mounted) return;
      setState(() {
        pageNumber--;
      });
      currentPageIndex.value = pageNumber;
      imageData[pageNumber] = null;
      widget.onPageFlipped?.call(pageNumber);
    } finally {
      _busy = false;
      currentPage.value = -1;
    }
  }

  Future<void> goToPage(int index) async {
    final lastIndex = pages.isEmpty ? 0 : pages.length - 1;
    final target = index.clamp(0, lastIndex);
    if (mounted) {
      setState(() {
        pageNumber = target;
      });
    } else {
      pageNumber = target;
    }
    for (var i = 0; i < _controllers.length; i++) {
      _controllers[i].value = i < target ? 0 : 1;
    }
    currentPageIndex.value = pageNumber;
    currentPage.value = -1;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, dimens) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {},
        onTapUp: (details) {},
        onPanDown: (details) {},
        onPanEnd: (details) {},
        onTapCancel: () {},
        onHorizontalDragCancel: () => _isForward = null,
        onHorizontalDragUpdate: (details) => _turnPage(details, dimens),
        onHorizontalDragEnd: (details) => _onDragFinish(),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (widget.lastPage != null) ...[
              widget.lastPage!,
            ],
            if (pages.isNotEmpty) ...pages else const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

class PageFlipController {
  PageFlipWidgetState? _state;

  void nextPage() {
    _state?.nextPage();
  }

  void previousPage() {
    _state?.previousPage();
  }

  void goToPage(int index) {
    _state?.goToPage(index);
  }
}
