import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/messenger/root_messenger.dart';
import '../../core/config/firebase_config.dart';
import '../../core/firebase/firebase_bootstrap.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/forum_topic_query.dart';
import '../../features/forums/utils/forum_navigation.dart';
import '../../features/forums/utils/official_post_categories.dart';
import '../../firebase_background.dart';
import '../auth/auth_provider.dart';
import '../calendar/calendar_provider.dart';
import '../calendar/utils/calendar_notification_navigation.dart';
import '../notifications/notifications_provider.dart';
import 'data/device_tokens_repository.dart';

String pushPlatformLabel() {
  if (kIsWeb) return 'web';
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return 'ios';
    default:
      return 'android';
  }
}

class PushMessagingService {
  PushMessagingService(this._ref);

  final Ref _ref;
  String? _currentToken;
  String? _lastRegisteredUserId;
  bool _initialized = false;

  bool get isAvailable =>
      FirebaseConfig.isConfigured && FirebaseBootstrap.isInitialized;

  Future<void> initialize() async {
    if (!isAvailable || _initialized) return;
    _initialized = true;

    final messaging = FirebaseMessaging.instance;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);

    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      _onMessageOpened(initial);
    }

    messaging.onTokenRefresh.listen(_registerToken);
  }

  Future<bool> hasPermission() async {
    if (!isAvailable) return false;

    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<bool> requestPermission() async {
    if (!isAvailable) return false;

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<bool> requestPermissionAndRegister() async {
    final granted = await requestPermission();
    if (!granted) return false;
    return syncRegistration();
  }

  /// Registra el token en Supabase si hay sesión y permiso concedido.
  Future<bool> syncRegistration() async {
    if (!isAvailable) return false;

    final user = _ref.read(currentUserProvider);
    if (user == null) return false;

    if (!await hasPermission()) return false;

    final token = await _getToken();
    if (token == null) return false;

    try {
      await _registerToken(token);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Quita el token de Supabase. La sesión tiene que seguir abierta.
  /// No invalida el token en Firebase: al volver a activar avisos se reutiliza.
  Future<void> unregister() async {
    final sessionUserId = _ref.read(currentUserProvider)?.id;
    final userId = sessionUserId ?? _lastRegisteredUserId;
    var token = _currentToken;
    // Sin sesión no pedimos un token nuevo: getToken() lo crearía.
    if (token == null && sessionUserId != null && isAvailable) {
      token = await _getToken();
    }
    if (token != null && userId != null) {
      try {
        await createDeviceTokensRepository().delete(
          userId: userId,
          fcmToken: token,
        );
      } catch (error, stack) {
        debugPrint('No se pudo borrar el token del dispositivo: $error\n$stack');
      }
    }
    _currentToken = null;
    _lastRegisteredUserId = null;
  }

  /// Cierra el canal push de este móvil antes de cerrar sesión.
  /// Primero borra la fila (el JWT sigue válido) y después invalida el token.
  Future<void> detachForSignOut(String? userId) async {
    final resolvedUserId =
        userId ?? _ref.read(currentUserProvider)?.id ?? _lastRegisteredUserId;
    final knownToken = _currentToken;
    Future<String?>? pendingToken;
    String? fetchedToken;
    if (knownToken == null && isAvailable) {
      pendingToken = _getToken();
      try {
        fetchedToken = await pendingToken.timeout(const Duration(seconds: 6));
      } catch (_) {
        fetchedToken = null;
      }
    }

    final token = knownToken ?? fetchedToken;
    if (token != null && resolvedUserId != null) {
      try {
        await createDeviceTokensRepository()
            .delete(
              userId: resolvedUserId,
              fcmToken: token,
            )
            .timeout(const Duration(seconds: 5));
      } catch (error, stack) {
        debugPrint('No se pudo borrar el token al salir: $error\n$stack');
      }
    }

    await _deleteLocalFcmToken();
    if (pendingToken != null) {
      // getToken puede terminar después del primer deleteToken y dejar uno nuevo.
      try {
        await pendingToken.timeout(const Duration(seconds: 2));
      } catch (_) {}
      await _deleteLocalFcmToken();
    }

    _currentToken = null;
    _lastRegisteredUserId = null;
  }

  Future<void> _deleteLocalFcmToken() async {
    if (!isAvailable) return;
    try {
      await FirebaseMessaging.instance
          .deleteToken()
          .timeout(const Duration(seconds: 5));
    } catch (error, stack) {
      debugPrint('No se pudo invalidar el token FCM: $error\n$stack');
    }
  }

  Future<String?> _getToken() async {
    const attempts = 3;
    for (var i = 0; i < attempts; i++) {
      try {
        if (kIsWeb && FirebaseConfig.vapidKey.isNotEmpty) {
          return await FirebaseMessaging.instance.getToken(
            vapidKey: FirebaseConfig.vapidKey,
          );
        }
        return await FirebaseMessaging.instance.getToken();
      } catch (_) {
        if (!kIsWeb || i == attempts - 1) return null;
        await Future<void>.delayed(Duration(milliseconds: 600 * (i + 1)));
      }
    }
    return null;
  }

  Future<void> _registerToken(String token) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    await createDeviceTokensRepository().upsert(
          userId: user.id,
          fcmToken: token,
          platform: pushPlatformLabel(),
        );

    _currentToken = token;
    _lastRegisteredUserId = user.id;
  }

  void _onForegroundMessage(RemoteMessage message) {
    _ref.read(notificationsProvider.notifier).silentRefresh();

    final title = message.notification?.title ?? message.data['title'];
    if (title == null || title.isEmpty) return;

    final body = message.notification?.body ?? message.data['body'] ?? '';

    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(body.isNotEmpty ? '$title\n$body' : title),
        action: _canNavigate(message.data)
            ? SnackBarAction(
                label: 'Ver',
                onPressed: () => _navigateFromData(message.data),
              )
            : null,
      ),
    );
  }

  void _onMessageOpened(RemoteMessage message) {
    final notificationId = message.data['notificationId']?.toString();
    if (notificationId != null && notificationId.isNotEmpty) {
      unawaited(
        _ref.read(notificationsProvider.notifier).markRead(notificationId),
      );
    }
    _navigateFromData(message.data);
  }

  bool _canNavigate(Map<String, dynamic> data) {
    return _resolveRoute(data) != null || isCalendarNotificationData(data);
  }

  Future<void> _navigateFromData(Map<String, dynamic> data) async {
    if (isCalendarNotificationData(data)) {
      _ref.read(routerProvider).go('/calendario');
      final focus = await buildCalendarFocusFromNotification(
        repo: _ref.read(calendarRepositoryProvider),
        eventId: data['eventId']?.toString(),
        startsAt: parseNotificationEventStartsAt(data['startsAt']),
      );
      if (focus != null) {
        _ref.read(calendarFocusRequestProvider.notifier).setFocus(focus);
      }
      return;
    }

    final route = _resolveRoute(data);
    if (route != null && route.isNotEmpty) {
      _navigateToRoute(route);
    }
  }

  String? _resolveRoute(Map<String, dynamic> data) {
    final route = data['route'];
    if (route is String && route.isNotEmpty) return route;

    final forumId = data['forumId'];
    final topicId = data['topicId'];
    if (forumId is! String || topicId is! String) return null;

    final replyId = data['replyId'];
    final section = data['officialCategory'] is String
        ? hermandadSectionQueryValue(data['officialCategory'] as String)
        : data['seccion'] is String
            ? parseHermandadSectionQuery(data['seccion'] as String)
            : null;

    final query = buildForumTopicQuery(
      section: forumId == 'hermandades' ? section : null,
      replyId: replyId is String ? replyId : null,
    );
    return forumTopicLocation(forumId, topicId, querySuffix: query);
  }

  void _navigateToRoute(String route) {
    try {
      _ref.read(routerProvider).go(route);
    } catch (_) {
      // Router aún no listo; se ignora.
    }
  }
}
