import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pressfit/providers/auth_provider.dart';
import 'package:pressfit/screens/auth/welcome_screen.dart';
import 'package:pressfit/screens/auth/login_screen.dart';
import 'package:pressfit/screens/auth/sign_up_screen.dart';
import 'package:pressfit/screens/main_shell.dart';
import 'package:pressfit/screens/weekly/monthly_calendar_screen.dart';
import 'package:pressfit/screens/weekly/workout_day_screen.dart';
import 'package:pressfit/screens/weekly/workout_screen.dart';
import 'package:pressfit/screens/weekly/exercise_library_screen.dart';
import 'package:pressfit/screens/weekly/exercise_detail_screen.dart';
import 'package:pressfit/screens/weekly/routine_editor_screen.dart';
import 'package:pressfit/screens/weekly/routine_detail_screen.dart';
import 'package:pressfit/screens/progress/progress_menu_screen.dart';
import 'package:pressfit/screens/progress/monthly_progress_screen.dart';
import 'package:pressfit/screens/progress/weekly_progress_screen.dart';
import 'package:pressfit/screens/progress/daily_progress_screen.dart';
import 'package:pressfit/screens/progress/exercise_tracking_screen.dart';
import 'package:pressfit/screens/progress/exercise_progress_detail_screen.dart';
import 'package:pressfit/screens/profile/profile_screen.dart';
import 'package:pressfit/screens/progress/physical_progress_screen.dart';
import 'package:pressfit/screens/weekly/exercise_catalog_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _weeklyNavigatorKey = GlobalKey<NavigatorState>();
final _progressNavigatorKey = GlobalKey<NavigatorState>();
final _profileNavigatorKey = GlobalKey<NavigatorState>();

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
      GoRoute(path: '/auth/welcome', builder: (context, state) => const WelcomeScreen()),
      GoRoute(path: '/auth/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/auth/signup', builder: (context, state) => const SignUpScreen()),

      // Main app with bottom navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          // Tab 1: Weekly
          StatefulShellBranch(
            navigatorKey: _weeklyNavigatorKey,
            routes: [
              GoRoute(
                path: '/weekly',
                builder: (context, state) => const MonthlyCalendarScreen(),
                routes: [
                  GoRoute(
                    path: 'day',
                    builder: (context, state) {
                      final extra = state.extra as Map<String, dynamic>? ?? {};
                      return WorkoutDayScreen(
                        date: extra['date'] as String? ?? DateTime.now().toIso8601String(),
                        routineId: extra['routineId'] as String?,
                        isToday: extra['isToday'] as bool? ?? false,
                      );
                    },
                    routes: [
                      GoRoute(
                        path: 'workout',
                        builder: (context, state) {
                          final extra = state.extra as Map<String, dynamic>? ?? {};
                          return WorkoutScreen(
                            workoutId: extra['workoutId'] as String,
                            dayName: extra['dayName'] as String? ?? '',
                            routineDayId: extra['routineDayId'] as String? ?? '',
                          );
                        },
                        routes: [
                          GoRoute(
                            path: 'exercises',
                            builder: (context, state) {
                              final extra = state.extra as Map<String, dynamic>? ?? {};
                              return ExerciseLibraryScreen(routineDayId: extra['routineDayId'] as String?);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'exercise/:id',
                    builder: (context, state) => ExerciseDetailScreen(exerciseId: state.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: 'routines',
                    builder: (context, state) => const RoutineEditorScreen(),
                  ),
                  GoRoute(
                    path: 'catalog',
                    builder: (context, state) => const ExerciseCatalogScreen(),
                  ),
                  GoRoute(
                    path: 'routine/:id',
                    builder: (context, state) => RoutineDetailScreen(routineId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          // Tab 2: Progress
          StatefulShellBranch(
            navigatorKey: _progressNavigatorKey,
            routes: [
              GoRoute(
                path: '/progress',
                builder: (context, state) => const ProgressMenuScreen(),
                routes: [
                  GoRoute(path: 'monthly', builder: (context, state) => const MonthlyProgressScreen()),
                  GoRoute(path: 'weekly', builder: (context, state) => const WeeklyProgressScreen()),
                  GoRoute(path: 'daily', builder: (context, state) => const DailyProgressScreen()),
                  GoRoute(
                    path: 'exercises',
                    builder: (context, state) => const ExerciseTrackingScreen(),
                    routes: [
                      GoRoute(
                        path: ':id',
                        builder: (context, state) => ExerciseProgressDetailScreen(exerciseId: state.pathParameters['id']!),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // Tab 3: Profile
          StatefulShellBranch(
            navigatorKey: _profileNavigatorKey,
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'physical-progress',
                    builder: (context, state) => const PhysicalProgressScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
