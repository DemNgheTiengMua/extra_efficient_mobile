import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/account_screen.dart';
import '../../features/auth/auth_models.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/sign_in_screen.dart';
import '../../features/auth/screens/verify_email_screen.dart';
import '../../features/exams/screens/exam_hub_screen.dart';
import '../../features/exams/screens/placement_exam_room_screen.dart';
import '../../features/exams/screens/placement_overview_screen.dart';
import '../../features/exams/screens/placement_result_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/shell/tab_placeholder_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

const _authRoutes = {
  '/sign-in',
  '/register',
  '/verify-email',
  '/forgot-password',
};

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = ref.watch(authRouterRefreshProvider);

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/path',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final auth = ref.read(authNotifierProvider);
      if (auth.status == AuthStatus.unknown) {
        return null;
      }
      final location = state.matchedLocation;
      final isAuthRoute = _authRoutes.contains(location);

      if (!auth.isAuthenticated && !isAuthRoute) {
        return '/sign-in';
      }
      if (auth.isAuthenticated && isAuthRoute) {
        return '/path';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainShell(
          navigationShell: navigationShell,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/path',
                builder: (context, state) => const TabPlaceholderScreen(
                  tabName: 'PATH',
                  description:
                      'Personalized learning path, placement status, and next action.',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/practice',
                builder: (context, state) => const TabPlaceholderScreen(
                  tabName: 'PRACTICE',
                  description:
                      'Free section & matrix drills, saved questions, and weakness report.',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/exams',
                builder: (context, state) => const ExamHubScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/wallet',
                builder: (context, state) => const TabPlaceholderScreen(
                  tabName: 'WALLET',
                  description:
                      'Credit balance, append-only ledger, credit packages, and mentors.',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/account',
                builder: (context, state) => const AccountScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/placement',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PlacementOverviewScreen(),
      ),
      GoRoute(
        path: '/placement/take/:placementId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id =
              int.tryParse(state.pathParameters['placementId'] ?? '') ?? 0;
          final resume = state.uri.queryParameters['resume'] == '1';
          return PlacementExamRoomScreen(placementId: id, resume: resume);
        },
      ),
      GoRoute(
        path: '/placement/result/:placementId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id =
              int.tryParse(state.pathParameters['placementId'] ?? '') ?? 0;
          return PlacementResultScreen(placementId: id);
        },
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});
