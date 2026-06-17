import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../auth/auth_provider.dart';
import '../push/push_provider.dart';
import 'notification_preferences_provider.dart';

class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(notificationPreferencesProvider);
    final supabaseReady = ref.watch(supabaseReadyProvider);
    final firebaseReady = ref.watch(firebaseConfiguredProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.chevron_left, color: AppColors.burgundy),
        ),
        title: Text(
          'Avisos',
          style: AppTypography.displaySmall().copyWith(fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: !supabaseReady
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
              loading: () => const Center(child: CircularProgressIndicator()),
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
                        onPressed: () =>
                            ref.invalidate(notificationPreferencesProvider),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (prefs) => _PushRegistrationOnOpen(
                pushEnabled: firebaseReady && prefs.pushEnabled,
                child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  if (firebaseReady) ...[
                    Text(
                      'Push en el dispositivo',
                      style: AppTypography.titleLarge().copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    _PrefSwitch(
                      title: 'Avisos push',
                      subtitle:
                          'Interruptor general para recibir avisos fuera de la app (requiere permiso del sistema)',
                      value: prefs.pushEnabled,
                      onChanged: (v) =>
                          _updatePush(ref, context, pushEnabled: v),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Text(
                    'Tipos de aviso',
                    style: AppTypography.titleLarge().copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    firebaseReady
                        ? 'Elige de qué quieres enterarte. Aparecen en Notificaciones y, con «Avisos push» activado, también en el móvil.'
                        : 'Elige de qué quieres avisos en la bandeja de Notificaciones.',
                    style: AppTypography.bodyMedium(),
                  ),
                  const SizedBox(height: 20),
                  _PrefSwitch(
                    title: 'Hashtags que sigo',
                    subtitle:
                        'Cuando publiquen o comenten con ese hashtag (#ViernesSanto, etc.)',
                    value: prefs.notifyHashtags,
                    onChanged: (v) => _update(ref, context, notifyHashtags: v),
                  ),
                  _PrefSwitch(
                    title: 'Cuentas que sigo',
                    subtitle: 'Cuando publiquen un tema nuevo',
                    value: prefs.notifyProfiles,
                    onChanged: (v) => _update(ref, context, notifyProfiles: v),
                  ),
                  _PrefSwitch(
                    title: 'Hilos que sigo',
                    subtitle: 'Nueva respuesta en un hilo seguido',
                    value: prefs.notifyTopics,
                    onChanged: (v) => _update(ref, context, notifyTopics: v),
                  ),
                  _PrefSwitch(
                    title: 'Menciones',
                    subtitle: 'Cuando alguien te etiquete con @handle',
                    value: prefs.notifyMentions,
                    onChanged: (v) => _update(ref, context, notifyMentions: v),
                  ),
                  _PrefSwitch(
                    title: 'Nuevos seguidores',
                    subtitle: 'Cuando alguien empiece a seguirte',
                    value: prefs.notifyFollowers,
                    onChanged: (v) => _update(ref, context, notifyFollowers: v),
                  ),
                ],
              ),
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
      // Al desactivar, PushScope ya elimina el token vía listener.
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
  }) async {
    try {
      await ref.read(notificationPreferencesProvider.notifier).updatePref(
            notifyHashtags: notifyHashtags,
            notifyProfiles: notifyProfiles,
            notifyTopics: notifyTopics,
            notifyMentions: notifyMentions,
            notifyFollowers: notifyFollowers,
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

class _PrefSwitch extends StatelessWidget {
  const _PrefSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: AppTypography.titleLarge().copyWith(fontSize: 15),
        ),
        subtitle: Text(subtitle, style: AppTypography.bodyMedium()),
        value: value,
        activeThumbColor: AppColors.burgundy,
        onChanged: onChanged,
      ),
    );
  }
}
