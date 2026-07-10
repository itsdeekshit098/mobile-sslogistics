import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/vehicle_models.dart';
import '../data/vehicle_repository.dart';

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  return VehicleRepository();
});

class VehiclesState {
  final List<FleetVehicle> vehicles;
  final int total;
  final VehicleStats stats;
  final int page;
  final int pageSize;
  final String search;
  final String type;
  final String status;
  final String ownerType;
  final String ownerName;
  final String fuelType;
  final String fcStatus;
  final String insuranceStatus;

  const VehiclesState({
    required this.vehicles,
    required this.total,
    required this.stats,
    this.page = 1,
    this.pageSize = 10,
    this.search = '',
    this.type = 'all',
    this.status = '',
    this.ownerType = '',
    this.ownerName = '',
    this.fuelType = '',
    this.fcStatus = '',
    this.insuranceStatus = '',
  });

  int get totalPages => total == 0 ? 1 : (total / pageSize).ceil();
  bool get hasFilters =>
      search.isNotEmpty ||
      type != 'all' ||
      status.isNotEmpty ||
      ownerType.isNotEmpty ||
      ownerName.isNotEmpty ||
      fuelType.isNotEmpty ||
      fcStatus.isNotEmpty ||
      insuranceStatus.isNotEmpty;

  VehiclesState copyWith({
    List<FleetVehicle>? vehicles,
    int? total,
    VehicleStats? stats,
    int? page,
    int? pageSize,
    String? search,
    String? type,
    String? status,
    String? ownerType,
    String? ownerName,
    String? fuelType,
    String? fcStatus,
    String? insuranceStatus,
  }) {
    return VehiclesState(
      vehicles: vehicles ?? this.vehicles,
      total: total ?? this.total,
      stats: stats ?? this.stats,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      search: search ?? this.search,
      type: type ?? this.type,
      status: status ?? this.status,
      ownerType: ownerType ?? this.ownerType,
      ownerName: ownerName ?? this.ownerName,
      fuelType: fuelType ?? this.fuelType,
      fcStatus: fcStatus ?? this.fcStatus,
      insuranceStatus: insuranceStatus ?? this.insuranceStatus,
    );
  }
}

/// autoDispose so the cached list dies with its last listener — otherwise a
/// logout/login as a different user would briefly show the previous user's
/// vehicles (nothing invalidates feature providers on auth changes).
final vehiclesListProvider =
    AsyncNotifierProvider.autoDispose<VehiclesNotifier, VehiclesState>(
      VehiclesNotifier.new,
    );

class VehiclesNotifier extends AutoDisposeAsyncNotifier<VehiclesState> {
  // Tracks disposal explicitly because this riverpod version doesn't expose
  // `ref.mounted`. Without this, a mutator awaiting `_fetch()` can resolve
  // after autoDispose tears the notifier down (e.g. the screen was navigated
  // away from mid-search) and writing to `state` then throws
  // "Bad state: Future already completed".
  bool _disposed = false;

  @override
  Future<VehiclesState> build() {
    ref.onDispose(() => _disposed = true);
    return _fetch();
  }

  Future<VehiclesState> _fetch({
    int page = 1,
    int pageSize = 10,
    String search = '',
    String type = 'all',
    String status = '',
    String ownerType = '',
    String ownerName = '',
    String fuelType = '',
    String fcStatus = '',
    String insuranceStatus = '',
  }) async {
    var data = await ref
        .read(vehicleRepositoryProvider)
        .getVehicles(
          page: page,
          pageSize: pageSize,
          search: search,
          type: type,
          status: status,
          ownerType: ownerType,
          ownerName: ownerName,
          fuelType: fuelType,
          fcStatus: fcStatus,
          insuranceStatus: insuranceStatus,
        );
    // The requested page can fall past the end (e.g. the last vehicle on the
    // final page was just deleted) — clamp to the last non-empty page.
    if (data.vehicles.isEmpty && data.total > 0 && page > 1) {
      final lastPage = (data.total / pageSize).ceil();
      page = lastPage < 1 ? 1 : lastPage;
      data = await ref
          .read(vehicleRepositoryProvider)
          .getVehicles(
            page: page,
            pageSize: pageSize,
            search: search,
            type: type,
            status: status,
            ownerType: ownerType,
            ownerName: ownerName,
            fuelType: fuelType,
            fcStatus: fcStatus,
            insuranceStatus: insuranceStatus,
          );
    }
    return VehiclesState(
      vehicles: data.vehicles,
      total: data.total,
      stats: data.stats,
      page: page,
      pageSize: pageSize,
      search: search,
      type: type,
      status: status,
      ownerType: ownerType,
      ownerName: ownerName,
      fuelType: fuelType,
      fcStatus: fcStatus,
      insuranceStatus: insuranceStatus,
    );
  }

  Future<void> refresh({bool showLoading = true}) async {
    final current = state.valueOrNull;
    if (showLoading) state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _fetch(
        page: current?.page ?? 1,
        pageSize: current?.pageSize ?? 10,
        search: current?.search ?? '',
        type: current?.type ?? 'all',
        status: current?.status ?? '',
        ownerType: current?.ownerType ?? '',
        ownerName: current?.ownerName ?? '',
        fuelType: current?.fuelType ?? '',
        fcStatus: current?.fcStatus ?? '',
        insuranceStatus: current?.insuranceStatus ?? '',
      ),
    );
    // Guard against the provider being torn down (autoDispose, e.g. the
    // screen was navigated away from) while the fetch above was in flight —
    // writing to `state` after disposal throws "Bad state: Future already
    // completed".
    if (_disposed) return;
    state = result;
  }

  Future<void> search(String value) async {
    final current = state.valueOrNull;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _fetch(
        page: 1,
        pageSize: current?.pageSize ?? 10,
        search: value,
        type: current?.type ?? 'all',
        status: current?.status ?? '',
        ownerType: current?.ownerType ?? '',
        ownerName: current?.ownerName ?? '',
        fuelType: current?.fuelType ?? '',
        fcStatus: current?.fcStatus ?? '',
        insuranceStatus: current?.insuranceStatus ?? '',
      ),
    );
    if (_disposed) return;
    state = result;
  }

  Future<void> applyFilters({
    String? type,
    String? status,
    String? ownerType,
    String? ownerName,
    String? fuelType,
    String? fcStatus,
    String? insuranceStatus,
  }) async {
    final current = state.valueOrNull;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _fetch(
        page: 1,
        pageSize: current?.pageSize ?? 10,
        search: current?.search ?? '',
        type: type ?? current?.type ?? 'all',
        status: status ?? current?.status ?? '',
        ownerType: ownerType ?? current?.ownerType ?? '',
        ownerName: ownerName ?? current?.ownerName ?? '',
        fuelType: fuelType ?? current?.fuelType ?? '',
        fcStatus: fcStatus ?? current?.fcStatus ?? '',
        insuranceStatus: insuranceStatus ?? current?.insuranceStatus ?? '',
      ),
    );
    if (_disposed) return;
    state = result;
  }

  Future<void> clearFilters() async {
    final current = state.valueOrNull;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _fetch(pageSize: current?.pageSize ?? 10),
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
        type: current.type,
        status: current.status,
        ownerType: current.ownerType,
        ownerName: current.ownerName,
        fuelType: current.fuelType,
        fcStatus: current.fcStatus,
        insuranceStatus: current.insuranceStatus,
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
        type: current?.type ?? 'all',
        status: current?.status ?? '',
        ownerType: current?.ownerType ?? '',
        ownerName: current?.ownerName ?? '',
        fuelType: current?.fuelType ?? '',
        fcStatus: current?.fcStatus ?? '',
        insuranceStatus: current?.insuranceStatus ?? '',
      ),
    );
    if (_disposed) return;
    state = result;
  }

  Future<void> createVehicle(VehiclePayload payload) async {
    await ref.read(vehicleRepositoryProvider).createVehicle(payload);
    await refresh();
  }

  Future<void> updateVehicle(VehiclePayload payload) async {
    await ref.read(vehicleRepositoryProvider).updateVehicle(payload);
    await refresh();
  }

  Future<void> deleteVehicle(int id) async {
    await ref.read(vehicleRepositoryProvider).deleteVehicle(id);
    await refresh();
  }
}
