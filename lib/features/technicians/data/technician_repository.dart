import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/api_response.dart';
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

    final outer = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to fetch technicians',
    );
    final list = outer['data'] as List;
    return TechnicianListData(
      technicians: list.map((e) => Technician.fromJson(e as Map<String, dynamic>)).toList(),
      total: outer['total'] as int? ?? list.length,
    );
  }

  Future<void> createTechnician(CreateTechnicianDto dto) async {
    final response = await _dio.post(ApiConstants.technicians, data: dto.toJson());
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to create technician');
  }

  Future<void> updateTechnician(UpdateTechnicianDto dto) async {
    final response = await _dio.put(ApiConstants.technicians, data: dto.toJson());
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to update technician');
  }

  Future<void> deleteTechnician(int id) async {
    final response = await _dio.delete(
      ApiConstants.technicians,
      queryParameters: {'id': id},
    );
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to delete technician');
  }

  Future<List<SpecializationOption>> getSpecializations() async {
    final response = await _dio.get(ApiConstants.specializations);
    final list = unwrapResponse<List>(
      response,
      fallbackError: 'Failed to fetch specializations',
    );
    return list.map((e) => SpecializationOption.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<SpecializationOption> createSpecialization(String name) async {
    final response = await _dio.post(ApiConstants.specializations, data: {'name': name});
    final data = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to add specialization',
    );
    return SpecializationOption.fromJson(data['specialization'] as Map<String, dynamic>);
  }
}
