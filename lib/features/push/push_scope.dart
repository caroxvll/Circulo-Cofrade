import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/messenger/root_messenger.dart';
import '../../core/router/app_router.dart';
import '../auth/auth_provider.dart';
import '../notifications/notification_preferences_provider.dart';
import 'push_provider.dart';

/// Inicializa FCM y sincroniza tokens al iniciar sesión o cambiar preferencias push.
class PushScope extends ConsumerStatefulWidget {
  const PushScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PushScope> createState() => _PushScopeState();
}

class _PushScopeState extends ConsumerState<PushScope> {
  /// Usuario cuya preferencia de avisos ya vimos en esta sesión de la app.
  /// Sirve para no pedir el permiso del sistema al entrar, solo al activar el toggle.
  String? _seenPrefsUserId;

  @override
  void initState() {
    super.initState();
    ref.read(authRepositoryProvider).beforeSignOut = (userId) {
      return ref.read(pushMessagingServiceProvider).detachForSignOut(userId);
    };
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    if (!ref.read(firebaseReadyProvider)) return;

    final push = ref.read(pushMessagingServiceProvider);
    await push.initialize();
    // El permiso push solo se pide al activar el toggle en Avisos.
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(firebaseReadyProvider)) {
      ref.listen(authStateChangesProvider, (previous, next) {
        final prevId = previous?.asData?.value.session?.user?.id;
        final nextId = next.asData?.value.session?.user?.id;
        if (prevId != null && nextId == null) {
          _seenPrefsUserId = null;
        }
      });

      ref.listen(notificationPreferencesProvider, (previous, next) {
        final user = ref.read(currentUserProvider);
        if (user == null) {
          _seenPrefsUserId = null;
          return;
        }
        if (!ref.read(isEmailVerifiedProvider)) return;

        final prevPush = previous?.asData?.value.pushEnabled;
        final nextPush = next.asData?.value.pushEnabled;
        if (nextPush == null) return;

        final push = ref.read(pushMessagingServiceProvider);
        final firstSnapshotForUser = _seenPrefsUserId != user.id;
        _seenPrefsUserId = user.id;

        if (nextPush == false && prevPush == true && !firstSnapshotForUser) {
          push.unregister();
          return;
        }

        if (nextPush != true) return;

        // Al entrar o al abrir la app: si los avisos siguen activos, se registra
        // el token nuevo. No se muestra el diálogo de permiso.
        if (firstSnapshotForUser) {
          push.syncRegistration();
          return;
        }

        // Solo al activar el toggle manualmente en Avisos.
        if (prevPush == false) {
          push.requestPermissionAndRegister().then(_showPushRegistrationFeedback);
        }
      });
    }

    return widget.child;
  }

  void _showPushRegistrationFeedback(bool registered) {
    if (!mounted || registered) return;
    if (!ref.read(isEmailVerifiedProvider)) return;

    final location = ref.read(routerProvider).state.matchedLocation;
    if (location == '/verificar-email' ||
        location == '/login' ||
        location == '/registro' ||
        location == '/bienvenida') {
      return;
    }

    rootScaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text(
          'No se pudo registrar el dispositivo para push. '
          'Desactiva y vuelve a activar Avisos push, o recarga la página.',
        ),
      ),
    );
  }
}
