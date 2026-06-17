import 'package:firebase_core/firebase_core.dart';

import '../config/firebase_config.dart';

abstract final class FirebaseBootstrap {
  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static Future<void> initialize() async {
    if (!FirebaseConfig.isConfigured) return;
    if (_initialized) return;

    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: FirebaseConfig.apiKey,
        appId: FirebaseConfig.appId,
        messagingSenderId: FirebaseConfig.messagingSenderId,
        projectId: FirebaseConfig.projectId,
        authDomain: FirebaseConfig.authDomain.isEmpty
            ? null
            : FirebaseConfig.authDomain,
      ),
    );
    _initialized = true;
  }
}
