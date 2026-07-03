import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/diesel/screens/diesel_list_screen.dart';
import '../../features/system/providers/maintenance_provider.dart';
import '../../features/system/screens/maintenance_screen.dart';
import '../../features/vehicles/screens/vehicles_screen.dart';

/// Bridges Riverpod auth + maintenance state changes to GoRouter's
/// Listenable refresh.
class _AppStateListener extends ChangeNotifier {
  _AppStateListener(Ref ref) {
    ref.listen(authProvider, (_, _) => notifyListeners());
    ref.listen(maintenanceStatusProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final listener = _AppStateListener(ref);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: listener,
    redirect: (context, state) {
      final authState = ref.read(authProvider);

      // Still loading — let the splash stay
      if (authState.isLoading) return null;

      final isAuthenticated = authState.valueOrNull != null;
      final isAdmin = authState.valueOrNull?.isAdmin ?? false;
      final isOnLogin = state.matchedLocation == '/login';
      final isOnMaintenance = state.matchedLocation == '/maintenance';

      // Maintenance mode blocks everyone but admins, in place, regardless
      // of what screen they're on — checked ahead of the normal auth gate.
      final maintenance = ref.read(maintenanceStatusProvider);
      if (maintenance.maintenanceMode && !isAdmin) {
        return isOnMaintenance ? null : '/maintenance';
      }
      if (isOnMaintenance) {
        return isAuthenticated ? '/dashboard' : '/login';
      }

      if (!isAuthenticated && !isOnLogin) return '/login';
      if (isAuthenticated && isOnLogin) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/maintenance',
        builder: (context, state) =>
            MaintenanceScreen(message: ref.read(maintenanceStatusProvider).message),
      ),
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
