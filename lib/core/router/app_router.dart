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
import '../../features/trip_bookings/screens/trip_bookings_list_screen.dart';
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

/// Most feature routes are reached via `context.go` (replacement, not push),
/// which leaves nothing on the Navigator's pop stack — without this, the
/// Android system back button exits the app from any screen instead of
/// returning to the dashboard. But some of these same routes are also
/// reached via `context.push` (e.g. the notification bell icon, or tapping
/// a push notification via PushService) — in that case there IS something
/// to pop, and it must pop normally or back-navigation breaks. So this only
/// traps the back gesture when the Navigator can't already pop.
Widget _backToDashboard(BuildContext context, Widget child) => PopScope(
      canPop: Navigator.canPop(context),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !Navigator.canPop(context)) context.go('/dashboard');
      },
      child: child,
    );

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
        // A trap by design: maintenance-mode users shouldn't be able to
        // back out to whatever screen they were on before it kicked in.
        builder: (context, state) => PopScope(
          canPop: false,
          child: MaintenanceScreen(
            message: ref.read(maintenanceStatusProvider).message,
          ),
        ),
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
          return _backToDashboard(
            context,
            DieselListScreen(initialVehicleId: vehicleId),
          );
        },
      ),
      GoRoute(
        path: '/external-trips',
        builder: (context, state) {
          final vehicleId = int.tryParse(
            state.uri.queryParameters['vehicle_id'] ?? '',
          );
          return _backToDashboard(
            context,
            ExternalTripsListScreen(initialVehicleId: vehicleId),
          );
        },
      ),
      GoRoute(
        path: '/repair-records',
        builder: (context, state) {
          final vehicleId = int.tryParse(
            state.uri.queryParameters['vehicle_id'] ?? '',
          );
          return _backToDashboard(
            context,
            RepairListScreen(initialVehicleId: vehicleId),
          );
        },
      ),
      GoRoute(
        path: '/trip-bookings',
        builder: (context, state) =>
            _backToDashboard(context, const TripBookingsListScreen()),
      ),
      GoRoute(
        path: '/vehicles',
        builder: (context, state) =>
            _backToDashboard(context, const VehiclesScreen()),
      ),
      GoRoute(
        path: '/drivers',
        builder: (context, state) =>
            _backToDashboard(context, const DriversScreen()),
      ),
      GoRoute(
        path: '/technicians',
        builder: (context, state) =>
            _backToDashboard(context, const TechniciansScreen()),
      ),
      GoRoute(
        path: '/vehicle-owners',
        builder: (context, state) =>
            _backToDashboard(context, const OwnersScreen()),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) =>
            _backToDashboard(context, const NotificationListScreen()),
      ),
      GoRoute(
        path: '/activity-log',
        builder: (context, state) =>
            _backToDashboard(context, const ActivityLogScreen()),
      ),
      GoRoute(
        path: '/warranty',
        builder: (context, state) =>
            _backToDashboard(context, const WarrantyScreen()),
      ),
      GoRoute(
        path: '/sessions',
        builder: (context, state) =>
            _backToDashboard(context, const SessionsScreen()),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) =>
            _backToDashboard(context, const SettingsScreen()),
      ),
    ],
  );
});
