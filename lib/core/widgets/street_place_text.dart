import 'package:flutter/material.dart';

import '../utils/street_from_coordinates.dart';
import '../utils/street_label.dart';

/// Muestra la calle cuando el aviso solo guardó «Mi ubicación» y hay GPS.
class StreetPlaceText extends StatefulWidget {
  const StreetPlaceText({
    super.key,
    required this.placeLabel,
    required this.style,
    this.latitude,
    this.longitude,
    this.fallback = '',
    this.maxLines = 1,
  });

  final String? placeLabel;
  final double? latitude;
  final double? longitude;
  final String fallback;
  final TextStyle style;
  final int maxLines;

  @override
  State<StreetPlaceText> createState() => _StreetPlaceTextState();
}

class _StreetPlaceTextState extends State<StreetPlaceText> {
  String? _street;
  int _token = 0;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant StreetPlaceText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placeLabel != widget.placeLabel ||
        oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      _street = null;
      _resolve();
    }
  }

  void _resolve() {
    if (!isGenericPlaceLabel(widget.placeLabel)) {
      if (_street != null) setState(() => _street = null);
      return;
    }
    final latitude = widget.latitude;
    final longitude = widget.longitude;
    if (latitude == null || longitude == null) return;
    final token = ++_token;
    streetNameForCoordinates(latitude, longitude).then((value) {
      if (!mounted || token != _token || value == null || value == _street) {
        return;
      }
      setState(() => _street = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final stored = widget.placeLabel?.trim() ?? '';
    final text = _street ?? (stored.isEmpty ? widget.fallback : stored);
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(
      text,
      maxLines: widget.maxLines,
      overflow: TextOverflow.ellipsis,
      style: widget.style,
    );
  }
}
