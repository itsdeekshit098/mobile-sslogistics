import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/api_response.dart';
import 'activity_log_models.dart';

class ActivityLogRepository {
  Dio get _dio => DioClient.dio;

  Future<ActivityLogPage> getEntries({int page = 1, int limit = 20}) async {
    final response = await _dio.get(
      ApiConstants.activityLog,
      queryParameters: {'page': page, 'limit': limit},
    );

    final outer = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to fetch activity log',
    );
    final list = outer['data'] as List;
    final entries = list
        .map((e) => ActivityLogEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    return ActivityLogPage(
      entries: entries,
      total: outer['total'] as int? ?? entries.length,
      page: outer['page'] as int? ?? page,
      limit: outer['limit'] as int? ?? limit,
      totalPages: outer['totalPages'] as int? ?? 1,
    );
  }
}
