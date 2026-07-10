/// Data models for GET/PUT /api/admin/settings/maintenance and
/// /api/admin/settings/app-version.
class MaintenanceSettings {
  final bool maintenanceMode;
  final String message;

  const MaintenanceSettings({required this.maintenanceMode, required this.message});

  factory MaintenanceSettings.fromJson(Map<String, dynamic> json) => MaintenanceSettings(
        maintenanceMode: json['maintenanceMode'] as bool? ?? false,
        message: json['message'] as String? ?? '',
      );
}

class AppVersionSettings {
  final int? minAndroidVersionCode;
  final String message;

  const AppVersionSettings({this.minAndroidVersionCode, required this.message});

  factory AppVersionSettings.fromJson(Map<String, dynamic> json) => AppVersionSettings(
        minAndroidVersionCode: json['minAndroidVersionCode'] as int?,
        message: json['forceUpdateMessage'] as String? ?? '',
      );
}
