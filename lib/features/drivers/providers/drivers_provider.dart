import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/state/list_filters.dart';
import '../../../shared/state/paged_result.dart';
import '../../../shared/state/paginated_list_notifier.dart';
import '../../../shared/state/paginated_list_state.dart';
import '../data/driver_models.dart';
import '../data/driver_repository.dart';

final driverRepositoryProvider = Provider<DriverRepository>((ref) => DriverRepository());

class DriverFilters implements ListFilters {
  final bool includeInactive;

  const DriverFilters({this.includeInactive = false});

  @override
  bool get isActive => includeInactive;

  DriverFilters copyWith({bool? includeInactive}) =>
      DriverFilters(includeInactive: includeInactive ?? this.includeInactive);
}

typedef DriversState = PaginatedListState<Driver, DriverFilters, void>;

extension DriversStateX on DriversState {
  List<Driver> get drivers => items;
  bool get includeInactive => filters.includeInactive;
}

/// autoDispose so a switched-user login doesn't briefly show the previous
/// user's cached driver list.
final driversListProvider =
    AsyncNotifierProvider.autoDispose<DriversNotifier, DriversState>(DriversNotifier.new);

class DriversNotifier extends PaginatedListNotifier<Driver, DriverFilters, void> {
  @override
  DriverFilters get initialFilters => const DriverFilters();

  @override
  int get defaultPageSize => 20;

  // Only clamp to the last page for a true out-of-bounds page request —
  // when filtering to inactive-only, an empty page can legitimately mean
  // "no inactive drivers on this page", not "past the end of the list".
  @override
  bool shouldClampPage(DriverFilters filters) => !filters.includeInactive;

  @override
  Future<PagedResult<Driver, void>> fetchPage({
    required int page,
    required int pageSize,
    required String search,
    required DriverFilters filters,
  }) async {
    // The API's include_inactive flag is additive (active+inactive together),
    // not an inactive-only filter — it has no server-side way to ask for
    // "only inactive". So when the "Inactive" chip is on, fetch with the
    // flag set to get inactive rows included at all, then filter this page
    // down to inactive-only client-side so the chip actually does what its
    // label says instead of just silently adding rows that may not exist.
    final data = await ref.read(driverRepositoryProvider).getDrivers(
          page: page,
          pageSize: pageSize,
          search: search,
          includeInactive: filters.includeInactive,
        );
    final drivers = filters.includeInactive
        ? data.drivers.where((d) => !d.isActive).toList()
        : data.drivers;
    final total = filters.includeInactive ? drivers.length : data.total;
    return PagedResult(items: drivers, total: total, extras: null);
  }

  Future<void> toggleIncludeInactive(bool value) =>
      applyFilters(DriverFilters(includeInactive: value));

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
