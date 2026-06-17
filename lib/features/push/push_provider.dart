import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/firebase_config.dart';
import '../../core/firebase/firebase_bootstrap.dart';
import 'data/device_tokens_repository.dart';
import 'push_messaging_service.dart';

final firebaseConfiguredProvider = Provider<bool>((ref) {
  return FirebaseConfig.isConfigured;
});

final firebaseReadyProvider = Provider<bool>((ref) {
  return FirebaseConfig.isConfigured && FirebaseBootstrap.isInitialized;
});

final deviceTokensRepositoryProvider = Provider<DeviceTokensRepository>((ref) {
  return createDeviceTokensRepository();
});

final pushMessagingServiceProvider = Provider<PushMessagingService>((ref) {
  return PushMessagingService(ref);
});
