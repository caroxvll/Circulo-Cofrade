import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_branding.dart';
import 'core/messenger/root_messenger.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_provider.dart';
import 'features/push/push_scope.dart';

class CofradeoApp extends ConsumerWidget {
  const CofradeoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    ref.listen(authStateChangesProvider, (previous, next) {
      final event = next.asData?.value.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        router.go('/nueva-contrasena');
      }

      if (event == AuthChangeEvent.signedOut &&
          ref.read(authRequiredProvider)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          router.go('/bienvenida');
        });
      }

      if (previous == null) return;
      final prevId = previous.asData?.value.session?.user?.id;
      final nextId = next.asData?.value.session?.user?.id;
      if (prevId != nextId) {
        rootScaffoldMessengerKey.currentState?.clearSnackBars();
      }
    });

    return PushScope(
      child: MaterialApp.router(
        title: AppBranding.name,
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        theme: AppTheme.light,
        locale: const Locale('es', 'ES'),
        supportedLocales: const [
          Locale('es', 'ES'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
      ),
    );
  }
}
