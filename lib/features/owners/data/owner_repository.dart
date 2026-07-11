import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/api_response.dart';
import 'owner_models.dart';

class OwnerRepository {
  Dio get _dio => DioClient.dio;

  /// Passing `page` opts into the paginated `{data, total}` envelope; omitting
  /// it (as the web app's dropdown callers do) gets the legacy bare array.
  Future<OwnerListData> getOwners({
    int page = 1,
    int pageSize = 20,
    String? ownerType,
    String search = '',
  }) async {
    final response = await _dio.get(
      ApiConstants.vehicleOwners,
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
        if (ownerType != null && ownerType.isNotEmpty) 'owner_type': ownerType,
        if (search.isNotEmpty) 'search': search,
      },
    );

    final outer = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to fetch owners',
    );
    final list = outer['data'] as List;
    return OwnerListData(
      owners: list.map((e) => VehicleOwner.fromJson(e as Map<String, dynamic>)).toList(),
      total: outer['total'] as int? ?? list.length,
    );
  }

  Future<void> createOwner(CreateOwnerDto dto) async {
    final response = await _dio.post(ApiConstants.vehicleOwners, data: dto.toJson());
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to create owner');
  }

  Future<void> updateOwner(UpdateOwnerDto dto) async {
    final response = await _dio.put(ApiConstants.vehicleOwners, data: dto.toJson());
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to update owner');
  }

  Future<void> deleteOwner(int id) async {
    final response = await _dio.delete(
      ApiConstants.vehicleOwners,
      queryParameters: {'id': id},
    );
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to delete owner');
  }
}
