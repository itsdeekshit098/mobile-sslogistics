import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/api_response.dart';
import '../../../shared/state/paged_result.dart';
import 'funding_models.dart';

class FundingRepository {
  Dio get _dio => DioClient.dio;

  Future<PagedResult<Funding, FundingSummary?>> fetchFundings({
    required int page,
    required int pageSize,
    required String search,
    required FundingFilters filters,
    bool includeSummary = false,
  }) async {
    // Server-paginated, matching loans/clients — a plain page/pageSize
    // request without these was silently capped at the server's own default
    // page size (10), truncating the list rather than showing it in full.
    // /api/fundings has no server-side search (it doesn't index the
    // embedded funder/borrower/counterparty names), so `search` is still
    // applied client-side, scoped to whatever page came back.
    final response = await _dio.get(
      ApiConstants.fundings,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        'direction': filters.direction,
        'sort': filters.sort,
        if (filters.status != null) 'status': filters.status,
        if (filters.funderId != null) 'funder_id': filters.funderId,
        if (includeSummary) 'include_summary': 'true',
      },
    );
    final data = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to load fundings',
    );
    final items = (data['data'] as List<dynamic>? ?? [])
        .map((e) => Funding.fromJson(e as Map<String, dynamic>))
        .toList();

    final filtered = search.isEmpty
        ? items
        : items
            .where((f) =>
                (f.funder?.name.toLowerCase().contains(search.toLowerCase()) ?? false) ||
                (f.borrower?.name.toLowerCase().contains(search.toLowerCase()) ?? false) ||
                (f.counterparty?.name.toLowerCase().contains(search.toLowerCase()) ?? false))
            .toList();

    return PagedResult<Funding, FundingSummary?>(
      items: filtered,
      total: data['total'] as int? ?? filtered.length,
      extras: data['summary'] != null
          ? FundingSummary.fromJson(data['summary'] as Map<String, dynamic>)
          : null,
    );
  }

  Future<FundingDetail> fetchFunding(int id) async {
    final response = await _dio.get(ApiConstants.fundingById(id));
    final data = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to load funding',
    );
    return FundingDetail.fromJson(data);
  }

  Future<int> createFunding(FundingDto dto) async {
    final response = await _dio.post(ApiConstants.fundings, data: dto.toJson());
    final data = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to create funding',
    );
    return (data['funding'] as Map<String, dynamic>)['id'] as int;
  }

  Future<void> updateFunding(int id, Map<String, dynamic> fields) async {
    final response = await _dio.put(ApiConstants.fundings, data: {'id': id, ...fields});
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to update funding');
  }

  Future<void> settleFunding(int id) async {
    await updateFunding(id, {'status': 'SETTLED'});
  }

  Future<void> deleteFunding(int id) async {
    final response =
        await _dio.delete(ApiConstants.fundings, queryParameters: {'id': id});
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to delete funding');
  }

  Future<void> recordEntry({
    required int fundingId,
    required String entryType,
    required num amount,
    required String entryDate,
    String? paymentMethod,
    String? reference,
    String? description,
  }) async {
    final response = await _dio.post(
      ApiConstants.fundingEntries(fundingId),
      data: {
        'entry_type': entryType,
        'amount': amount,
        'entry_date': entryDate,
        'payment_method': paymentMethod,
        'reference': reference,
        'description': description,
      },
    );
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to record entry');
  }

  Future<void> reverseEntry({
    required int fundingId,
    required int entryId,
    String? reason,
  }) async {
    final response = await _dio.post(
      ApiConstants.fundingEntryReverse(fundingId, entryId),
      data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to reverse entry');
  }

  /// Records a renegotiated rate, effective from a given date onward. Never
  /// edits a past rate row — interest already accrued keeps the rate that
  /// was actually in force.
  Future<void> changeRate({
    required int fundingId,
    required String effectiveFrom,
    num? roi,
    String? roiBasis,
    num? fixedInterestAmount,
    String? note,
  }) async {
    final response = await _dio.post(
      ApiConstants.fundingRates(fundingId),
      data: {
        'effective_from': effectiveFrom,
        'roi': roi,
        'roi_basis': roiBasis,
        'fixed_interest_amount': fixedInterestAmount,
        'note': note,
      },
    );
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to change rate');
  }
}
