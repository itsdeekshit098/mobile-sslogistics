import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../models/api_response.dart';
import 'lender_models.dart';

class LenderRepository {
  Dio get _dio => DioClient.dio;

  /// [lenderKind] filters to `'INSTITUTION'` (loan forms) or `'PRIVATE'`
  /// (funding forms) — a bank doesn't lend at a hand-agreed monthly rate, and
  /// mixing the two lists is how duplicate "HDFC" rows get created.
  Future<List<Lender>> fetchAll({String? lenderKind}) async {
    final query = <String, dynamic>{};
    if (lenderKind != null) query['lender_kind'] = lenderKind;

    final response = await _dio.get(ApiConstants.lenders, queryParameters: query);
    final data = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to load lenders',
    );
    return (data['data'] as List<dynamic>? ?? [])
        .map((e) => Lender.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Lender> create({
    required String name,
    required String lenderKind,
    String? phone,
    String? contactPerson,
  }) async {
    final response = await _dio.post(
      ApiConstants.lenders,
      data: {
        'name': name,
        'lender_kind': lenderKind,
        'phone': phone,
        'contact_person': contactPerson,
      },
    );
    final data = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to add lender',
    );
    return Lender.fromJson(data['lender'] as Map<String, dynamic>);
  }
}
