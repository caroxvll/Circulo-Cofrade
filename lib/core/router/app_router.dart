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
import '../../features/semana_santa/screens/ss_informar_compose_screen.dart';
import '../../features/semana_santa/screens/ss_informar_kind_screen.dart';
import '../../features/semana_santa/models/ss_live_update.dart';
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
import '../../features/profile/widgets/profile_people_mode.dart';
import '../../features/profile/user_profile_screen.dart';
import '../../features/notifications/notification_preferences_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/admin/junta_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/shell/cofradeo_shell.dart';
import 'cofradeo_page.dart';

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

  ref.listen(authStateChangesProvider, (_, _) {
    refresh.value++;
  });

  ref.listen(currentUserProfileProvider, (_, _) {
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
        pageBuilder: (context, state) => cofradeoAuthPage(
          state: state,
          child: const AuthSplashScreen(),
        ),
      ),
      GoRoute(
        path: '/bienvenida',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => cofradeoAuthPage(
          state: state,
          child: const WelcomeScreen(),
        ),
      ),
      GoRoute(
        path: '/login',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => cofradeoAuthPage(
          state: state,
          child: LoginScreen(redirect: state.uri.queryParameters['redirect']),
        ),
      ),
      GoRoute(
        path: '/registro',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => cofradeoAuthPage(
          state: state,
          child: RegisterScreen(redirect: state.uri.queryParameters['redirect']),
        ),
      ),
      GoRoute(
        path: '/recuperar-contrasena',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => cofradeoFadePage(
          state: state,
          child: const ForgotPasswordScreen(),
        ),
      ),
      GoRoute(
        path: '/nueva-contrasena',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => cofradeoFadePage(
          state: state,
          child: const ResetPasswordScreen(),
        ),
      ),
      GoRoute(
        path: '/verificar-email',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => cofradeoFadePage(
          state: state,
          child: VerifyEmailScreen(
            email: state.uri.queryParameters['email'],
          ),
        ),
      ),
      GoRoute(
        path: '/completar-perfil',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => cofradeoFadePage(
          state: state,
          child: CompleteProfileScreen(
            redirect: state.uri.queryParameters['redirect'],
          ),
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
                pageBuilder: (context, state) => cofradeoTabPage(
                  state: state,
                  child: const CalendarScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _forumsNavigatorKey,
            routes: [
              GoRoute(
                path: '/foros',
                pageBuilder: (context, state) => cofradeoTabPage(
                  state: state,
                  child: const ForumsScreen(),
                ),
              ),
              GoRoute(
                path: '/foros/mis-hermandades',
                pageBuilder: (context, state) => cofradeoFadePage(
                  state: state,
                  child: const MisHermandadesScreen(),
                ),
              ),
              GoRoute(
                path: '/quiz',
                pageBuilder: (context, state) => cofradeoFadePage(
                  state: state,
                  child: const QuizPlayScreen(),
                ),
              ),
              GoRoute(
                path: '/quiz/ranking',
                pageBuilder: (context, state) => cofradeoFadePage(
                  state: state,
                  child: const QuizRankingScreen(),
                ),
              ),
              GoRoute(
                path: '/foros/:forumId',
                pageBuilder: (context, state) {
                  final forumId = state.pathParameters['forumId']!;
                  return cofradeoFadePage(
                    state: state,
                    child: ForumTopicsScreen(forumId: forumId),
                  );
                },
              ),
              GoRoute(
                path: '/foros/:forumId/tema/:topicId',
                pageBuilder: (context, state) {
                  final forumId = state.pathParameters['forumId']!;
                  final topicId = state.pathParameters['topicId']!;

                  final Widget child;
                  if (topicId == cuaresmaTopicId) {
                    child = CuaresmaHubScreen(
                      forumId: forumId,
                      topicId: topicId,
                    );
                  } else if (topicId == semanaSantaTopicId) {
                    child = SemanaSantaHubScreen(
                      forumId: forumId,
                      topicId: topicId,
                    );
                  } else if (topicId == gloriasTopicId) {
                    child = GloriasHubScreen(
                      forumId: forumId,
                      topicId: topicId,
                    );
                  } else {
                    child = TopicDetailScreen(
                      forumId: forumId,
                      topicId: topicId,
                      highlightReplyId: state.uri.queryParameters['reply'],
                    );
                  }

                  return cofradeoFadePage(state: state, child: child);
                },
                routes: [
                  GoRoute(
                    path: 'ensayo/:eventId',
                    pageBuilder: (context, state) => cofradeoFadePage(
                      state: state,
                      child: EnsayoLiveScreen(
                        forumId: state.pathParameters['forumId']!,
                        topicId: state.pathParameters['topicId']!,
                        eventId: state.pathParameters['eventId']!,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'informar',
                    pageBuilder: (context, state) => cofradeoFadePage(
                      state: state,
                      child: SsInformarKindScreen(
                        forumId: state.pathParameters['forumId']!,
                        topicId: state.pathParameters['topicId']!,
                      ),
                    ),
                    routes: [
                      GoRoute(
                        path: ':kind',
                        pageBuilder: (context, state) {
                          final kind = SsLiveUpdateKind.fromDb(
                            state.pathParameters['kind'],
                          );
                          return cofradeoFadePage(
                            state: state,
                            child: SsInformarComposeScreen(
                              forumId: state.pathParameters['forumId']!,
                              topicId: state.pathParameters['topicId']!,
                              kind: kind,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/buscar',
                pageBuilder: (context, state) => cofradeoTabPage(
                  state: state,
                  child: const SearchScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/notificaciones',
                pageBuilder: (context, state) => cofradeoTabPage(
                  state: state,
                  child: const NotificationsScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/perfil',
                pageBuilder: (context, state) => cofradeoTabPage(
                  state: state,
                  child: const ProfileScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'usuario/:userId',
                    pageBuilder: (context, state) {
                      final userId = state.pathParameters['userId']!;
                      return cofradeoFadePage(
                        state: state,
                        child: UserProfileScreen(userId: userId),
                      );
                    },
                    routes: [
                      GoRoute(
                        path: 'seguidores',
                        pageBuilder: (context, state) {
                          final userId = state.pathParameters['userId']!;
                          return cofradeoFadePage(
                            state: state,
                            child: FollowersScreen(
                              forUserId: userId,
                              initialMode: ProfilePeopleMode.seguidores,
                            ),
                          );
                        },
                      ),
                      GoRoute(
                        path: 'siguiendo',
                        pageBuilder: (context, state) {
                          final userId = state.pathParameters['userId']!;
                          return cofradeoFadePage(
                            state: state,
                            child: FollowersScreen(
                              forUserId: userId,
                              initialMode: ProfilePeopleMode.siguiendo,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'junta',
                    pageBuilder: (context, state) => cofradeoFadePage(
                      state: state,
                      child: const JuntaScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'editar',
                    pageBuilder: (context, state) => cofradeoFadePage(
                      state: state,
                      child: const EditProfileScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'notificaciones',
                    pageBuilder: (context, state) => cofradeoFadePage(
                      state: state,
                      child: const NotificationPreferencesScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'seguidores',
                    pageBuilder: (context, state) {
                      final modo = state.uri.queryParameters['modo'];
                      return cofradeoFadePage(
                        state: state,
                        child: FollowersScreen(
                          initialMode: modo == 'siguiendo'
                              ? ProfilePeopleMode.siguiendo
                              : ProfilePeopleMode.seguidores,
                        ),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'siguiendo',
                    pageBuilder: (context, state) => cofradeoFadePage(
                      state: state,
                      child: const FollowersScreen(
                        initialMode: ProfilePeopleMode.siguiendo,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'bloqueados',
                    pageBuilder: (context, state) => cofradeoFadePage(
                      state: state,
                      child: const BlockedAccountsScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'eventos-guardados',
                    pageBuilder: (context, state) => cofradeoFadePage(
                      state: state,
                      child: const SavedEventsScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'publicaciones-programadas',
                    pageBuilder: (context, state) => cofradeoFadePage(
                      state: state,
                      child: const HermandadScheduledPostsScreen(),
                    ),
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
