import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../features/activity_log/screens/activity_log_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/diesel/screens/diesel_list_screen.dart';
import '../../features/drivers/screens/drivers_screen.dart';
import '../../features/external_trips/screens/external_trips_list_screen.dart';
import '../../features/notifications/screens/notification_list_screen.dart';
import '../../features/owners/screens/owners_screen.dart';
import '../../features/repairs/screens/repair_list_screen.dart';
import '../../features/sessions/screens/sessions_screen.dart';
import '../../features/settings_admin/screens/settings_screen.dart';
import '../../features/system/providers/maintenance_provider.dart';
import '../../features/system/screens/maintenance_screen.dart';
import '../../features/technicians/screens/technicians_screen.dart';
import '../../features/vehicles/screens/vehicles_screen.dart';
import '../../features/warranty/screens/warranty_screen.dart';

/// Bridges Riverpod auth + maintenance state changes to GoRouter's
/// Listenable refresh.
class _AppStateListener extends ChangeNotifier {
  _AppStateListener(Ref ref) {
    ref.listen(authProvider, (_, _) => notifyListeners());
    ref.listen(maintenanceStatusProvider, (_, _) => notifyListeners());
  }
}

/// Exposed so [PushService] can navigate to a notification's deep link from
/// a background/terminated push tap, where no BuildContext is otherwise
/// available.
final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final listener = _AppStateListener(ref);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/dashboard',
    refreshListenable: listener,
    // Records screen navigation as breadcrumbs so a captured error shows
    // the path the user took to get there.
    observers: [SentryNavigatorObserver()],
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
        builder: (context, state) {
          final vehicleId = int.tryParse(
            state.uri.queryParameters['vehicle_id'] ?? '',
          );
          return DieselListScreen(initialVehicleId: vehicleId);
        },
      ),
      GoRoute(
        path: '/external-trips',
        builder: (context, state) {
          final vehicleId = int.tryParse(
            state.uri.queryParameters['vehicle_id'] ?? '',
          );
          return ExternalTripsListScreen(initialVehicleId: vehicleId);
        },
      ),
      GoRoute(
        path: '/repair-records',
        builder: (context, state) {
          final vehicleId = int.tryParse(
            state.uri.queryParameters['vehicle_id'] ?? '',
          );
          return RepairListScreen(initialVehicleId: vehicleId);
        },
      ),
      GoRoute(
        path: '/vehicles',
        builder: (context, state) => const VehiclesScreen(),
      ),
      GoRoute(
        path: '/drivers',
        builder: (context, state) => const DriversScreen(),
      ),
      GoRoute(
        path: '/technicians',
        builder: (context, state) => const TechniciansScreen(),
      ),
      GoRoute(
        path: '/vehicle-owners',
        builder: (context, state) => const OwnersScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationListScreen(),
      ),
      GoRoute(
        path: '/activity-log',
        builder: (context, state) => const ActivityLogScreen(),
      ),
      GoRoute(
        path: '/warranty',
        builder: (context, state) => const WarrantyScreen(),
      ),
      GoRoute(
        path: '/sessions',
        builder: (context, state) => const SessionsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
