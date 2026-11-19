import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Avisa justo al cambiar el minuto, para que «Empieza en X min» baje solo.
final minuteClockProvider = StreamProvider<DateTime>((ref) {
  ref.keepAlive();
  final controller = StreamController<DateTime>();
  Timer? timer;

  void emit() {
    if (!controller.isClosed) controller.add(DateTime.now());
  }

  emit();
  final now = DateTime.now();
  final waitMs =
      ((60 - now.second) * 1000 - now.millisecond).clamp(250, 60000);
  timer = Timer(Duration(milliseconds: waitMs), () {
    emit();
    timer = Timer.periodic(const Duration(minutes: 1), (_) => emit());
  });

  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Instante del último minuto, o ahora si el reloj aún no ha emitido.
DateTime watchMinuteClock(WidgetRef ref) {
  return ref.watch(minuteClockProvider).asData?.value ?? DateTime.now();
}
