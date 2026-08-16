import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/state/paged_result.dart';
import '../../../shared/state/paginated_list_notifier.dart';
import '../../../shared/state/paginated_list_state.dart';
import '../data/client_models.dart';
import '../data/client_repository.dart';

final clientRepositoryProvider = Provider<ClientRepository>((ref) => ClientRepository());

typedef ClientState = PaginatedListState<Client, ClientFilters, ClientSummary?>;

class ClientNotifier extends PaginatedListNotifier<Client, ClientFilters, ClientSummary?> {
  @override
  ClientFilters get initialFilters => ClientFilters.none;

  @override
  Future<PagedResult<Client, ClientSummary?>> fetchPage({
    required int page,
    required int pageSize,
    required String search,
    required ClientFilters filters,
  }) {
    return ref.read(clientRepositoryProvider).fetchClients(
          page: page,
          pageSize: pageSize,
          search: search,
          filters: filters,
          includeSummary: page == 1,
        );
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
    final id = await ref.read(clientRepositoryProvider).createClient(
          name: name,
          clientType: clientType,
          partyKind: partyKind,
          entityId: entityId,
          receivingAccountId: receivingAccountId,
          location: location,
          address: address,
          gstNumber: gstNumber,
          notes: notes,
          openingBalance: openingBalance,
          openingDate: openingDate,
        );
    await refresh();
    return id;
  }

  Future<void> updateClient(int id, Map<String, dynamic> fields) async {
    await ref.read(clientRepositoryProvider).updateClient(id, fields);
    await refresh();
  }

  Future<void> deleteClient(int id) async {
    await ref.read(clientRepositoryProvider).deleteClient(id);
    await refresh();
  }
}

final clientListProvider =
    AsyncNotifierProvider.autoDispose<ClientNotifier, ClientState>(ClientNotifier.new);
