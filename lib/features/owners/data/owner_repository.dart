import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import 'owner_models.dart';

class OwnerRepository {
  Dio get _dio => DioClient.dio;

  /// Bare array response (no pagination), capped at 1000 server-side.
  Future<List<VehicleOwner>> getOwners({String? ownerType, String search = ''}) async {
    final response = await _dio.get(
      ApiConstants.vehicleOwners,
      queryParameters: {
        if (ownerType != null && ownerType.isNotEmpty) 'owner_type': ownerType,
        if (search.isNotEmpty) 'search': search,
      },
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      final list = response.data['data'] as List;
      return list.map((e) => VehicleOwner.fromJson(e as Map<String, dynamic>)).toList();
    }

    throw Exception(response.data['error'] ?? 'Failed to fetch owners');
  }

  Future<void> createOwner(CreateOwnerDto dto) async {
    final response = await _dio.post(ApiConstants.vehicleOwners, data: dto.toJson());
    if (response.statusCode == 201 && response.data['success'] == true) return;
    throw Exception(response.data['error'] ?? 'Failed to create owner');
  }

  Future<void> updateOwner(UpdateOwnerDto dto) async {
    final response = await _dio.put(ApiConstants.vehicleOwners, data: dto.toJson());
    if (response.statusCode == 200 && response.data['success'] == true) return;
    throw Exception(response.data['error'] ?? 'Failed to update owner');
  }

  Future<void> deleteOwner(int id) async {
    final response = await _dio.delete(
      ApiConstants.vehicleOwners,
      queryParameters: {'id': id},
    );
    if (response.statusCode == 200 && response.data['success'] == true) return;
    throw Exception(response.data['error'] ?? 'Failed to delete owner');
  }
}
