import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/messenger/root_messenger.dart';
import '../../core/config/firebase_config.dart';
import '../../core/firebase/firebase_bootstrap.dart';
import '../../core/router/app_router.dart';
import '../../firebase_background.dart';
import '../auth/auth_provider.dart';
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

  Future<void> unregister() async {
    final token = _currentToken;
    final userId = _lastRegisteredUserId;
    if (token != null && userId != null) {
      await createDeviceTokensRepository().delete(
            userId: userId,
            fcmToken: token,
          );
    }
    _currentToken = null;
    _lastRegisteredUserId = null;
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
        action: message.data['route'] != null
            ? SnackBarAction(
                label: 'Ver',
                onPressed: () => _navigateToRoute(message.data['route']!),
              )
            : null,
      ),
    );
  }

  void _onMessageOpened(RemoteMessage message) {
    final route = message.data['route'];
    if (route != null && route.isNotEmpty) {
      _navigateToRoute(route);
    }
  }

  void _navigateToRoute(String route) {
    try {
      _ref.read(routerProvider).go(route);
    } catch (_) {
      // Router aún no listo; se ignora.
    }
  }
}
