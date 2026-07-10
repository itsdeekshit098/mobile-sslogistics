import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import 'settings_models.dart';

class SettingsRepository {
  Dio get _dio => DioClient.dio;

  Future<MaintenanceSettings> getMaintenance() async {
    final response = await _dio.get(ApiConstants.maintenanceSettings);
    if (response.statusCode == 200 && response.data['success'] == true) {
      return MaintenanceSettings.fromJson(response.data['data'] as Map<String, dynamic>);
    }
    throw Exception(response.data['error'] ?? 'Failed to fetch maintenance settings');
  }

  Future<void> updateMaintenance({required bool maintenanceMode, String? message}) async {
    final response = await _dio.put(
      ApiConstants.maintenanceSettings,
      data: {'maintenanceMode': maintenanceMode, 'message': message},
    );
    if (response.statusCode == 200 && response.data['success'] == true) return;
    throw Exception(response.data['error'] ?? 'Failed to update maintenance settings');
  }

  Future<AppVersionSettings> getAppVersion() async {
    final response = await _dio.get(ApiConstants.appVersionSettings);
    if (response.statusCode == 200 && response.data['success'] == true) {
      return AppVersionSettings.fromJson(response.data['data'] as Map<String, dynamic>);
    }
    throw Exception(response.data['error'] ?? 'Failed to fetch app version settings');
  }

  Future<void> updateAppVersion({int? minAndroidVersionCode, String? message}) async {
    // Built explicitly (not via a DTO's conditional toJson) so a null
    // minAndroidVersionCode still serializes as JSON null and clears the
    // server value, instead of being dropped from the request body.
    final response = await _dio.put(
      ApiConstants.appVersionSettings,
      data: {'minAndroidVersionCode': minAndroidVersionCode, 'message': message},
    );
    if (response.statusCode == 200 && response.data['success'] == true) return;
    throw Exception(response.data['error'] ?? 'Failed to update app version settings');
  }
}
