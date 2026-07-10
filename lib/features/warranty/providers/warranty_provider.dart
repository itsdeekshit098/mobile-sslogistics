import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/warranty_models.dart';
import '../data/warranty_repository.dart';

final warrantyRepositoryProvider = Provider<WarrantyRepository>((ref) => WarrantyRepository());

class WarrantyState {
  final List<WarrantyItem> items;
  final int total;
  final int page;
  final int pageSize;
  final WarrantyFilters filters;

  const WarrantyState({
    required this.items,
    required this.total,
    this.page = 1,
    this.pageSize = 20,
    this.filters = const WarrantyFilters(),
  });

  int get totalPages => total == 0 ? 1 : (total / pageSize).ceil();
}

/// autoDispose so a switched-user login doesn't briefly show the previous
/// user's cached warranty list.
final warrantyProvider =
    AsyncNotifierProvider.autoDispose<WarrantyNotifier, WarrantyState>(WarrantyNotifier.new);

class WarrantyNotifier extends AutoDisposeAsyncNotifier<WarrantyState> {
  bool _disposed = false;

  @override
  Future<WarrantyState> build() {
    ref.onDispose(() => _disposed = true);
    return _fetch();
  }

  Future<WarrantyState> _fetch({
    int page = 1,
    int pageSize = 20,
    WarrantyFilters filters = const WarrantyFilters(),
  }) async {
    var data = await ref
        .read(warrantyRepositoryProvider)
        .fetch(filters: filters, page: page, pageSize: pageSize);
    // A delete can empty out the last page — step back a page rather than
    // showing a page that no longer exists.
    if (data.items.isEmpty && data.total > 0 && page > 1) {
      final lastPage = (data.total / pageSize).ceil();
      page = lastPage < 1 ? 1 : lastPage;
      data = await ref
          .read(warrantyRepositoryProvider)
          .fetch(filters: filters, page: page, pageSize: pageSize);
    }
    return WarrantyState(items: data.items, total: data.total, page: page, pageSize: pageSize, filters: filters);
  }

  Future<void> refresh() async {
    final current = state.valueOrNull;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _fetch(
        page: current?.page ?? 1,
        pageSize: current?.pageSize ?? 20,
        filters: current?.filters ?? const WarrantyFilters(),
      ),
    );
    if (_disposed) return;
    state = result;
  }

  Future<void> setSearch(String value) async {
    final current = state.valueOrNull;
    final filters = (current?.filters ?? const WarrantyFilters()).copyWith(search: value);
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _fetch(page: 1, pageSize: current?.pageSize ?? 20, filters: filters),
    );
    if (_disposed) return;
    state = result;
  }

  Future<void> setFilters(WarrantyFilters filters) async {
    final current = state.valueOrNull;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _fetch(page: 1, pageSize: current?.pageSize ?? 20, filters: filters),
    );
    if (_disposed) return;
    state = result;
  }

  Future<void> setStatusFilter(String? status) async {
    final current = state.valueOrNull;
    final filters = (current?.filters ?? const WarrantyFilters())
        .copyWith(status: status, clearStatus: status == null);
    await setFilters(filters);
  }

  Future<void> changePage(int page) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _fetch(page: page, pageSize: current.pageSize, filters: current.filters),
    );
    if (_disposed) return;
    state = result;
  }

  Future<void> changePageSize(int pageSize) async {
    final current = state.valueOrNull;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _fetch(page: 1, pageSize: pageSize, filters: current?.filters ?? const WarrantyFilters()),
    );
    if (_disposed) return;
    state = result;
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
