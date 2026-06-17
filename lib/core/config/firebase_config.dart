/// Firebase vía `--dart-define-from-file=env.json` (opcional).
abstract final class FirebaseConfig {
  static const projectId =
      String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: '');
  static const apiKey =
      String.fromEnvironment('FIREBASE_API_KEY', defaultValue: '');
  static const appId =
      String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '');
  static const messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '');
  static const authDomain =
      String.fromEnvironment('FIREBASE_AUTH_DOMAIN', defaultValue: '');
  static const vapidKey =
      String.fromEnvironment('FIREBASE_VAPID_KEY', defaultValue: '');

  static bool get isConfigured =>
      projectId.isNotEmpty &&
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      messagingSenderId.isNotEmpty;
}
