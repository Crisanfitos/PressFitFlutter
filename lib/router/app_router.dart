import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pressfit/providers/auth_provider.dart';
import 'package:pressfit/screens/auth/welcome_screen.dart';
import 'package:pressfit/screens/auth/login_screen.dart';
import 'package:pressfit/screens/auth/sign_up_screen.dart';
import 'package:pressfit/screens/main_shell.dart';
import 'package:pressfit/screens/weekly/monthly_calendar_screen.dart';
import 'package:pressfit/screens/progress/progress_screen.dart';
import 'package:pressfit/screens/profile/profile_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/weekly',
    refreshListenable: authProvider,
    redirect: (context, state) {
      final isAuth = authProvider.isAuthenticated;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');

      if (!isAuth && !isAuthRoute) return '/auth/welcome';
      if (isAuth && isAuthRoute) return '/weekly';
      return null;
    },
    routes: [
      // Auth routes
      GoRoute(
        path: '/auth/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/signup',
        builder: (context, state) => const SignUpScreen(),
      ),

      // Main app with bottom navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/weekly',
                builder: (context, state) => const MonthlyCalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/progress',
                builder: (context, state) => const ProgressScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
