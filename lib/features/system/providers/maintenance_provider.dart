import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../data/maintenance_stream_service.dart';
import '../models/maintenance_status.dart';

/// Live maintenance-mode status, kept up to date by an SSE stream (near-
/// instant) plus a fallback that reacts to any single API call coming back
/// 503 MAINTENANCE_MODE (in case the stream hasn't caught up yet, or is
/// blocked by a restrictive network). GoRouter's redirect reads this to
/// send non-admins to the maintenance screen — see app_router.dart.
final maintenanceStatusProvider =
    NotifierProvider<MaintenanceNotifier, MaintenanceStatus>(
        MaintenanceNotifier.new);

class MaintenanceNotifier extends Notifier<MaintenanceStatus> {
  final _service = MaintenanceStreamService();

  @override
  MaintenanceStatus build() {
    _service.onStatus = (status) => state = status;
    _service.start();
    DioClient.onMaintenanceDetected =
        (message) => state = MaintenanceStatus(maintenanceMode: true, message: message);

    ref.onDispose(() {
      _service.dispose();
      DioClient.onMaintenanceDetected = null;
    });

    return const MaintenanceStatus(maintenanceMode: false, message: null);
  }
}
