import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/api_response.dart';
import '../../../shared/state/paged_result.dart';
import 'client_models.dart';

class ClientRepository {
  Dio get _dio => DioClient.dio;

  Future<PagedResult<Client, ClientSummary?>> fetchClients({
    required int page,
    required int pageSize,
    required String search,
    required ClientFilters filters,
    bool includeSummary = false,
  }) async {
    final response = await _dio.get(
      ApiConstants.clients,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (search.isNotEmpty) 'search': search,
        if (filters.clientType != null) 'client_type': filters.clientType,
        if (filters.hasDues) 'has_dues': 'true',
        if (filters.partyKind != null) 'party_kind': filters.partyKind,
        if (includeSummary) 'include_summary': 'true',
      },
    );
    final data = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to load clients',
    );
    final items = (data['data'] as List<dynamic>? ?? [])
        .map((e) => Client.fromJson(e as Map<String, dynamic>))
        .toList();
    return PagedResult<Client, ClientSummary?>(
      items: items,
      total: data['total'] as int? ?? items.length,
      extras: data['summary'] != null
          ? ClientSummary.fromJson(data['summary'] as Map<String, dynamic>)
          : null,
    );
  }

  Future<ClientDetail> fetchClient(int id) async {
    final response = await _dio.get(ApiConstants.clientById(id));
    final data = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to load client',
    );
    return ClientDetail.fromJson(data);
  }

  Future<int> createClient({
    String? name,
    required String clientType,
    String partyKind = 'COMPANY',
    int? entityId,
    int? receivingAccountId,
    String? location,
    String? address,
    String? gstNumber,
    String? notes,
    num? openingBalance,
    String? openingDate,
  }) async {
    final response = await _dio.post(
      ApiConstants.clients,
      data: {
        'party_kind': partyKind,
        // An individual's name is mirrored server-side from the linked
        // entity — omitted so it can never fight the trigger.
        if (partyKind != 'INDIVIDUAL') 'name': name,
        'entity_id': entityId,
        'receiving_account_id': receivingAccountId,
        'client_type': clientType,
        'location': location,
        'address': address,
        'gst_number': partyKind == 'INDIVIDUAL' ? null : gstNumber,
        'notes': notes,
        if (openingBalance != null) 'opening_balance': openingBalance,
        if (openingDate != null) 'opening_date': openingDate,
      },
    );
    final data = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to create client',
    );
    return (data['client'] as Map<String, dynamic>)['id'] as int;
  }

  Future<void> updateClient(int id, Map<String, dynamic> fields) async {
    final response = await _dio.put(ApiConstants.clients, data: {'id': id, ...fields});
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to update client');
  }

  Future<void> deleteClient(int id) async {
    final response = await _dio.delete(ApiConstants.clients, queryParameters: {'id': id});
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to delete client');
  }

  Future<({List<LedgerEntry> data, int total, num closingBalance})> fetchEntries({
    required int clientId,
    required int page,
    required int pageSize,
  }) async {
    final response = await _dio.get(
      ApiConstants.clientEntries(clientId),
      queryParameters: {'page': page, 'page_size': pageSize},
    );
    final data = unwrapResponse<Map<String, dynamic>>(
      response,
      fallbackError: 'Failed to load statement',
    );
    return (
      data: (data['data'] as List<dynamic>? ?? [])
          .map((e) => LedgerEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: data['total'] as int? ?? 0,
      closingBalance: data['closing_balance'] as num? ?? 0,
    );
  }

  Future<void> addEntry({
    required int clientId,
    required String entryType,
    required num amount,
    required String entryDate,
    String? invoiceNo,
    String? periodMonth,
    String? paymentMethod,
    String? reference,
    String? description,
  }) async {
    final response = await _dio.post(
      ApiConstants.clientEntries(clientId),
      data: {
        'entry_type': entryType,
        'amount': amount,
        'entry_date': entryDate,
        'invoice_no': invoiceNo,
        'period_month': periodMonth,
        'payment_method': paymentMethod,
        'reference': reference,
        'description': description,
      },
    );
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to save entry');
  }

  Future<void> reverseEntry({required int clientId, required int entryId, String? reason}) async {
    final response = await _dio.post(
      ApiConstants.clientEntryReverse(clientId, entryId),
      data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to reverse entry');
  }

  Future<void> addOrUpdateContact({
    required int clientId,
    int? id,
    required String name,
    String? role,
    String? designation,
    String? phone,
    String? altPhone,
    String? email,
    bool isPrimary = false,
  }) async {
    final path = ApiConstants.clientContacts(clientId);
    final payload = {
      if (id != null) 'id': id,
      'name': name,
      'role': role,
      'designation': designation,
      'phone': phone,
      'alt_phone': altPhone,
      'email': email,
      'is_primary': isPrimary,
    };
    final response =
        id == null ? await _dio.post(path, data: payload) : await _dio.put(path, data: payload);
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to save contact');
  }

  Future<void> deleteContact({required int clientId, required int contactId}) async {
    final response = await _dio.delete(
      ApiConstants.clientContacts(clientId),
      queryParameters: {'contact_id': contactId},
    );
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to remove contact');
  }

  /// [vehicleId] set links a real fleet vehicle (spec is copied from it
  /// server-side); null means a declared bucket, using the spec fields here.
  Future<void> addOrUpdateDeployment({
    required int clientId,
    int? id,
    int? vehicleId,
    int quantity = 1,
    String? vehicleType,
    int? seatingCapacity,
    String? truckType,
    String? containerLength,
    String? axleType,
    String? containerBodyType,
    num? monthlyRate,
    String? startDate,
    String? endDate,
  }) async {
    final path = ApiConstants.clientDeployments(clientId);
    final payload = {
      if (id != null) 'id': id,
      'vehicle_id': vehicleId,
      'quantity': quantity,
      'vehicle_type': vehicleType,
      'seating_capacity': seatingCapacity,
      'truck_type': truckType,
      'container_length': containerLength,
      'axle_type': axleType,
      'container_body_type': containerBodyType,
      'monthly_rate': monthlyRate,
      'start_date': startDate,
      'end_date': endDate,
    };
    final response =
        id == null ? await _dio.post(path, data: payload) : await _dio.put(path, data: payload);
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to save vehicle');
  }

  Future<void> deleteDeployment({required int clientId, required int deploymentId}) async {
    final response = await _dio.delete(
      ApiConstants.clientDeployments(clientId),
      queryParameters: {'deployment_id': deploymentId},
    );
    unwrapResponse<dynamic>(response, fallbackError: 'Failed to remove vehicle');
  }
}
