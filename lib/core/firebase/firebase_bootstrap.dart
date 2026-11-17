import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../config/firebase_config.dart';

abstract final class FirebaseBootstrap {
  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  /// `env.json` lleva el appId de la app web. En iOS, Firebase aborta el
  /// proceso si ese id no es de iOS.
  static bool get _appIdMatchesPlatform {
    final id = FirebaseConfig.appId;
    if (kIsWeb) return id.contains(':web:');
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return id.contains(':ios:');
    }
    return true;
  }

  static Future<void> initialize() async {
    if (!FirebaseConfig.isConfigured || !_appIdMatchesPlatform) return;
    if (_initialized) return;

    try {
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
    } catch (error, stack) {
      debugPrint('Firebase no se inició: $error\n$stack');
    }
  }
}
