import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import 'repair_models.dart';

class RepairRepository {
  Dio get _dio => DioClient.dio;

  Future<RepairListData> getRecords({
    RepairFilters filters = const RepairFilters(),
    int page = 1,
    int pageSize = 10,
    bool includeSummary = true,
  }) async {
    final response = await _dio.get(
      ApiConstants.repairRecords,
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
        'include_summary': includeSummary,
        ...filters.toQueryParams(),
      },
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      final outer = response.data['data'];
      final list = outer['data'] as List;
      final total = outer['total'] as int? ?? list.length;
      final rawSummary = outer['summary'] as Map<String, dynamic>?;
      return RepairListData(
        records: list
            .map((e) => RepairRecord.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: total,
        summary: rawSummary != null ? RepairSummary.fromJson(rawSummary) : null,
      );
    }

    throw Exception(response.data['error'] ?? 'Failed to fetch repair records');
  }

  Future<int> createRecord(CreateRepairDto dto) async {
    final response = await _dio.post(
      ApiConstants.repairRecords,
      data: dto.toJson(),
    );

    if (response.statusCode == 201 && response.data['success'] == true) {
      return response.data['data']['id'] as int;
    }

    throw Exception(response.data['error'] ?? 'Failed to create repair record');
  }

  Future<void> updateRecord(UpdateRepairDto dto) async {
    final response = await _dio.put(
      ApiConstants.repairRecords,
      data: dto.toJson(),
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      return;
    }

    throw Exception(response.data['error'] ?? 'Failed to update repair record');
  }

  Future<void> deleteRecord(int id) async {
    final response = await _dio.delete(
      ApiConstants.repairRecords,
      queryParameters: {'id': id},
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      return;
    }

    throw Exception(response.data['error'] ?? 'Failed to delete repair record');
  }

  Future<Map<String, List<String>>> getIssueOptions() async {
    final response = await _dio.get(ApiConstants.repairIssues);

    if (response.statusCode == 200 && response.data['success'] == true) {
      final data = response.data['data'] as Map<String, dynamic>;
      return {
        repairCategoryElectrical:
            (data['electrical'] as List?)?.whereType<String>().toList() ??
                const [],
        repairCategoryMechanical:
            (data['mechanical'] as List?)?.whereType<String>().toList() ??
                const [],
      };
    }

    throw Exception(response.data['error'] ?? 'Failed to fetch issue options');
  }

  /// Returns null if the option already exists (409) so the caller can just
  /// select the existing value instead of surfacing an error.
  Future<String?> addIssueOption(String category, String name) async {
    final response = await _dio.post(
      ApiConstants.repairIssues,
      data: {'category': category, 'name': name},
    );

    if (response.statusCode == 201 && response.data['success'] == true) {
      return name;
    }
    if (response.statusCode == 409) return null;

    throw Exception(response.data['error'] ?? 'Failed to add issue option');
  }

  Future<List<PartOption>> getPartOptions({String? search, int limit = 100}) async {
    final response = await _dio.get(
      ApiConstants.partOptions,
      queryParameters: {
        'limit': limit,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      final list = response.data['data']['data'] as List;
      return list
          .map((e) => PartOption.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    throw Exception(response.data['error'] ?? 'Failed to fetch part options');
  }

  /// Returns null if the option already exists (409).
  Future<PartOption?> addPartOption(String name) async {
    final response = await _dio.post(
      ApiConstants.partOptions,
      data: {'name': name},
    );

    if (response.statusCode == 201 && response.data['success'] == true) {
      return PartOption.fromJson(
        response.data['data']['partOption'] as Map<String, dynamic>,
      );
    }
    if (response.statusCode == 409) return null;

    throw Exception(response.data['error'] ?? 'Failed to add part option');
  }

  Future<List<Technician>> getTechnicians() async {
    final response = await _dio.get(
      ApiConstants.technicians,
      queryParameters: {'include_inactive': true, 'pageSize': 1000},
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      final list = response.data['data']['data'] as List;
      return list
          .map((e) => Technician.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    throw Exception(response.data['error'] ?? 'Failed to fetch technicians');
  }

  Future<List<Vendor>> getVendors() async {
    final response = await _dio.get(
      ApiConstants.vendors,
      queryParameters: {'pageSize': 100},
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      final list = response.data['data']['data'] as List;
      return list.map((e) => Vendor.fromJson(e as Map<String, dynamic>)).toList();
    }

    throw Exception(response.data['error'] ?? 'Failed to fetch vendors');
  }

  Future<Vendor> addVendor({required String name, String? phone, String? location}) async {
    final response = await _dio.post(
      ApiConstants.vendors,
      data: {
        'name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (location != null && location.isNotEmpty) 'location': location,
      },
    );

    if (response.statusCode == 201 && response.data['success'] == true) {
      return Vendor.fromJson(response.data['data'] as Map<String, dynamic>);
    }

    throw Exception(response.data['error'] ?? 'Failed to add vendor');
  }
}
