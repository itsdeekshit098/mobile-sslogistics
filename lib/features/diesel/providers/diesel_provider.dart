import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/diesel_repository.dart';
import '../data/diesel_models.dart';

/// UI state for the diesel records list screen
class DieselListState {
  final List<DieselRecord> records;
  final int total;
  final int page;
  final int pageSize;
  final int? selectedVehicleId;

  const DieselListState({
    required this.records,
    required this.total,
    this.page = 1,
    this.pageSize = 10,
    this.selectedVehicleId,
  });

  int get totalPages => total == 0 ? 1 : (total / pageSize).ceil();

  DieselListState copyWith({
    List<DieselRecord>? records,
    int? total,
    int? page,
    int? pageSize,
    int? selectedVehicleId,
    bool clearVehicle = false,
  }) {
    return DieselListState(
      records: records ?? this.records,
      total: total ?? this.total,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      selectedVehicleId: clearVehicle
          ? null
          : (selectedVehicleId ?? this.selectedVehicleId),
    );
  }
}

final dieselRepositoryProvider = Provider<DieselRepository>(
  (ref) => DieselRepository(),
);

final dieselListProvider =
    AsyncNotifierProvider<DieselListNotifier, DieselListState>(
      DieselListNotifier.new,
    );

class DieselListNotifier extends AsyncNotifier<DieselListState> {
  @override
  Future<DieselListState> build() async =>
      const DieselListState(records: [], total: 0, page: 1, pageSize: 10);

  // ── Internal fetch ───────────────────────────────────────────────────────
  Future<DieselListState> _fetch({
    int? vehicleId,
    int page = 1,
    int pageSize = 10,
  }) async {
    if (vehicleId == null) {
      return DieselListState(
        records: const [],
        total: 0,
        page: page,
        pageSize: pageSize,
      );
    }

    final data = await ref
        .read(dieselRepositoryProvider)
        .getRecords(vehicleId: vehicleId, page: page, pageSize: pageSize);
    return DieselListState(
      records: data.records,
      total: data.total,
      page: page,
      pageSize: pageSize,
      selectedVehicleId: vehicleId,
    );
  }

  // ── Pagination ───────────────────────────────────────────────────────────
  Future<void> changePage(int page) async {
    final cur = state.valueOrNull;
    if (cur == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetch(
        vehicleId: cur.selectedVehicleId,
        page: page,
        pageSize: cur.pageSize,
      ),
    );
  }

  Future<void> changePageSize(int pageSize) async {
    final cur = state.valueOrNull;
    if (cur == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () =>
          _fetch(vehicleId: cur.selectedVehicleId, page: 1, pageSize: pageSize),
    );
  }

  // ── Filter ───────────────────────────────────────────────────────────────
  Future<void> filterByVehicle(int? vehicleId) async {
    final cur = state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () =>
          _fetch(vehicleId: vehicleId, page: 1, pageSize: cur?.pageSize ?? 10),
    );
  }

  // ── CRUD ─────────────────────────────────────────────────────────────────
  Future<List<String>> createRecord(CreateDieselDto dto) async {
    final cur = state.valueOrNull;
    final warnings =
        await ref.read(dieselRepositoryProvider).createRecord(dto);
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetch(
        vehicleId: cur?.selectedVehicleId,
        page: 1,
        pageSize: cur?.pageSize ?? 10,
      ),
    );
    return warnings;
  }

  Future<void> updateRecord(UpdateDieselDto dto) async {
    final cur = state.valueOrNull;
    await ref.read(dieselRepositoryProvider).updateRecord(dto);
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetch(
        vehicleId: cur?.selectedVehicleId,
        page: cur?.page ?? 1,
        pageSize: cur?.pageSize ?? 10,
      ),
    );
  }

  Future<void> deleteRecord(int id) async {
    final cur = state.valueOrNull;
    await ref.read(dieselRepositoryProvider).deleteRecord(id);
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetch(
        vehicleId: cur?.selectedVehicleId,
        page: cur?.page ?? 1,
        pageSize: cur?.pageSize ?? 10,
      ),
    );
  }
}
