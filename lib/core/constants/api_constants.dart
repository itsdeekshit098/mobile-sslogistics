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
    static const String tripBookingsComplete = '/api/trip-bookings/complete';
  static const String repairRecords = '/api/repair-records';
  static const String repairIssues = '/api/repair-issues';
  static const String partOptions = '/api/part-options';
  static const String technicians = '/api/technicians';
  static const String specializations = '/api/specializations';
  static const String vendors = '/api/vendors';
  static const String locationsAutocomplete = '/api/locations/autocomplete';

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

  // ── Finance: loans, private fundings, client receivables ──────────────────
  // Admin/superadmin only — these routes gate every method, GET included.
  //
  // Unlike the resource endpoints above (single collection path, id in the
  // query or body), these follow the web's REST sub-paths, so they need path
  // builders. Note the page-size param here is `page_size`, not the `pageSize`
  // the older routes accept — sending the wrong one silently pins you to
  // page 1.
  static const String loans = '/api/loans';
  static const String loansCalendar = '/api/loans/calendar';
  static String loanById(int id) => '/api/loans/$id';
  static String loanPayments(int id) => '/api/loans/$id/payments';
  static String loanPaymentReverse(int loanId, int paymentId) =>
      '/api/loans/$loanId/payments/$paymentId/reverse';

  static const String fundings = '/api/fundings';
  static String fundingById(int id) => '/api/fundings/$id';
  static String fundingEntries(int id) => '/api/fundings/$id/entries';
  static String fundingRates(int id) => '/api/fundings/$id/rates';
  static String fundingEntryReverse(int fundingId, int entryId) =>
      '/api/fundings/$fundingId/entries/$entryId/reverse';

  static const String clients = '/api/clients';
  static String clientById(int id) => '/api/clients/$id';
  static String clientEntries(int id) => '/api/clients/$id/entries';
  static String clientContacts(int id) => '/api/clients/$id/contacts';
  static String clientDeployments(int id) => '/api/clients/$id/deployments';
  static String clientEntryReverse(int clientId, int entryId) =>
      '/api/clients/$clientId/entries/$entryId/reverse';

  static const String lenders = '/api/lenders';
  static const String entities = '/api/entities';
  static const String bankAccounts = '/api/bank-accounts';
  static const String lookups = '/api/lookups';

  static const String attachments = '/api/attachments';
  static const String attachmentView = '/api/attachments/view';
}
