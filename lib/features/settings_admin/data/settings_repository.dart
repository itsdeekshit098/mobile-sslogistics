import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/api_response.dart';
import 'settings_models.dart';

class SettingsRepository {
  Dio get _dio => DioClient.dio;

  Future<MaintenanceSettings> getMaintenance() async {
    final response = await _dio.get(ApiConstants.maintenanceSettings);
    final data = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to fetch maintenance settings',
    );
    return MaintenanceSettings.fromJson(data);
  }

  Future<void> updateMaintenance({required bool maintenanceMode, String? message}) async {
    final response = await _dio.put(
      ApiConstants.maintenanceSettings,
      data: {'maintenanceMode': maintenanceMode, 'message': message},
    );
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to update maintenance settings');
  }

  Future<AppVersionSettings> getAppVersion() async {
    final response = await _dio.get(ApiConstants.appVersionSettings);
    final data = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to fetch app version settings',
    );
    return AppVersionSettings.fromJson(data);
  }

  Future<void> updateAppVersion({int? minAndroidVersionCode, String? message}) async {
    // Built explicitly (not via a DTO's conditional toJson) so a null
    // minAndroidVersionCode still serializes as JSON null and clears the
    // server value, instead of being dropped from the request body.
    final response = await _dio.put(
      ApiConstants.appVersionSettings,
      data: {'minAndroidVersionCode': minAndroidVersionCode, 'message': message},
    );
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to update app version settings');
  }
}
