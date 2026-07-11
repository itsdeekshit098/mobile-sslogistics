import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/state/list_filters.dart';
import '../../../shared/state/paged_result.dart';
import '../../../shared/state/paginated_list_notifier.dart';
import '../../../shared/state/paginated_list_state.dart';
import '../data/vehicle_models.dart';
import '../data/vehicle_repository.dart';

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  return VehicleRepository();
});

class VehicleFilters implements ListFilters {
  final String type;
  final String status;
  final String ownerType;
  final String ownerName;
  final String fuelType;
  final String fcStatus;
  final String insuranceStatus;

  const VehicleFilters({
    this.type = 'all',
    this.status = '',
    this.ownerType = '',
    this.ownerName = '',
    this.fuelType = '',
    this.fcStatus = '',
    this.insuranceStatus = '',
  });

  @override
  bool get isActive =>
      type != 'all' ||
      status.isNotEmpty ||
      ownerType.isNotEmpty ||
      ownerName.isNotEmpty ||
      fuelType.isNotEmpty ||
      fcStatus.isNotEmpty ||
      insuranceStatus.isNotEmpty;

  VehicleFilters copyWith({
    String? type,
    String? status,
    String? ownerType,
    String? ownerName,
    String? fuelType,
    String? fcStatus,
    String? insuranceStatus,
  }) {
    return VehicleFilters(
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

typedef VehiclesState = PaginatedListState<FleetVehicle, VehicleFilters, VehicleStats>;

extension VehiclesStateX on VehiclesState {
  List<FleetVehicle> get vehicles => items;
  VehicleStats get stats => extras;
  String get type => filters.type;
  String get status => filters.status;
  String get ownerType => filters.ownerType;
  String get ownerName => filters.ownerName;
  String get fuelType => filters.fuelType;
  String get fcStatus => filters.fcStatus;
  String get insuranceStatus => filters.insuranceStatus;
}

/// autoDispose so the cached list dies with its last listener — otherwise a
/// logout/login as a different user would briefly show the previous user's
/// vehicles (nothing invalidates feature providers on auth changes).
final vehiclesListProvider =
    AsyncNotifierProvider.autoDispose<VehiclesNotifier, VehiclesState>(
      VehiclesNotifier.new,
    );

class VehiclesNotifier
    extends PaginatedListNotifier<FleetVehicle, VehicleFilters, VehicleStats> {
  @override
  VehicleFilters get initialFilters => const VehicleFilters();

  @override
  Future<PagedResult<FleetVehicle, VehicleStats>> fetchPage({
    required int page,
    required int pageSize,
    required String search,
    required VehicleFilters filters,
  }) async {
    final data = await ref
        .read(vehicleRepositoryProvider)
        .getVehicles(
          page: page,
          pageSize: pageSize,
          search: search,
          type: filters.type,
          status: filters.status,
          ownerType: filters.ownerType,
          ownerName: filters.ownerName,
          fuelType: filters.fuelType,
          fcStatus: filters.fcStatus,
          insuranceStatus: filters.insuranceStatus,
        );
    return PagedResult(items: data.vehicles, total: data.total, extras: data.stats);
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
