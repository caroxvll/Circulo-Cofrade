import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';



import '../../features/auth/auth_provider.dart';

import '../../features/calendar/calendar_screen.dart';

import '../../features/forums/forum_topics_screen.dart';

import '../../features/forums/forums_screen.dart';

import '../../features/cuaresma/screens/cuaresma_hub_screen.dart';
import '../../features/cuaresma/screens/ensayo_live_screen.dart';
import '../../features/cuaresma/utils/cuaresma_topic.dart';
import '../../features/glorias/screens/glorias_hub_screen.dart';
import '../../features/glorias/utils/glorias_topic.dart';
import '../../features/semana_santa/screens/semana_santa_hub_screen.dart';
import '../../features/semana_santa/screens/ss_live_screen.dart';
import '../../features/semana_santa/utils/semana_santa_topic.dart';
import '../../features/quiz/screens/quiz_play_screen.dart';
import '../../features/quiz/screens/quiz_ranking_screen.dart';

import '../../features/forums/topic_detail_screen.dart';
import '../../features/forums/mis_hermandades_screen.dart';

import '../../features/auth/login_screen.dart';

import '../../features/auth/register_screen.dart';

import '../../features/auth/splash_screen.dart';

import '../../features/auth/welcome_screen.dart';

import '../../features/auth/forgot_password_screen.dart';

import '../../features/auth/reset_password_screen.dart';

import '../../features/auth/verify_email_screen.dart';

import '../../features/profile/complete_profile_screen.dart';
import '../../features/profile/profile_onboarding.dart';
import '../../features/profile/profile_provider.dart';
import '../../features/profile/edit_profile_screen.dart';

import '../../features/calendar/saved_events_screen.dart';
import '../../features/forums/hermandad_scheduled_posts_screen.dart';
import '../../features/profile/blocked_accounts_screen.dart';
import '../../features/profile/widgets/followers_screen.dart';
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

Future<String?> _authRedirect(Ref ref, GoRouterState state) async {
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
      if (!emailVerified) return '/verificar-email';
      if (await needsProfileOnboarding(ref)) {
        return '/completar-perfil';
      }
      return '/calendario';
    }
    return '/bienvenida';
  }

  if (!isLoggedIn && !_isPublicAuthRoute(location)) {
    if (location == '/completar-perfil') {
      return '/login?redirect=${Uri.encodeComponent('/completar-perfil')}';
    }
    // Enlace compartido a un tema/comentario: tras login volver ahí.
    if (location.startsWith('/foros/')) {
      final path =
          '${state.uri.path}${state.uri.hasQuery ? '?${state.uri.query}' : ''}';
      return '/login?redirect=${Uri.encodeComponent(path)}';
    }
    return '/bienvenida';
  }

  if (isLoggedIn && !emailVerified) {
    if (_isPasswordRecoveryRoute(location)) return null;
    if (location == '/verificar-email') return null;
    return '/verificar-email';
  }

  if (isLoggedIn && location == '/completar-perfil') {
    if (!await needsProfileOnboarding(ref)) {
      return '/calendario';
    }
    return null;
  }

  if (isLoggedIn && await needsProfileOnboarding(ref)) {
    return '/completar-perfil';
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

  ref.listen(currentUserProfileProvider, (_, __) {

    refresh.value++;

  });

  ref.onDispose(refresh.dispose);



  return GoRouter(

    navigatorKey: _rootNavigatorKey,

    initialLocation: '/splash',

    refreshListenable: refresh,

    redirect: (context, state) async => _authRedirect(ref, state),

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

      GoRoute(

        path: '/completar-perfil',

        parentNavigatorKey: _rootNavigatorKey,

        builder: (context, state) => CompleteProfileScreen(
          redirect: state.uri.queryParameters['redirect'],
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
                path: '/foros/mis-hermandades',
                builder: (context, state) => const MisHermandadesScreen(),
              ),
              GoRoute(
                path: '/quiz',
                builder: (context, state) => const QuizPlayScreen(),
              ),

              GoRoute(

                path: '/quiz/ranking',

                builder: (context, state) => const QuizRankingScreen(),

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

                  if (topicId == cuaresmaTopicId) {
                    return CuaresmaHubScreen(
                      forumId: forumId,
                      topicId: topicId,
                    );
                  }

                  if (topicId == semanaSantaTopicId) {
                    return SemanaSantaHubScreen(
                      forumId: forumId,
                      topicId: topicId,
                    );
                  }

                  if (topicId == gloriasTopicId) {
                    return GloriasHubScreen(
                      forumId: forumId,
                      topicId: topicId,
                    );
                  }

                  return TopicDetailScreen(

                    forumId: forumId,

                    topicId: topicId,

                    highlightReplyId: state.uri.queryParameters['reply'],

                  );

                },

                routes: [

                  GoRoute(

                    path: 'ensayo/:eventId',

                    builder: (context, state) {

                      return EnsayoLiveScreen(

                        forumId: state.pathParameters['forumId']!,

                        topicId: state.pathParameters['topicId']!,

                        eventId: state.pathParameters['eventId']!,

                      );

                    },

                  ),

                  GoRoute(
                    path: 'en-directo',
                    builder: (context, state) {
                      return SsLiveScreen(
                        forumId: state.pathParameters['forumId']!,
                        topicId: state.pathParameters['topicId']!,
                      );
                    },
                  ),

                ],

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

                    path: 'seguidores',

                    builder: (context, state) => const FollowersScreen(),

                  ),

                  GoRoute(

                    path: 'bloqueados',

                    builder: (context, state) => const BlockedAccountsScreen(),

                  ),

                  GoRoute(

                    path: 'eventos-guardados',

                    builder: (context, state) => const SavedEventsScreen(),

                  ),

                  GoRoute(

                    path: 'publicaciones-programadas',

                    builder: (context, state) =>
                        const HermandadScheduledPostsScreen(),

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


