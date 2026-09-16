/// Ajustes opcionales de la cuenta atrás (Supabase).
/// Si no hay fila para el año, la app usa cálculo automático.
class LiturgicalCountdownSettings {
  const LiturgicalCountdownSettings({
    required this.year,
    this.palmSundayOverride,
    this.easterSundayOverride,
    this.visibleDaysBefore = 60,
    this.isEnabled = true,
    this.usesManualDates = false,
  });

  final int year;
  final DateTime? palmSundayOverride;
  final DateTime? easterSundayOverride;
  final int visibleDaysBefore;
  final bool isEnabled;

  /// True si al menos una fecha viene de la Junta (no del algoritmo).
  final bool usesManualDates;

  static LiturgicalCountdownSettings automatic(int year) {
    return LiturgicalCountdownSettings(year: year);
  }

  LiturgicalCountdownSettings copyWith({
    int? year,
    DateTime? palmSundayOverride,
    DateTime? easterSundayOverride,
    bool clearPalmOverride = false,
    bool clearEasterOverride = false,
    int? visibleDaysBefore,
    bool? isEnabled,
    bool? usesManualDates,
  }) {
    return LiturgicalCountdownSettings(
      year: year ?? this.year,
      palmSundayOverride:
          clearPalmOverride ? null : (palmSundayOverride ?? this.palmSundayOverride),
      easterSundayOverride: clearEasterOverride
          ? null
          : (easterSundayOverride ?? this.easterSundayOverride),
      visibleDaysBefore: visibleDaysBefore ?? this.visibleDaysBefore,
      isEnabled: isEnabled ?? this.isEnabled,
      usesManualDates: usesManualDates ?? this.usesManualDates,
    );
  }
}
