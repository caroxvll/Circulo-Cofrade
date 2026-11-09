import 'dart:async';

import 'package:flutter/services.dart';

/// Mientras una pregunta está abierta: bloquea la captura en Android
/// y avisa en iOS si hacen una captura.
class ScreenGuard {
  ScreenGuard._();

  static final instance = ScreenGuard._();
  static const _channel = MethodChannel('cofradeo/screen_guard');

  final _shots = StreamController<void>.broadcast();
  var _listening = false;

  Stream<void> get screenshots => _shots.stream;

  void ensureListening() {
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'screenshot') {
        _shots.add(null);
      }
    });
  }

  Future<void> protect() async {
    ensureListening();
    try {
      await _channel.invokeMethod<void>('protect');
    } catch (_) {}
  }

  Future<void> unprotect() async {
    try {
      await _channel.invokeMethod<void>('unprotect');
    } catch (_) {}
  }
}
