import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/models/vehicle_model.dart';
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
        if (vehicleId != null) 'vehicle_id': vehicleId,
      },
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      final outer = response.data['data'];
      // API returns { data: { data: [...], total: N } }
      final list = outer['data'] as List;
      final total = outer['total'] as int? ?? list.length;
      return DieselListData(
        records: list
            .map((e) => DieselRecord.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: total,
      );
    }

    throw Exception(
        response.data['error'] ?? 'Failed to fetch diesel records');
  }

  Future<void> createRecord(CreateDieselDto dto) async {
    final response = await _dio.post(
      ApiConstants.dieselRecords,
      data: dto.toJson(),
    );

    if (response.statusCode == 201 && response.data['success'] == true) {
      return;
    }

    throw Exception(
        response.data['error'] ?? 'Failed to create diesel record');
  }

  Future<void> updateRecord(UpdateDieselDto dto) async {
    final response = await _dio.put(
      ApiConstants.dieselRecords,
      data: dto.toJson(),
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      return;
    }

    throw Exception(
        response.data['error'] ?? 'Failed to update diesel record');
  }

  Future<void> deleteRecord(int id) async {
    final response = await _dio.delete(
      ApiConstants.dieselRecords,
      queryParameters: {'id': id},
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      return;
    }

    throw Exception(
        response.data['error'] ?? 'Failed to delete diesel record');
  }
}

class VehicleRepository {
  Dio get _dio => DioClient.dio;

  Future<List<Vehicle>> getVehicles() async {
    final response = await _dio.get(ApiConstants.vehicles);

    if (response.statusCode == 200 && response.data['success'] == true) {
      final data = response.data['data'];
      // Handle both flat list and paginated { data: [...] } shapes
      final list = data is List
          ? data
          : (data['data'] as List? ?? data as List);
      return list
          .map((e) => Vehicle.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    throw Exception('Failed to fetch vehicles');
  }
}
