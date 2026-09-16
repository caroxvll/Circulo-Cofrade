import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../auth/auth_provider.dart';
import '../push/push_provider.dart';
import 'notification_preferences_provider.dart';
import 'notifications_design.dart';

class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(notificationPreferencesProvider);
    final supabaseReady = ref.watch(supabaseReadyProvider);
    final firebaseReady = ref.watch(firebaseConfiguredProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(
                      Icons.chevron_left,
                      color: AppColors.burgundy,
                      size: 30,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'AVISOS',
                      textAlign: TextAlign.center,
                      style: AppTypography.screenAppBarTitle().copyWith(
                        fontSize: 24,
                        letterSpacing: 0.45,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: !supabaseReady
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Conecta Supabase para guardar tus preferencias.',
                          style: AppTypography.bodyMedium(),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : prefsAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, __) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'No se pudieron cargar las preferencias.',
                                style: AppTypography.bodyMedium(),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '¿Ejecutaste notification_social.sql?',
                                style: AppTypography.labelSmall(),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () => ref.invalidate(
                                  notificationPreferencesProvider,
                                ),
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      data: (prefs) => _PushRegistrationOnOpen(
                        pushEnabled: firebaseReady && prefs.pushEnabled,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                          children: [
                            if (firebaseReady) ...[
                              _PrefSection(
                                title: 'Push en el dispositivo',
                                children: [
                                  _PrefRow(
                                    icon: Icons.notifications_active_outlined,
                                    title: 'Avisos push',
                                    subtitle:
                                        'Interruptor general para recibir avisos fuera de la app (requiere permiso del sistema)',
                                    value: prefs.pushEnabled,
                                    onChanged: (v) => _updatePush(
                                      ref,
                                      context,
                                      pushEnabled: v,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                            ],
                            Text(
                              firebaseReady
                                  ? 'Elige de qué quieres enterarte. Aparecen en Notificaciones y, con «Avisos push» activado, también en el móvil.'
                                  : 'Elige de qué quieres avisos en la bandeja de Notificaciones.',
                              style: NotificationsDesign.sectionHint(),
                            ),
                            const SizedBox(height: 18),
                            _PrefSection(
                              title: 'Lo que sigues',
                              children: [
                                _PrefRow(
                                  icon: Icons.tag_outlined,
                                  title: 'Hashtags que sigo',
                                  subtitle:
                                      'Cuando publiquen o comenten con ese hashtag (#ViernesSanto, etc.)',
                                  value: prefs.notifyHashtags,
                                  onChanged: (v) => _update(
                                    ref,
                                    context,
                                    notifyHashtags: v,
                                  ),
                                ),
                                _PrefRow(
                                  icon: Icons.person_outline_rounded,
                                  title: 'Cuentas que sigo',
                                  subtitle: 'Cuando publiquen un tema nuevo',
                                  value: prefs.notifyProfiles,
                                  onChanged: (v) => _update(
                                    ref,
                                    context,
                                    notifyProfiles: v,
                                  ),
                                ),
                                _PrefRow(
                                  icon: Icons.forum_outlined,
                                  title: 'Hilos que sigo',
                                  subtitle:
                                      'Nueva respuesta en un hilo seguido',
                                  value: prefs.notifyTopics,
                                  onChanged: (v) =>
                                      _update(ref, context, notifyTopics: v),
                                ),
                                _PrefRow(
                                  icon: Icons.newspaper_outlined,
                                  title: 'Noticias',
                                  subtitle:
                                      'Si sigues el apartado Noticias, aviso al publicar',
                                  value: prefs.notifyNews,
                                  onChanged: (v) =>
                                      _update(ref, context, notifyNews: v),
                                  showDivider: false,
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _PrefSection(
                              title: 'Mi actividad',
                              children: [
                                _PrefRow(
                                  icon: Icons.alternate_email_rounded,
                                  title: 'Menciones',
                                  subtitle:
                                      'Cuando alguien te etiquete con @handle',
                                  value: prefs.notifyMentions,
                                  onChanged: (v) => _update(
                                    ref,
                                    context,
                                    notifyMentions: v,
                                  ),
                                ),
                                _PrefRow(
                                  icon: Icons.favorite_border_rounded,
                                  title: 'Reacciones',
                                  subtitle:
                                      'Cuando alguien reaccione a tu comentario',
                                  value: prefs.notifyReactions,
                                  onChanged: (v) => _update(
                                    ref,
                                    context,
                                    notifyReactions: v,
                                  ),
                                ),
                                _PrefRow(
                                  icon: Icons.person_add_alt_1_outlined,
                                  title: 'Nuevos seguidores',
                                  subtitle: 'Cuando alguien empiece a seguirte',
                                  value: prefs.notifyFollowers,
                                  onChanged: (v) => _update(
                                    ref,
                                    context,
                                    notifyFollowers: v,
                                  ),
                                  showDivider: false,
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _PrefSection(
                              title: 'Pregunta en vivo',
                              hint:
                                  'Cuando la Junta lance una pregunta sorpresa (15 segundos).',
                              children: [
                                _PrefRow(
                                  icon: Icons.quiz_outlined,
                                  title: 'Avisos de pregunta',
                                  subtitle:
                                      'Te avisamos al instante para que puedas sumar más puntos',
                                  value: prefs.notifyQuiz,
                                  onChanged: (v) => _update(
                                    ref,
                                    context,
                                    notifyQuiz: v,
                                  ),
                                  showDivider: false,
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _PrefSection(
                              title: 'Calendario',
                              hint:
                                  'Novedades y recordatorios de procesiones, ensayos y eventos cofrades.',
                              children: [
                                _PrefRow(
                                  icon: Icons.event_available_outlined,
                                  title: 'Avisos importantes',
                                  subtitle:
                                      'Eventos nuevos al publicarse y recordatorios 24 h y 1 h antes',
                                  value: prefs.notifyCalendar,
                                  onChanged: (v) => _update(
                                    ref,
                                    context,
                                    notifyCalendar: v,
                                  ),
                                  showDivider: false,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              firebaseReady
                                  ? 'Los avisos del calendario aparecen aquí y en Notificaciones. Con «Avisos push» activado, también te llegan al móvil.'
                                  : 'Los avisos del calendario aparecen en la bandeja de Notificaciones de la app.',
                              style: NotificationsDesign.sectionHint().copyWith(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updatePush(
    WidgetRef ref,
    BuildContext context, {
    required bool pushEnabled,
  }) async {
    try {
      await ref.read(notificationPreferencesProvider.notifier).updatePref(
            pushEnabled: pushEnabled,
          );
      if (pushEnabled || !context.mounted) return;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar la preferencia')),
        );
      }
    }
  }

  Future<void> _update(
    WidgetRef ref,
    BuildContext context, {
    bool? notifyHashtags,
    bool? notifyProfiles,
    bool? notifyTopics,
    bool? notifyMentions,
    bool? notifyFollowers,
    bool? notifyReactions,
    bool? notifyCalendar,
    bool? notifyQuiz,
    bool? notifyNews,
  }) async {
    try {
      await ref.read(notificationPreferencesProvider.notifier).updatePref(
            notifyHashtags: notifyHashtags,
            notifyProfiles: notifyProfiles,
            notifyTopics: notifyTopics,
            notifyMentions: notifyMentions,
            notifyFollowers: notifyFollowers,
            notifyReactions: notifyReactions,
            notifyCalendar: notifyCalendar,
            notifyQuiz: notifyQuiz,
            notifyNews: notifyNews,
          );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar la preferencia')),
        );
      }
    }
  }
}

/// Al abrir Avisos con push activo, intenta registrar el token (p. ej. permiso ya concedido).
class _PushRegistrationOnOpen extends ConsumerStatefulWidget {
  const _PushRegistrationOnOpen({
    required this.pushEnabled,
    required this.child,
  });

  final bool pushEnabled;
  final Widget child;

  @override
  ConsumerState<_PushRegistrationOnOpen> createState() =>
      _PushRegistrationOnOpenState();
}

class _PushRegistrationOnOpenState extends ConsumerState<_PushRegistrationOnOpen> {
  @override
  void initState() {
    super.initState();
    if (widget.pushEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(pushMessagingServiceProvider).syncRegistration();
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _PrefSection extends StatelessWidget {
  const _PrefSection({
    required this.title,
    required this.children,
    this.hint,
  });

  final String title;
  final String? hint;
  final List<_PrefRow> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: NotificationsDesign.sectionTitle()),
        if (hint != null) ...[
          const SizedBox(height: 6),
          Text(hint!, style: NotificationsDesign.sectionHint()),
        ],
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: NotificationsDesign.settingsCardDecoration(),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _PrefRow extends StatelessWidget {
  const _PrefRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: AppColors.burgundy),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: NotificationsDesign.prefTitle()),
                    const SizedBox(height: 3),
                    Text(subtitle, style: NotificationsDesign.prefSubtitle()),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Transform.scale(
                scale: 0.86,
                child: Switch(
                  value: value,
                  onChanged: onChanged,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  activeTrackColor: AppColors.burgundy,
                  activeThumbColor: AppColors.surface,
                  inactiveThumbColor: AppColors.textPrimary,
                  inactiveTrackColor: AppColors.surface,
                  trackOutlineColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppColors.burgundy;
                    }
                    return AppColors.textPrimary.withValues(alpha: 0.35);
                  }),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 62),
            child: Divider(
              height: 1,
              thickness: 1,
              color: AppColors.border.withValues(alpha: 0.75),
            ),
          ),
      ],
    );
  }
}
