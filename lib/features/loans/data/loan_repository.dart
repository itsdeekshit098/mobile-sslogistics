import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/api_response.dart';
import '../../../shared/state/paged_result.dart';
import 'loan_models.dart';

/// Talks to `/api/loans` and its sub-paths. Every method is admin/superadmin
/// only server-side (`requireStrictAdminAuth`, GET included) — a 401/403 here
/// surfaces as an [ApiException] like any other failure, there's nothing
/// loan-specific to handle beyond that.
class LoanRepository {
  Dio get _dio => DioClient.dio;

  Future<PagedResult<Loan, LoanSummary?>> fetchLoans({
    required int page,
    required int pageSize,
    required String search,
    required LoanFilters filters,
    bool includeSummary = false,
  }) async {
    final response = await _dio.get(
      ApiConstants.loans,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (search.isNotEmpty) 'search': search,
        if (filters.status != null) 'status': filters.status,
        if (filters.loanType != null) 'loan_type': filters.loanType,
        if (filters.borrowerEntityId != null)
          'borrower_entity_id': filters.borrowerEntityId,
        if (filters.lenderId != null) 'lender_id': filters.lenderId,
        if (filters.overdueOnly) 'overdue_only': 'true',
        if (includeSummary) 'include_summary': 'true',
      },
    );

    final data = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to load loans',
    );

    final items = (data['data'] as List<dynamic>? ?? [])
        .map((e) => Loan.fromJson(e as Map<String, dynamic>))
        .toList();

    return PagedResult<Loan, LoanSummary?>(
      items: items,
      total: data['total'] as int? ?? items.length,
      extras: data['summary'] != null
          ? LoanSummary.fromJson(data['summary'] as Map<String, dynamic>)
          : null,
    );
  }

  Future<LoanDetail> fetchLoan(int id) async {
    final response = await _dio.get(ApiConstants.loanById(id));
    final data = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to load loan',
    );
    return LoanDetail.fromJson(data);
  }

  Future<int> createLoan(LoanDto dto) async {
    final response = await _dio.post(ApiConstants.loans, data: dto.toJson());
    final data = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to create loan',
    );
    return (data['loan'] as Map<String, dynamic>)['id'] as int;
  }

  Future<void> updateLoan(int id, Map<String, dynamic> fields) async {
    final response = await _dio.put(
      ApiConstants.loans,
      data: {'id': id, ...fields},
    );
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to update loan');
  }

  Future<void> deleteLoan(int id) async {
    final response = await _dio.delete(
      ApiConstants.loans,
      queryParameters: {'id': id},
    );
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to delete loan');
  }

  /// Records an EMI settled / prepayment / foreclosure / charge.
  /// [installmentId] is required for `payment_type: 'EMI'`.
  Future<void> recordPayment({
    required int loanId,
    required String paymentType,
    required num amount,
    required String paidOn,
    int? installmentId,
    String? paymentMethod,
    String? reference,
    String? notes,
  }) async {
    final response = await _dio.post(
      ApiConstants.loanPayments(loanId),
      data: {
        'payment_type': paymentType,
        'amount': amount,
        'paid_on': paidOn,
        'installment_id': installmentId,
        'payment_method': paymentMethod,
        'reference': reference,
        'notes': notes,
      },
    );
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to record payment');
  }

  /// Flags an installment `BOUNCED`/`WAIVED`, or clears the flag with null.
  Future<void> setInstallmentManualStatus({
    required int loanId,
    required int installmentId,
    required String? manualStatus,
  }) async {
    final response = await _dio.put(
      ApiConstants.loanPayments(loanId),
      data: {'installment_id': installmentId, 'manual_status': manualStatus},
    );
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to update installment');
  }

  Future<void> reversePayment({
    required int loanId,
    required int paymentId,
    String? reason,
  }) async {
    final response = await _dio.post(
      ApiConstants.loanPaymentReverse(loanId, paymentId),
      data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to reverse payment');
  }

  Future<LoanCalendar> fetchCalendar({required String from, required String to}) async {
    final response = await _dio.get(
      ApiConstants.loansCalendar,
      queryParameters: {'from': from, 'to': to},
    );
    final data = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to load the EMI calendar',
    );
    return LoanCalendar.fromJson(data);
  }
}
