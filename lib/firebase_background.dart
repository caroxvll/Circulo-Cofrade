import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/config/firebase_config.dart';
import 'core/firebase/firebase_bootstrap.dart';

/// Handler de mensajes FCM con la app en segundo plano o cerrada.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!FirebaseConfig.isConfigured) return;
  if (!FirebaseBootstrap.isInitialized) {
    await FirebaseBootstrap.initialize();
  }
}
