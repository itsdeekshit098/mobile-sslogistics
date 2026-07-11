import 'dart:io';

import 'package:flutter/foundation.dart' show kReleaseMode;

class ApiConstants {
  /// Override via `--dart-define=API_BASE_URL=https://...` (e.g. from
  /// scripts/build_release.sh). Takes priority over everything below.
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// An explicit --dart-define wins; otherwise release builds always point
  /// at production (so forgetting a flag can never ship pointed at
  /// localhost), and debug/profile builds switch between the Android
  /// emulator and iOS simulator loopback addresses automatically.
  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    if (kReleaseMode) return 'https://sslogistics.vercel.app';
    if (Platform.isAndroid) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000';
  }

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const String login = '/api/auth/login';
  static const String logout = '/api/auth/signout';
  static const String session = '/api/auth/session';

  // ── Resources ─────────────────────────────────────────────────────────────
  static const String vehicles = '/api/vehicles';
  static const String vehicleDocuments = '/api/vehicles/documents';
  static const String vehicleDocumentView = '/api/vehicles/documents/view';
  static const String vehicleOwners = '/api/vehicle-owners';
  static const String drivers = '/api/drivers';
  static const String dieselRecords = '/api/diesel-records';
  static const String externalTrips = '/api/external-trips';
  static const String tripBookings = '/api/trip-bookings';
  static const String repairRecords = '/api/repair-records';
  static const String repairIssues = '/api/repair-issues';
  static const String partOptions = '/api/part-options';
  static const String technicians = '/api/technicians';
  static const String specializations = '/api/specializations';
  static const String vendors = '/api/vendors';

  // ── Notifications ─────────────────────────────────────────────────────────
  static const String notifications = '/api/notifications';
  static const String notificationsMarkRead = '/api/notifications/mark-read';
  static const String notificationsMarkAllRead =
      '/api/notifications/mark-all-read';
  static const String notificationsRegisterDevice =
      '/api/notifications/register-device';
  static const String notificationsStream = '/api/notifications/stream';

  // ── System ────────────────────────────────────────────────────────────────
  static const String maintenanceStream = '/api/system/maintenance-stream';
  static const String appVersion = '/api/system/app-version';

  // ── Admin ─────────────────────────────────────────────────────────────────
  static const String adminSessions = '/api/admin/sessions';
  static const String maintenanceSettings = '/api/admin/settings/maintenance';
  static const String appVersionSettings = '/api/admin/settings/app-version';
  static const String activityLog = '/api/activity-log';
  static const String warranty = '/api/warranty';
}
