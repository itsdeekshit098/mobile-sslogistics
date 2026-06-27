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

  const VehiclesState({
    required this.vehicles,
    required this.total,
    required this.stats,
    this.page = 1,
    this.pageSize = 10,
    this.search = '',
    this.type = 'all',
    this.status = '',
  });

  int get totalPages => total == 0 ? 1 : (total / pageSize).ceil();
  bool get hasFilters =>
      search.isNotEmpty || type != 'all' || status.isNotEmpty;

  VehiclesState copyWith({
    List<FleetVehicle>? vehicles,
    int? total,
    VehicleStats? stats,
    int? page,
    int? pageSize,
    String? search,
    String? type,
    String? status,
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
    );
  }
}

final vehiclesListProvider =
    AsyncNotifierProvider<VehiclesNotifier, VehiclesState>(
      VehiclesNotifier.new,
    );

class VehiclesNotifier extends AsyncNotifier<VehiclesState> {
  @override
  Future<VehiclesState> build() => _fetch();

  Future<VehiclesState> _fetch({
    int page = 1,
    int pageSize = 10,
    String search = '',
    String type = 'all',
    String status = '',
  }) async {
    final data = await ref
        .read(vehicleRepositoryProvider)
        .getVehicles(
          page: page,
          pageSize: pageSize,
          search: search,
          type: type,
          status: status,
        );
    return VehiclesState(
      vehicles: data.vehicles,
      total: data.total,
      stats: data.stats,
      page: page,
      pageSize: pageSize,
      search: search,
      type: type,
      status: status,
    );
  }

  Future<void> refresh({bool showLoading = true}) async {
    final current = state.valueOrNull;
    if (showLoading) state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetch(
        page: current?.page ?? 1,
        pageSize: current?.pageSize ?? 10,
        search: current?.search ?? '',
        type: current?.type ?? 'all',
        status: current?.status ?? '',
      ),
    );
  }

  Future<void> search(String value) async {
    final current = state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetch(
        page: 1,
        pageSize: current?.pageSize ?? 10,
        search: value,
        type: current?.type ?? 'all',
        status: current?.status ?? '',
      ),
    );
  }

  Future<void> applyFilters({String? type, String? status}) async {
    final current = state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetch(
        page: 1,
        pageSize: current?.pageSize ?? 10,
        search: current?.search ?? '',
        type: type ?? current?.type ?? 'all',
        status: status ?? current?.status ?? '',
      ),
    );
  }

  Future<void> clearFilters() async {
    final current = state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetch(pageSize: current?.pageSize ?? 10),
    );
  }

  Future<void> changePage(int page) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetch(
        page: page,
        pageSize: current.pageSize,
        search: current.search,
        type: current.type,
        status: current.status,
      ),
    );
  }

  Future<void> changePageSize(int pageSize) async {
    final current = state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetch(
        page: 1,
        pageSize: pageSize,
        search: current?.search ?? '',
        type: current?.type ?? 'all',
        status: current?.status ?? '',
      ),
    );
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
