import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// Tope de clip en el reto (anti-trampas / tamaño).
const quizMaxAudioSeconds = 20;

/// Duración del audio en memoria; null si no se puede medir.
Future<Duration?> probeQuizAudioDuration(Uint8List bytes) async {
  final player = AudioPlayer();
  try {
    await player.setSource(BytesSource(bytes));
    // Algunos backends necesitan un instante para reportar duración.
    for (var i = 0; i < 8; i++) {
      final d = await player.getDuration();
      if (d != null && d.inMilliseconds > 0) return d;
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    return await player.getDuration();
  } catch (_) {
    return null;
  } finally {
    await player.dispose();
  }
}

bool isQuizAudioTooLong(Duration? duration) {
  if (duration == null) return false;
  return duration.inMilliseconds > quizMaxAudioSeconds * 1000;
}
