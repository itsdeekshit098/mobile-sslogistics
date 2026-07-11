import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/state/list_filters.dart';
import '../../../shared/state/paged_result.dart';
import '../../../shared/state/paginated_list_notifier.dart';
import '../../../shared/state/paginated_list_state.dart';
import '../data/diesel_repository.dart';
import '../data/diesel_models.dart';

class DieselFilters implements ListFilters {
  final int? vehicleId;

  const DieselFilters({this.vehicleId});

  // Vehicle selection drives which records are shown at all (see
  // DieselListScreen's "no vehicle selected" empty state) rather than acting
  // as a filter chip on top of a base list, so it doesn't feed hasFilters.
  @override
  bool get isActive => false;
}

/// UI state for the diesel records list screen
typedef DieselListState = PaginatedListState<DieselRecord, DieselFilters, void>;

extension DieselListStateX on DieselListState {
  List<DieselRecord> get records => items;
  int? get selectedVehicleId => filters.vehicleId;
}

final dieselRepositoryProvider = Provider<DieselRepository>(
  (ref) => DieselRepository(),
);

/// autoDispose so the cached list dies with its last listener — otherwise a
/// logout/login as a different user would briefly show the previous user's
/// diesel records (nothing invalidates feature providers on auth changes).
final dieselListProvider =
    AsyncNotifierProvider.autoDispose<DieselListNotifier, DieselListState>(
      DieselListNotifier.new,
    );

class DieselListNotifier
    extends PaginatedListNotifier<DieselRecord, DieselFilters, void> {
  @override
  DieselFilters get initialFilters => const DieselFilters();

  @override
  Future<PagedResult<DieselRecord, void>> fetchPage({
    required int page,
    required int pageSize,
    required String search,
    required DieselFilters filters,
  }) async {
    if (filters.vehicleId == null) {
      return const PagedResult(items: [], total: 0, extras: null);
    }
    final data = await ref
        .read(dieselRepositoryProvider)
        .getRecords(vehicleId: filters.vehicleId, page: page, pageSize: pageSize);
    return PagedResult(items: data.records, total: data.total, extras: null);
  }

  // ── Filter ───────────────────────────────────────────────────────────────
  Future<void> filterByVehicle(int? vehicleId) =>
      applyFilters(DieselFilters(vehicleId: vehicleId));

  // ── CRUD ─────────────────────────────────────────────────────────────────
  /// Returns any non-blocking warnings (e.g. tank-capacity checks) computed
  /// server-side for the newly created record.
  Future<List<String>> createRecord(CreateDieselDto dto) async {
    final warnings =
        await ref.read(dieselRepositoryProvider).createRecord(dto);
    await changePage(1);
    return warnings;
  }

  Future<void> updateRecord(UpdateDieselDto dto) async {
    await ref.read(dieselRepositoryProvider).updateRecord(dto);
    await refresh();
  }

  Future<void> deleteRecord(int id) async {
    await ref.read(dieselRepositoryProvider).deleteRecord(id);
    await refresh();
  }
}
