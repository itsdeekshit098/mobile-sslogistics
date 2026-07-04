import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import 'vehicle_models.dart';

class VehicleRepository {
  Dio get _dio => DioClient.dio;

  Future<VehicleListData> getVehicles({
    int page = 1,
    int pageSize = 10,
    String search = '',
    String type = 'all',
    String status = '',
    String ownerType = '',
    String ownerName = '',
    String fuelType = '',
  }) async {
    final response = await _dio.get(
      ApiConstants.vehicles,
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (type != 'all') 'type': type,
        if (status.isNotEmpty) 'status': status,
        if (ownerType.isNotEmpty) 'ownerType': ownerType,
        if (ownerName.isNotEmpty) 'ownerName': ownerName,
        if (fuelType.isNotEmpty) 'fuelType': fuelType,
      },
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      final data = response.data['data'] as Map<String, dynamic>? ?? {};
      final list = data['data'] as List? ?? const [];
      return VehicleListData(
        vehicles: list
            .map((item) => FleetVehicle.fromJson(item as Map<String, dynamic>))
            .toList(),
        total: data['total'] as int? ?? list.length,
        stats: VehicleStats.fromJson(data['stats'] as Map<String, dynamic>?),
      );
    }

    throw Exception(response.data['error'] ?? 'Failed to fetch vehicles');
  }

  Future<void> createVehicle(VehiclePayload payload) async {
    final response = await _dio.post(
      ApiConstants.vehicles,
      data: payload.toJson(),
    );
    if (response.statusCode == 201 && response.data['success'] == true) return;
    throw Exception(response.data['error'] ?? 'Failed to create vehicle');
  }

  Future<void> updateVehicle(VehiclePayload payload) async {
    final response = await _dio.put(
      ApiConstants.vehicles,
      data: payload.toJson(),
    );
    if (response.statusCode == 200 && response.data['success'] == true) return;
    throw Exception(response.data['error'] ?? 'Failed to update vehicle');
  }

  Future<void> updateVehicleField(int id, String field, String? value) async {
    final response = await _dio.put(
      ApiConstants.vehicles,
      data: {'id': id, field: value},
    );
    if (response.statusCode == 200 && response.data['success'] == true) return;
    throw Exception(response.data['error'] ?? 'Failed to update vehicle');
  }

  Future<void> deleteVehicle(int id) async {
    final response = await _dio.delete(
      ApiConstants.vehicles,
      queryParameters: {'id': id},
    );
    if (response.statusCode == 200 && response.data['success'] == true) return;
    throw Exception(response.data['error'] ?? 'Failed to delete vehicle');
  }

  Future<List<VehicleOwner>> getOwners({String? ownerType}) async {
    final response = await _dio.get(
      ApiConstants.vehicleOwners,
      queryParameters: {'owner_type': ?ownerType},
    );
    if (response.statusCode == 200 && response.data['success'] == true) {
      final list = response.data['data'] as List? ?? const [];
      return list
          .map((item) => VehicleOwner.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    throw Exception(response.data['error'] ?? 'Failed to fetch owners');
  }

  Future<VehicleOwner> createOwner({
    required String name,
    required String ownerType,
  }) async {
    final response = await _dio.post(
      ApiConstants.vehicleOwners,
      data: {'name': name.trim(), 'owner_type': ownerType},
    );
    if (response.statusCode == 201 && response.data['success'] == true) {
      final data = response.data['data'] as Map<String, dynamic>;
      return VehicleOwner.fromJson(data['owner'] as Map<String, dynamic>);
    }
    throw Exception(response.data['error'] ?? 'Failed to add owner');
  }

  Future<String> uploadDocument({
    required FleetVehicle vehicle,
    required String documentType,
    required String filePath,
  }) async {
    final file = File(filePath);
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path),
      'vehicleId': vehicle.id.toString(),
      'vehicleNumber': vehicle.vehicleNumber
          .replaceAll(RegExp(r'\s+'), '-')
          .toUpperCase(),
      'documentType': documentType,
    });

    final response = await _dio.post(
      ApiConstants.vehicleDocuments,
      data: formData,
      options: Options(headers: {'Content-Type': 'multipart/form-data'}),
    );

    if (response.statusCode == 201 && response.data['success'] == true) {
      final data = response.data['data'] as Map<String, dynamic>? ?? {};
      return data['filePath'] as String? ?? '';
    }
    throw Exception(response.data['error'] ?? 'Failed to upload document');
  }

  Future<void> deleteDocument({
    required int vehicleId,
    required String documentType,
    required String filePath,
  }) async {
    final response = await _dio.delete(
      ApiConstants.vehicleDocuments,
      data: {
        'vehicleId': vehicleId,
        'documentType': documentType,
        'filePath': filePath,
      },
    );

    if (response.statusCode == 200 && response.data['success'] == true) return;
    throw Exception(response.data['error'] ?? 'Failed to delete document');
  }

  Future<String> downloadDocument(String filePath, {String? fileName}) async {
    final dir = await getTemporaryDirectory();
    final savePath = '${dir.path}/${fileName ?? filePath.split('/').last}';

    final response = await _dio.download(
      ApiConstants.vehicleDocumentView,
      savePath,
      queryParameters: {'filePath': filePath, 'download': 'true'},
    );

    if ((response.statusCode ?? 500) < 300) return savePath;
    throw Exception('Failed to download document');
  }
}
