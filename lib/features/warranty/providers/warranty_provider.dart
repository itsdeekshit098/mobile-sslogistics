import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/state/paged_result.dart';
import '../../../shared/state/paginated_list_notifier.dart';
import '../../../shared/state/paginated_list_state.dart';
import '../data/warranty_models.dart';
import '../data/warranty_repository.dart';

final warrantyRepositoryProvider = Provider<WarrantyRepository>((ref) => WarrantyRepository());

typedef WarrantyState = PaginatedListState<WarrantyItem, WarrantyFilters, void>;

/// autoDispose so a switched-user login doesn't briefly show the previous
/// user's cached warranty list.
final warrantyProvider =
    AsyncNotifierProvider.autoDispose<WarrantyNotifier, WarrantyState>(WarrantyNotifier.new);

class WarrantyNotifier extends PaginatedListNotifier<WarrantyItem, WarrantyFilters, void> {
  @override
  WarrantyFilters get initialFilters => const WarrantyFilters();

  @override
  int get defaultPageSize => 20;

  // WarrantyFilters carries its own `search` field (used directly by the
  // repository's query params), so the search text lives there rather than
  // in the base class's top-level `search` — [search] below routes into it.
  @override
  Future<PagedResult<WarrantyItem, void>> fetchPage({
    required int page,
    required int pageSize,
    required String search,
    required WarrantyFilters filters,
  }) async {
    final data = await ref
        .read(warrantyRepositoryProvider)
        .fetch(filters: filters, page: page, pageSize: pageSize);
    return PagedResult(items: data.items, total: data.total, extras: null);
  }

  Future<void> setSearch(String value) {
    final current = state.valueOrNull;
    return applyFilters((current?.filters ?? initialFilters).copyWith(search: value));
  }

  Future<void> setFilters(WarrantyFilters filters) => applyFilters(filters);

  Future<void> setStatusFilter(String? status) async {
    final current = state.valueOrNull;
    final filters = (current?.filters ?? initialFilters)
        .copyWith(status: status, clearStatus: status == null);
    await setFilters(filters);
  }

  Future<void> createItem(WarrantyDto dto) async {
    await ref.read(warrantyRepositoryProvider).create(dto);
    await refresh();
  }

  Future<void> updateItem(WarrantyDto dto) async {
    await ref.read(warrantyRepositoryProvider).update(dto);
    await refresh();
  }

  /// Dispatches to create or update based on whether [dto] carries an id —
  /// lets the single create+edit form sheet call one method regardless of
  /// mode.
  Future<void> createOrUpdate(WarrantyDto dto) => dto.id == null ? createItem(dto) : updateItem(dto);

  Future<void> deleteItem(int id) async {
    await ref.read(warrantyRepositoryProvider).delete(id);
    await refresh();
  }
}
