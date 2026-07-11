import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/api_response.dart';
import 'warranty_models.dart';

final _isoFmt = DateFormat('yyyy-MM-dd');

class WarrantyRepository {
  Dio get _dio => DioClient.dio;

  Future<WarrantyPage> fetch({
    WarrantyFilters filters = const WarrantyFilters(),
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _dio.get(
      ApiConstants.warranty,
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
        if (filters.vehicleId != null) 'vehicle_id': filters.vehicleId,
        if (filters.vendorId != null) 'vendor_id': filters.vendorId,
        if (filters.status != null) 'status': filters.status,
        if (filters.fromDate != null) 'from_date': _isoFmt.format(filters.fromDate!),
        if (filters.toDate != null) 'to_date': _isoFmt.format(filters.toDate!),
        if (filters.search.isNotEmpty) 'search': filters.search,
      },
    );

    final outer = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to fetch warranty records',
    );
    final list = outer['data'] as List;
    final items = list.map((e) => WarrantyItem.fromJson(e as Map<String, dynamic>)).toList();
    return WarrantyPage(items: items, total: outer['total'] as int? ?? items.length);
  }

  Future<void> create(WarrantyDto dto) async {
    final response = await _dio.post(ApiConstants.warranty, data: dto.toJson());
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to create warranty record');
  }

  Future<void> update(WarrantyDto dto) async {
    final response = await _dio.put(ApiConstants.warranty, data: dto.toJson());
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to update warranty record');
  }

  Future<void> delete(int id) async {
    final response = await _dio.delete(ApiConstants.warranty, queryParameters: {'id': id});
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to delete warranty record');
  }
}
