import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../models/api_response.dart';
import 'bank_account_models.dart';

class BankAccountListData {
  final List<BankAccount> accounts;
  final int total;

  const BankAccountListData({required this.accounts, required this.total});
}

class BankAccountRepository {
  Dio get _dio => DioClient.dio;

  Future<List<BankAccount>> fetchAll({bool activeOnly = false, int? holderEntityId}) async {
    final query = <String, dynamic>{};
    if (activeOnly) query['is_active'] = 'true';
    if (holderEntityId != null) query['holder_entity_id'] = holderEntityId;

    final response = await _dio.get(ApiConstants.bankAccounts, queryParameters: query);
    final data = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to load bank accounts',
    );
    return (data['data'] as List<dynamic>? ?? [])
        .map((e) => BankAccount.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BankAccountListData> fetchPage({
    required int page,
    required int pageSize,
    String search = '',
    bool withCounts = true,
  }) async {
    final response = await _dio.get(
      ApiConstants.bankAccounts,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (search.isNotEmpty) 'search': search,
        if (withCounts) 'with_counts': 'true',
      },
    );
    final data = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to load bank accounts',
    );
    final list = (data['data'] as List<dynamic>? ?? [])
        .map((e) => BankAccount.fromJson(e as Map<String, dynamic>))
        .toList();
    return BankAccountListData(accounts: list, total: data['total'] as int? ?? list.length);
  }

  Future<BankAccount> create({
    required int holderEntityId,
    required String bankName,
    required String accountNumber,
    String accountType = 'SAVINGS',
    String? ifsc,
    String? branch,
    String? nickname,
    String? notes,
  }) async {
    final response = await _dio.post(
      ApiConstants.bankAccounts,
      data: {
        'holder_entity_id': holderEntityId,
        'bank_name': bankName,
        'account_number': accountNumber,
        'account_type': accountType,
        'ifsc': ifsc,
        'branch': branch,
        'nickname': nickname,
        'notes': notes,
      },
    );
    final data = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to add bank account',
    );
    return BankAccount.fromJson(data['bank_account'] as Map<String, dynamic>);
  }

  Future<BankAccount> update({
    required int id,
    int? holderEntityId,
    String? bankName,
    String? accountNumber,
    String? accountType,
    String? ifsc,
    String? branch,
    String? nickname,
    String? notes,
    bool? isActive,
  }) async {
    final response = await _dio.put(
      ApiConstants.bankAccounts,
      data: {
        'id': id,
        if (holderEntityId != null) 'holder_entity_id': holderEntityId,
        if (bankName != null) 'bank_name': bankName,
        if (accountNumber != null) 'account_number': accountNumber,
        if (accountType != null) 'account_type': accountType,
        if (ifsc != null) 'ifsc': ifsc,
        if (branch != null) 'branch': branch,
        if (nickname != null) 'nickname': nickname,
        if (notes != null) 'notes': notes,
        if (isActive != null) 'is_active': isActive,
      },
    );
    final data = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to update bank account',
    );
    return BankAccount.fromJson(data['bank_account'] as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    final response = await _dio.delete(
      ApiConstants.bankAccounts,
      queryParameters: {'id': id},
    );
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to delete bank account');
  }
}
