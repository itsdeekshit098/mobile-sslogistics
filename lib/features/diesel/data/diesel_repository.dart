import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/models/api_response.dart';
import 'diesel_models.dart';

class DieselRepository {
  Dio get _dio => DioClient.dio;

  Future<DieselListData> getRecords({
    int? vehicleId,
    int page = 1,
    int pageSize = 10,
  }) async {
    final response = await _dio.get(
      ApiConstants.dieselRecords,
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
        'vehicle_id': ?vehicleId,
      },
    );

    // API returns { data: { data: [...], total: N } }
    final outer = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to fetch diesel records',
    );
    final list = outer['data'] as List;
    final total = outer['total'] as int? ?? list.length;
    return DieselListData(
      records: list
          .map((e) => DieselRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: total,
    );
  }

  /// Returns any non-blocking warnings (e.g. tank-capacity checks) computed
  /// server-side for the newly created record.
  Future<List<String>> createRecord(CreateDieselDto dto) async {
    final response = await _dio.post(
      ApiConstants.dieselRecords,
      data: dto.toJson(),
    );

    final data = unwrapResponse<Map<String, dynamic>?>(
      response,
      fallbackError: 'Failed to create diesel record',
    );
    return (data?['warnings'] as List?)?.whereType<String>().toList() ??
        const <String>[];
  }

  Future<void> updateRecord(UpdateDieselDto dto) async {
    final response = await _dio.put(
      ApiConstants.dieselRecords,
      data: dto.toJson(),
    );

    unwrapResponse<dynamic>(response, fallbackError: 'Failed to update diesel record');
  }

  Future<void> deleteRecord(int id) async {
    final response = await _dio.delete(
      ApiConstants.dieselRecords,
      queryParameters: {'id': id},
    );

    unwrapResponse<dynamic>(response, fallbackError: 'Failed to delete diesel record');
  }
}
