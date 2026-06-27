import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/diesel/screens/diesel_list_screen.dart';
import '../../features/vehicles/screens/vehicles_screen.dart';

/// Bridges Riverpod auth state changes to GoRouter's Listenable refresh.
class _AuthStateListener extends ChangeNotifier {
  _AuthStateListener(Ref ref) {
    ref.listen(authProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final listener = _AuthStateListener(ref);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: listener,
    redirect: (context, state) {
      final authState = ref.read(authProvider);

      // Still loading — let the splash stay
      if (authState.isLoading) return null;

      final isAuthenticated = authState.valueOrNull != null;
      final isOnLogin = state.matchedLocation == '/login';

      if (!isAuthenticated && !isOnLogin) return '/login';
      if (isAuthenticated && isOnLogin) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/diesel-records',
        builder: (context, state) => const DieselListScreen(),
      ),
      GoRoute(
        path: '/vehicles',
        builder: (context, state) => const VehiclesScreen(),
      ),
    ],
  );
});
