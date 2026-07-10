import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/driver_models.dart';
import '../data/driver_repository.dart';

final driverRepositoryProvider = Provider<DriverRepository>((ref) => DriverRepository());

class DriversState {
  final List<Driver> drivers;
  final int total;
  final int page;
  final int pageSize;
  final String search;
  final bool includeInactive;

  const DriversState({
    required this.drivers,
    required this.total,
    this.page = 1,
    this.pageSize = 20,
    this.search = '',
    this.includeInactive = false,
  });

  int get totalPages => total == 0 ? 1 : (total / pageSize).ceil();

  DriversState copyWith({
    List<Driver>? drivers,
    int? total,
    int? page,
    int? pageSize,
    String? search,
    bool? includeInactive,
  }) {
    return DriversState(
      drivers: drivers ?? this.drivers,
      total: total ?? this.total,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      search: search ?? this.search,
      includeInactive: includeInactive ?? this.includeInactive,
    );
  }
}

/// autoDispose so a switched-user login doesn't briefly show the previous
/// user's cached driver list.
final driversListProvider =
    AsyncNotifierProvider.autoDispose<DriversNotifier, DriversState>(DriversNotifier.new);

class DriversNotifier extends AutoDisposeAsyncNotifier<DriversState> {
  // See VehiclesNotifier for why this manual disposal flag is needed:
  // autoDispose can tear the notifier down while a fetch is in flight, and
  // writing to `state` afterwards throws "Bad state: Future already completed".
  bool _disposed = false;

  @override
  Future<DriversState> build() {
    ref.onDispose(() => _disposed = true);
    return _fetch();
  }

  Future<DriversState> _fetch({
    int page = 1,
    int pageSize = 20,
    String search = '',
    bool includeInactive = false,
  }) async {
    // The API's include_inactive flag is additive (active+inactive together),
    // not an inactive-only filter — it has no server-side way to ask for
    // "only inactive". So when the "Inactive" chip is on, fetch with the
    // flag set to get inactive rows included at all, then filter this page
    // down to inactive-only client-side so the chip actually does what its
    // label says instead of just silently adding rows that may not exist.
    var data = await ref.read(driverRepositoryProvider).getDrivers(
          page: page,
          pageSize: pageSize,
          search: search,
          includeInactive: includeInactive,
        );
    // Only clamp to the last page for a true out-of-bounds page request —
    // when filtering to inactive-only, an empty page can legitimately mean
    // "no inactive drivers on this page", not "past the end of the list".
    if (!includeInactive && data.drivers.isEmpty && data.total > 0 && page > 1) {
      final lastPage = (data.total / pageSize).ceil();
      page = lastPage < 1 ? 1 : lastPage;
      data = await ref.read(driverRepositoryProvider).getDrivers(
            page: page,
            pageSize: pageSize,
            search: search,
            includeInactive: includeInactive,
          );
    }
    final drivers = includeInactive ? data.drivers.where((d) => !d.isActive).toList() : data.drivers;
    final total = includeInactive ? drivers.length : data.total;
    return DriversState(
      drivers: drivers,
      total: total,
      page: page,
      pageSize: pageSize,
      search: search,
      includeInactive: includeInactive,
    );
  }

  Future<void> refresh({bool showLoading = true}) async {
    final current = state.valueOrNull;
    if (showLoading) state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _fetch(
        page: current?.page ?? 1,
        pageSize: current?.pageSize ?? 20,
        search: current?.search ?? '',
        includeInactive: current?.includeInactive ?? false,
      ),
    );
    if (_disposed) return;
    state = result;
  }

  Future<void> search(String value) async {
    final current = state.valueOrNull;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _fetch(
        page: 1,
        pageSize: current?.pageSize ?? 20,
        search: value,
        includeInactive: current?.includeInactive ?? false,
      ),
    );
    if (_disposed) return;
    state = result;
  }

  Future<void> toggleIncludeInactive(bool value) async {
    final current = state.valueOrNull;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _fetch(
        page: 1,
        pageSize: current?.pageSize ?? 20,
        search: current?.search ?? '',
        includeInactive: value,
      ),
    );
    if (_disposed) return;
    state = result;
  }

  Future<void> changePage(int page) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _fetch(
        page: page,
        pageSize: current.pageSize,
        search: current.search,
        includeInactive: current.includeInactive,
      ),
    );
    if (_disposed) return;
    state = result;
  }

  Future<void> changePageSize(int pageSize) async {
    final current = state.valueOrNull;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _fetch(
        page: 1,
        pageSize: pageSize,
        search: current?.search ?? '',
        includeInactive: current?.includeInactive ?? false,
      ),
    );
    if (_disposed) return;
    state = result;
  }

  Future<void> createDriver(CreateDriverDto dto) async {
    await ref.read(driverRepositoryProvider).createDriver(dto);
    await refresh();
  }

  Future<void> updateDriver(UpdateDriverDto dto) async {
    await ref.read(driverRepositoryProvider).updateDriver(dto);
    await refresh();
  }

  Future<void> toggleActive(Driver driver) async {
    await ref
        .read(driverRepositoryProvider)
        .updateDriver(UpdateDriverDto(id: driver.id, isActive: !driver.isActive));
    await refresh(showLoading: false);
  }

  Future<void> deleteDriver(int id) async {
    await ref.read(driverRepositoryProvider).deleteDriver(id);
    await refresh();
  }
}
