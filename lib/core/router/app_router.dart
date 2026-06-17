import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';



import '../../features/auth/auth_provider.dart';
import '../../features/auth/data/auth_repository.dart';

import '../../features/calendar/calendar_screen.dart';

import '../../features/forums/forum_topics_screen.dart';

import '../../features/forums/forums_screen.dart';

import '../../features/forums/topic_detail_screen.dart';

import '../../features/auth/login_screen.dart';

import '../../features/auth/register_screen.dart';

import '../../features/auth/splash_screen.dart';

import '../../features/auth/welcome_screen.dart';

import '../../features/auth/forgot_password_screen.dart';

import '../../features/auth/reset_password_screen.dart';

import '../../features/auth/verify_email_screen.dart';

import '../../features/profile/edit_profile_screen.dart';

import '../../features/profile/blocked_accounts_screen.dart';

import '../../features/profile/user_profile_screen.dart';

import '../../features/notifications/notification_preferences_screen.dart';

import '../../features/notifications/notifications_screen.dart';

import '../../features/profile/profile_screen.dart';

import '../../features/admin/junta_screen.dart';

import '../../features/search/search_screen.dart';

import '../../features/shell/cofradeo_shell.dart';



final _rootNavigatorKey = GlobalKey<NavigatorState>();

final _forumsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'foros');

bool _isPublicAuthRoute(String location) =>
    location == '/splash' ||
    location == '/bienvenida' ||
    location == '/login' ||
    location == '/registro' ||
    location == '/recuperar-contrasena' ||
    location == '/nueva-contrasena' ||
    location == '/verificar-email';

bool _isPasswordRecoveryRoute(String location) =>
    location == '/recuperar-contrasena' || location == '/nueva-contrasena';

String? _authRedirect(Ref ref, GoRouterState state) {
  final location = state.matchedLocation;
  final repo = ref.read(authRepositoryProvider);
  final isLoggedIn = repo.currentSession != null;
  final emailVerified = isLoggedIn && repo.isEmailVerified;

  if (!ref.read(authRequiredProvider)) {
    if (location == '/splash') return '/calendario';
    return null;
  }

  if (location == '/splash') {
    if (isLoggedIn) {
      return emailVerified ? '/calendario' : '/verificar-email';
    }
    return '/bienvenida';
  }

  if (!isLoggedIn && !_isPublicAuthRoute(location)) {
    return '/bienvenida';
  }

  if (isLoggedIn && !emailVerified) {
    if (_isPasswordRecoveryRoute(location)) return null;
    if (location == '/verificar-email') return null;
    return '/verificar-email';
  }

  if (isLoggedIn && _isPublicAuthRoute(location)) {
    if (_isPasswordRecoveryRoute(location)) return null;
    if (location == '/verificar-email') return '/calendario';
    final redirect = state.uri.queryParameters['redirect'];
    if (redirect != null && redirect.isNotEmpty) return redirect;
    return '/calendario';
  }

  return null;
}

final routerProvider = Provider<GoRouter>((ref) {

  final refresh = ValueNotifier<int>(0);

  ref.listen(authStateChangesProvider, (_, __) {

    refresh.value++;

  });

  ref.onDispose(refresh.dispose);



  return GoRouter(

    navigatorKey: _rootNavigatorKey,

    initialLocation: '/splash',

    refreshListenable: refresh,

    redirect: (context, state) => _authRedirect(ref, state),

    routes: [

      GoRoute(

        path: '/splash',

        parentNavigatorKey: _rootNavigatorKey,

        builder: (context, state) => const AuthSplashScreen(),

      ),

      GoRoute(

        path: '/bienvenida',

        parentNavigatorKey: _rootNavigatorKey,

        builder: (context, state) => const WelcomeScreen(),

      ),

      GoRoute(

        path: '/login',

        parentNavigatorKey: _rootNavigatorKey,

        builder: (context, state) {

          final redirect = state.uri.queryParameters['redirect'];

          return LoginScreen(redirect: redirect);

        },

      ),

      GoRoute(

        path: '/registro',

        parentNavigatorKey: _rootNavigatorKey,

        builder: (context, state) {

          final redirect = state.uri.queryParameters['redirect'];

          return RegisterScreen(redirect: redirect);

        },

      ),

      GoRoute(

        path: '/recuperar-contrasena',

        parentNavigatorKey: _rootNavigatorKey,

        builder: (context, state) => const ForgotPasswordScreen(),

      ),

      GoRoute(

        path: '/nueva-contrasena',

        parentNavigatorKey: _rootNavigatorKey,

        builder: (context, state) => const ResetPasswordScreen(),

      ),

      GoRoute(

        path: '/verificar-email',

        parentNavigatorKey: _rootNavigatorKey,

        builder: (context, state) => VerifyEmailScreen(

          email: state.uri.queryParameters['email'],

        ),

      ),

      StatefulShellRoute.indexedStack(

        builder: (context, state, navigationShell) {

          return CofradeoShell(navigationShell: navigationShell);

        },

        branches: [

          StatefulShellBranch(

            routes: [

              GoRoute(

                path: '/calendario',

                builder: (context, state) => const CalendarScreen(),

              ),

            ],

          ),

          StatefulShellBranch(

            navigatorKey: _forumsNavigatorKey,

            routes: [

              GoRoute(

                path: '/foros',

                builder: (context, state) => const ForumsScreen(),

              ),

              GoRoute(

                path: '/foros/:forumId',

                builder: (context, state) {

                  final forumId = state.pathParameters['forumId']!;

                  return ForumTopicsScreen(forumId: forumId);

                },

              ),

              GoRoute(

                path: '/foros/:forumId/tema/:topicId',

                builder: (context, state) {

                  final forumId = state.pathParameters['forumId']!;

                  final topicId = state.pathParameters['topicId']!;

                  return TopicDetailScreen(

                    forumId: forumId,

                    topicId: topicId,

                    highlightReplyId: state.uri.queryParameters['reply'],

                  );

                },

              ),

            ],

          ),

          StatefulShellBranch(

            routes: [

              GoRoute(

                path: '/buscar',

                builder: (context, state) => const SearchScreen(),

              ),

            ],

          ),

          StatefulShellBranch(

            routes: [

              GoRoute(

                path: '/notificaciones',

                builder: (context, state) => const NotificationsScreen(),

              ),

            ],

          ),

          StatefulShellBranch(

            routes: [

              GoRoute(

                path: '/perfil',

                builder: (context, state) => const ProfileScreen(),

                routes: [

                  GoRoute(

                    path: 'usuario/:userId',

                    builder: (context, state) {

                      final userId = state.pathParameters['userId']!;

                      return UserProfileScreen(userId: userId);

                    },

                  ),

                  GoRoute(

                    path: 'junta',

                    builder: (context, state) => const JuntaScreen(),

                  ),

                  GoRoute(

                    path: 'editar',

                    builder: (context, state) => const EditProfileScreen(),

                  ),

                  GoRoute(

                    path: 'notificaciones',

                    builder: (context, state) =>

                        const NotificationPreferencesScreen(),

                  ),

                  GoRoute(

                    path: 'bloqueados',

                    builder: (context, state) => const BlockedAccountsScreen(),

                  ),

                ],

              ),

            ],

          ),

        ],

      ),

    ],

  );

});


