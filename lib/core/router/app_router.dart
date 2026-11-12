import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_attendance_app/core/theme/app_theme.dart';
import 'package:qr_attendance_app/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:qr_attendance_app/features/attendance/presentation/pages/attendance_history_page.dart';
import 'package:qr_attendance_app/features/attendance/presentation/pages/employee_dashboard_page.dart';
import 'package:qr_attendance_app/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:qr_attendance_app/features/authentication/presentation/bloc/auth_state.dart';
import 'package:qr_attendance_app/features/authentication/presentation/pages/login_page.dart';
import 'package:qr_attendance_app/features/authentication/presentation/pages/profile_page.dart';
import 'package:qr_attendance_app/features/authentication/presentation/pages/splash_page.dart';
import 'package:qr_attendance_app/features/qr_attendance/presentation/pages/admin_qr_generator_page.dart';
import 'package:qr_attendance_app/features/qr_attendance/presentation/pages/qr_scanner_page.dart';

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class AppRouter {
  AppRouter(this._authBloc) {
    _refreshListenable = GoRouterRefreshStream(_authBloc.stream);
    router = GoRouter(
      initialLocation: '/splash',
      refreshListenable: _refreshListenable,
      redirect: _handleRedirect,
      routes: [
        GoRoute(
          path: '/splash',
          builder: (_, _) => const SplashPage(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => const LoginPage(),
        ),
        ShellRoute(
          builder: (context, state, child) => _AppShellScaffold(
            location: state.matchedLocation,
            child: child,
          ),
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (_, _) => const EmployeeDashboardPage(),
            ),
            GoRoute(
              path: '/history',
              builder: (_, _) => const AttendanceHistoryPage(),
            ),
            GoRoute(
              path: '/admin',
              builder: (_, _) => const AdminDashboardPage(),
            ),
            GoRoute(
              path: '/admin/qr-generator',
              builder: (_, _) => const AdminQrGeneratorPage(),
            ),
            GoRoute(
              path: '/profile',
              builder: (_, _) => const ProfilePage(),
            ),
          ],
        ),
        GoRoute(
          path: '/scan',
          builder: (_, state) => QrScannerPage(
            preferredAction: state.uri.queryParameters['action'],
          ),
        ),
      ],
    );
  }

  final AuthBloc _authBloc;
  late final GoRouterRefreshStream _refreshListenable;
  late final GoRouter router;

  String? _handleRedirect(BuildContext context, GoRouterState state) {
    final authState = _authBloc.state;
    final location = state.matchedLocation;

    if (authState.status == AuthStatus.initial ||
        authState.status == AuthStatus.checking) {
      return location == '/splash' ? null : '/splash';
    }

    if (!authState.isAuthenticated) {
      return location == '/login' ? null : '/login';
    }

    final isAdmin = authState.user?.isAdmin ?? false;

    if (location == '/splash' || location == '/login') {
      return isAdmin ? '/admin' : '/dashboard';
    }

    if (!isAdmin && location.startsWith('/admin')) {
      return '/dashboard';
    }

    if (isAdmin &&
        (location == '/dashboard' ||
            location == '/history' ||
            location == '/scan')) {
      return '/admin';
    }

    return null;
  }

  void dispose() {
    _refreshListenable.dispose();
    router.dispose();
  }
}

class _AppShellScaffold extends StatelessWidget {
  const _AppShellScaffold({
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select(
      (AuthBloc bloc) => bloc.state.user?.isAdmin ?? false,
    );

    final destinations = isAdmin
        ? const <_NavItem>[
            _NavItem(
              route: '/admin',
              label: 'Console',
              icon: Icons.admin_panel_settings_outlined,
              selectedIcon: Icons.admin_panel_settings_rounded,
            ),
            _NavItem(
              route: '/admin/qr-generator',
              label: 'QR Kiosk',
              icon: Icons.qr_code_2_outlined,
              selectedIcon: Icons.qr_code_2_rounded,
            ),
            _NavItem(
              route: '/profile',
              label: 'Profile',
              icon: Icons.person_outline_rounded,
              selectedIcon: Icons.person_rounded,
            ),
          ]
        : const <_NavItem>[
            _NavItem(
              route: '/dashboard',
              label: 'Dashboard',
              icon: Icons.dashboard_outlined,
              selectedIcon: Icons.dashboard_rounded,
            ),
            _NavItem(
              route: '/history',
              label: 'History',
              icon: Icons.history_outlined,
              selectedIcon: Icons.history_rounded,
            ),
            _NavItem(
              route: '/profile',
              label: 'Profile',
              icon: Icons.person_outline_rounded,
              selectedIcon: Icons.person_rounded,
            ),
          ];

    final currentIndex = destinations.indexWhere(
      (item) => item.route == location,
    );
    final selectedIndex = currentIndex >= 0 ? currentIndex : 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 800;
        if (useRail) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: AppColors.surface,
                  onDestinationSelected: (idx) =>
                      context.go(destinations[idx].route),
                  destinations: destinations
                      .map(
                        (d) => NavigationRailDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: Text(d.label),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: child),
              ],
            ),
          );
        }

        return Scaffold(
          body: child,
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (idx) =>
                context.go(destinations[idx].route),
            destinations: destinations
                .map(
                  (d) => NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label,
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.route,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String route;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

