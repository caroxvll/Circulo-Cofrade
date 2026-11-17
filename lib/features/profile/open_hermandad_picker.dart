import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'profile_provider.dart';

/// Abre Perfil → Siguiendo, en el directorio para elegir hermandad.
void openHermandadPicker(BuildContext context, WidgetRef ref) {
  ref.read(profileFollowingIntentProvider.notifier).open(discover: true);
  context.go('/perfil');
}
