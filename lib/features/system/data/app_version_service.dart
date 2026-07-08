import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import '../models/app_version_status.dart';

/// One-shot check against the public /api/system/app-version endpoint —
/// unlike maintenance mode, this doesn't need a persistent SSE connection
/// since it's only checked at app startup/resume, and must work even for a
/// user who isn't logged in yet.
class AppVersionService {
  Future<AppVersionConfig> fetch() async {
    final response = await DioClient.dio.get(ApiConstants.appVersion);
    final data = response.data;
    if (data is Map && data['success'] == true && data['data'] is Map) {
      return AppVersionConfig.fromJson(data['data'] as Map<String, dynamic>);
    }
    throw Exception('Failed to fetch app version config');
  }
}
