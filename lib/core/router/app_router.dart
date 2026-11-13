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
                builder: (context, state) => const TabPlaceholderScreen(
                  tabName: 'EXAMS',
                  description:
                      'Timed mock exams and AI-graded speaking/writing skill practice.',
                ),
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
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});
