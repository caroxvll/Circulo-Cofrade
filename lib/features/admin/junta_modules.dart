import 'package:flutter/material.dart';

enum JuntaNavSection { moderation, community, platform }

enum JuntaModule {
  overview,
  topics,
  rejectedTopics,
  reports,
  events,
  closeRequests,
  moderators,
  hermandades,
  forums,
  season,
  ads,
  quiz,
}

extension JuntaModuleMeta on JuntaModule {
  String get label => switch (this) {
    JuntaModule.overview => 'Resumen',
    JuntaModule.topics => 'Temas pendientes',
    JuntaModule.rejectedTopics => 'Historial de rechazos',
    JuntaModule.reports => 'Reportes',
    JuntaModule.events => 'Eventos',
    JuntaModule.closeRequests => 'Cierres solicitados',
    JuntaModule.moderators => 'Moderadores',
    JuntaModule.hermandades => 'Hermandades',
    JuntaModule.forums => 'Foros y apariencia',
    JuntaModule.season => 'Temporada',
    JuntaModule.ads => 'Patrocinios',
    JuntaModule.quiz => 'Pregunta en vivo',
  };

  String? get shortLabel => switch (this) {
    JuntaModule.overview => null,
    JuntaModule.topics => 'Temas',
    JuntaModule.rejectedTopics => 'Rechazos',
    JuntaModule.reports => 'Reportes',
    JuntaModule.events => 'Eventos',
    JuntaModule.closeRequests => 'Cierres',
    JuntaModule.moderators => 'Moderadores',
    JuntaModule.hermandades => 'Hermandades',
    JuntaModule.forums => 'Foros',
    JuntaModule.season => 'Temporada',
    JuntaModule.ads => 'Patrocinios',
    JuntaModule.quiz => 'Quiz',
  };

  IconData get icon => switch (this) {
    JuntaModule.overview => Icons.dashboard_outlined,
    JuntaModule.topics => Icons.rate_review_outlined,
    JuntaModule.rejectedTopics => Icons.history_outlined,
    JuntaModule.reports => Icons.flag_outlined,
    JuntaModule.events => Icons.event_outlined,
    JuntaModule.closeRequests => Icons.lock_clock_outlined,
    JuntaModule.moderators => Icons.admin_panel_settings_outlined,
    JuntaModule.hermandades => Icons.church_outlined,
    JuntaModule.forums => Icons.forum_outlined,
    JuntaModule.season => Icons.calendar_month_outlined,
    JuntaModule.ads => Icons.campaign_outlined,
    JuntaModule.quiz => Icons.quiz_outlined,
  };

  JuntaNavSection? get section => switch (this) {
    JuntaModule.overview => null,
    JuntaModule.topics ||
    JuntaModule.rejectedTopics ||
    JuntaModule.reports ||
    JuntaModule.events ||
    JuntaModule.closeRequests =>
      JuntaNavSection.moderation,
    JuntaModule.moderators ||
    JuntaModule.hermandades ||
    JuntaModule.forums =>
      JuntaNavSection.community,
    JuntaModule.season || JuntaModule.ads || JuntaModule.quiz =>
      JuntaNavSection.platform,
  };

  bool get adminOnly => switch (this) {
    JuntaModule.events ||
    JuntaModule.moderators ||
    JuntaModule.hermandades ||
    JuntaModule.forums ||
    JuntaModule.season ||
    JuntaModule.ads =>
      true,
    // Moderadores proponen; admin aprueba/lanza dentro del panel.
    JuntaModule.quiz => false,
    _ => false,
  };
}

extension JuntaNavSectionMeta on JuntaNavSection {
  String get title => switch (this) {
    JuntaNavSection.moderation => 'Moderación',
    JuntaNavSection.community => 'Comunidad',
    JuntaNavSection.platform => 'Plataforma',
  };
}

List<JuntaModule> visibleJuntaModules({
  required bool isAdmin,
  bool canCreateQuiz = false,
}) {
  return JuntaModule.values.where((module) {
    if (module == JuntaModule.overview) return true;
    if (module == JuntaModule.quiz) return isAdmin || canCreateQuiz;
    if (module.adminOnly && !isAdmin) return false;
    return true;
  }).toList();
}

List<JuntaModule> modulesInSection(
  JuntaNavSection section, {
  required bool isAdmin,
  bool canCreateQuiz = false,
}) {
  return visibleJuntaModules(
    isAdmin: isAdmin,
    canCreateQuiz: canCreateQuiz,
  ).where((m) => m.section == section).toList();
}
