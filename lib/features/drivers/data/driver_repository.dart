import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/api_response.dart';
import 'driver_models.dart';

class DriverRepository {
  Dio get _dio => DioClient.dio;

  Future<DriverListData> getDrivers({
    int page = 1,
    int pageSize = 20,
    String search = '',
    bool includeInactive = false,
  }) async {
    final response = await _dio.get(
      ApiConstants.drivers,
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
        if (search.isNotEmpty) 'search': search,
        if (includeInactive) 'include_inactive': true,
      },
    );

    final outer = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to fetch drivers',
    );
    final list = outer['data'] as List;
    return DriverListData(
      drivers: list.map((e) => Driver.fromJson(e as Map<String, dynamic>)).toList(),
      total: outer['total'] as int? ?? list.length,
    );
  }

  Future<void> createDriver(CreateDriverDto dto) async {
    final response = await _dio.post(ApiConstants.drivers, data: dto.toJson());
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to create driver');
  }

  Future<void> updateDriver(UpdateDriverDto dto) async {
    final response = await _dio.put(ApiConstants.drivers, data: dto.toJson());
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to update driver');
  }

  Future<void> deleteDriver(int id) async {
    final response = await _dio.delete(
      ApiConstants.drivers,
      queryParameters: {'id': id},
    );
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to delete driver');
  }
}
