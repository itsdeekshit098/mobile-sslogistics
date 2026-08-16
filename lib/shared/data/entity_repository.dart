import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../models/api_response.dart';
import 'entity_models.dart';

class EntityListData {
  final List<Entity> entities;
  final int total;

  const EntityListData({required this.entities, required this.total});
}

class EntityRepository {
  Dio get _dio => DioClient.dio;

  /// Unpaginated fetch (up to 1000 rows) for pickers — loans, fundings,
  /// deployment forms. Pass [page] to opt into the paginated envelope
  /// instead, for the full Firms & Owners list screen.
  Future<List<Entity>> fetchAll({String? entityKind, bool activeOnly = true}) async {
    final query = <String, dynamic>{};
    if (activeOnly) query['is_active'] = 'true';
    if (entityKind != null) query['entity_kind'] = entityKind;

    final response = await _dio.get(ApiConstants.entities, queryParameters: query);
    final data = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to load entities',
    );
    return (data['data'] as List<dynamic>? ?? [])
        .map((e) => Entity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<EntityListData> fetchPage({
    required int page,
    required int pageSize,
    String search = '',
    String? entityKind,
    String? relationship,
    bool withCounts = true,
  }) async {
    final response = await _dio.get(
      ApiConstants.entities,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (search.isNotEmpty) 'search': search,
        if (entityKind != null) 'entity_kind': entityKind,
        if (relationship != null) 'relationship': relationship,
        if (withCounts) 'with_counts': 'true',
      },
    );
    final data = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to load entities',
    );
    final list = (data['data'] as List<dynamic>? ?? [])
        .map((e) => Entity.fromJson(e as Map<String, dynamic>))
        .toList();
    return EntityListData(entities: list, total: data['total'] as int? ?? list.length);
  }

  Future<Entity> create({
    required String name,
    required String entityKind,
    String relationship = 'INTERNAL',
    int? proprietorEntityId,
    String? phone,
    String? email,
    String? pan,
    String? gstNumber,
    String? address,
    String? notes,
  }) async {
    final response = await _dio.post(
      ApiConstants.entities,
      data: {
        'name': name,
        'entity_kind': entityKind,
        'relationship': relationship,
        'proprietor_entity_id': proprietorEntityId,
        'phone': phone,
        'email': email,
        'pan': pan,
        'gst_number': gstNumber,
        'address': address,
        'notes': notes,
      },
    );
    final data = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to add entity',
    );
    return Entity.fromJson(data['entity'] as Map<String, dynamic>);
  }

  Future<Entity> update({
    required int id,
    String? name,
    String? entityKind,
    String? relationship,
    int? proprietorEntityId,
    bool clearProprietor = false,
    String? phone,
    String? email,
    String? pan,
    String? gstNumber,
    String? address,
    String? notes,
  }) async {
    final response = await _dio.put(
      ApiConstants.entities,
      data: {
        'id': id,
        if (name != null) 'name': name,
        if (entityKind != null) 'entity_kind': entityKind,
        if (relationship != null) 'relationship': relationship,
        if (proprietorEntityId != null || clearProprietor)
          'proprietor_entity_id': clearProprietor ? null : proprietorEntityId,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (pan != null) 'pan': pan,
        if (gstNumber != null) 'gst_number': gstNumber,
        if (address != null) 'address': address,
        if (notes != null) 'notes': notes,
      },
    );
    final data = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to update entity',
    );
    return Entity.fromJson(data['entity'] as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    final response = await _dio.delete(ApiConstants.entities, queryParameters: {'id': id});
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to delete entity');
  }
}
