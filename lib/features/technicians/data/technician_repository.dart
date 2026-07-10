import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import 'technician_models.dart';

class TechnicianRepository {
  Dio get _dio => DioClient.dio;

  Future<TechnicianListData> getTechnicians({
    int page = 1,
    int pageSize = 20,
    String search = '',
    bool includeInactive = false,
  }) async {
    final response = await _dio.get(
      ApiConstants.technicians,
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
        if (search.isNotEmpty) 'search': search,
        if (includeInactive) 'include_inactive': true,
      },
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      final outer = response.data['data'] as Map<String, dynamic>;
      final list = outer['data'] as List;
      return TechnicianListData(
        technicians: list.map((e) => Technician.fromJson(e as Map<String, dynamic>)).toList(),
        total: outer['total'] as int? ?? list.length,
      );
    }

    throw Exception(response.data['error'] ?? 'Failed to fetch technicians');
  }

  Future<void> createTechnician(CreateTechnicianDto dto) async {
    final response = await _dio.post(ApiConstants.technicians, data: dto.toJson());
    if (response.statusCode == 201 && response.data['success'] == true) return;
    throw Exception(response.data['error'] ?? 'Failed to create technician');
  }

  Future<void> updateTechnician(UpdateTechnicianDto dto) async {
    final response = await _dio.put(ApiConstants.technicians, data: dto.toJson());
    if (response.statusCode == 200 && response.data['success'] == true) return;
    throw Exception(response.data['error'] ?? 'Failed to update technician');
  }

  Future<void> deleteTechnician(int id) async {
    final response = await _dio.delete(
      ApiConstants.technicians,
      queryParameters: {'id': id},
    );
    if (response.statusCode == 200 && response.data['success'] == true) return;
    throw Exception(response.data['error'] ?? 'Failed to delete technician');
  }

  Future<List<SpecializationOption>> getSpecializations() async {
    final response = await _dio.get(ApiConstants.specializations);
    if (response.statusCode == 200 && response.data['success'] == true) {
      final list = response.data['data'] as List;
      return list.map((e) => SpecializationOption.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception(response.data['error'] ?? 'Failed to fetch specializations');
  }

  Future<SpecializationOption> createSpecialization(String name) async {
    final response = await _dio.post(ApiConstants.specializations, data: {'name': name});
    if (response.statusCode == 201 && response.data['success'] == true) {
      final data = response.data['data'] as Map<String, dynamic>;
      return SpecializationOption.fromJson(data['specialization'] as Map<String, dynamic>);
    }
    throw Exception(response.data['error'] ?? 'Failed to add specialization');
  }
}
