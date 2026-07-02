import 'dart:io';

class ApiConstants {
  /// Base URL switches between Android emulator and iOS simulator automatically.
  /// Replace with the production HTTPS URL before going live.
  static String get baseUrl {
    if (Platform.isAndroid) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000';
    // return 'https://sslogistics-hqs96351g-deekshiths-projects-eaba341b.vercel.app/';
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
}
