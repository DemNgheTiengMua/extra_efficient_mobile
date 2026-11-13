import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/account_screen.dart';
import '../../features/account/screens/complaints_screen.dart';
import '../../features/account/screens/file_complaint_screen.dart';
import '../../features/account/screens/profile_screen.dart';
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
import '../../features/path/screens/goal_calibration_screen.dart';
import '../../features/path/screens/learning_path_screen.dart';
import '../../features/path/screens/lesson_player_screen.dart';
import '../../features/path/screens/path_dashboard_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/shell/tab_placeholder_screen.dart';
import '../../features/wallet/screens/wallet_screen.dart';

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
                builder: (context, state) => const PathDashboardScreen(),
                routes: [
                  GoRoute(
                    path: 'goal',
                    builder: (context, state) => const GoalCalibrationScreen(),
                  ),
                  GoRoute(
                    path: 'learning-path',
                    builder: (context, state) => const LearningPathScreen(),
                  ),
                  GoRoute(
                    path: 'lessons/:id',
                    builder: (context, state) {
                      final id =
                          int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                      return LessonPlayerScreen(lessonId: id);
                    },
                  ),
                ],
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
                builder: (context, state) => const WalletScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/account',
                builder: (context, state) => const AccountScreen(),
                routes: [
                  GoRoute(
                    path: 'profile',
                    builder: (context, state) => const ProfileScreen(),
                  ),
                  GoRoute(
                    path: 'complaints',
                    builder: (context, state) => const ComplaintsScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (context, state) =>
                            const FileComplaintScreen(),
                      ),
                    ],
                  ),
                ],
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
