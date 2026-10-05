import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../forums/forums_provider.dart';
import '../../forums/utils/hermandad_board_display.dart';
import '../models/ss_live_update.dart';
import '../semana_santa_provider.dart';

class SsDayHermandadOption {
  const SsDayHermandadOption({
    required this.name,
    this.topicId,
    this.iconImageUrl,
    this.processionDay,
  });

  final String name;
  final String? topicId;
  final String? iconImageUrl;
  final String? processionDay;
}

/// Hermandades del foro que salen en la jornada activa (o todas si no hay día).
final ssDayHermandadesProvider =
    Provider.autoDispose<AsyncValue<List<SsDayHermandadOption>>>((ref) {
  final gate = ref.watch(ssLiveGateProvider);
  final topicsAsync = ref.watch(forumTopicsProvider('hermandades'));

  return topicsAsync.when(
    loading: () => const AsyncValue.loading(),
    error: AsyncValue.error,
    data: (topics) {
      final dayLabel = gate.asData?.value.activeDay?.label.trim();
      final options = <SsDayHermandadOption>[];
      for (final topic in topics) {
        if (topic.isSystem) continue;
        final parsed = parseHermandadTopicTitle(topic.title);
        final name = parsed.hermandadName.trim();
        if (name.isEmpty) continue;
        if (dayLabel != null &&
            dayLabel.isNotEmpty &&
            parsed.processionDay != null &&
            parsed.processionDay != dayLabel) {
          continue;
        }
        options.add(
          SsDayHermandadOption(
            name: name,
            topicId: topic.id,
            iconImageUrl: topic.iconImageUrl,
            processionDay: parsed.processionDay,
          ),
        );
      }
      options.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return AsyncValue.data(options);
    },
  );
});

String ssInformarKindDescription(SsLiveUpdateKind kind) => switch (kind) {
      SsLiveUpdateKind.retraso =>
        'La hermandad va con retraso en su recorrido',
      SsLiveUpdateKind.posicion =>
        'Información sobre su paso, ubicación o cambio de itinerario',
      SsLiveUpdateKind.incidente =>
        'Alguna incidencia en el cortejo o en el recorrido',
      SsLiveUpdateKind.curiosidad =>
        'Información de interés o detalle relevante',
      SsLiveUpdateKind.general => 'Cualquier otra información',
    };
