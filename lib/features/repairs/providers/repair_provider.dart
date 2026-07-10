import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repair_repository.dart';
import '../data/repair_models.dart';

const _pageSize = 15;

/// UI state for the repair records list screen.
class RepairListState {
  final List<RepairRecord> records;
  final int total;
  final RepairSummary? summary;
  final int page;
  final RepairFilters filters;
  final bool isLoadingMore;

  const RepairListState({
    required this.records,
    required this.total,
    this.summary,
    this.page = 1,
    this.filters = const RepairFilters(),
    this.isLoadingMore = false,
  });

  bool get hasMore => records.length < total;

  RepairListState copyWith({
    List<RepairRecord>? records,
    int? total,
    RepairSummary? summary,
    bool clearSummary = false,
    int? page,
    RepairFilters? filters,
    bool? isLoadingMore,
  }) {
    return RepairListState(
      records: records ?? this.records,
      total: total ?? this.total,
      summary: clearSummary ? null : (summary ?? this.summary),
      page: page ?? this.page,
      filters: filters ?? this.filters,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

final repairRepositoryProvider = Provider<RepairRepository>(
  (ref) => RepairRepository(),
);

final repairListProvider =
    AsyncNotifierProvider<RepairListNotifier, RepairListState>(
  RepairListNotifier.new,
);

class RepairListNotifier extends AsyncNotifier<RepairListState> {
  @override
  Future<RepairListState> build() => _fetchFirstPage(const RepairFilters());

  Future<RepairListState> _fetchFirstPage(RepairFilters filters) async {
    final data = await ref
        .read(repairRepositoryProvider)
        .getRecords(filters: filters, page: 1, pageSize: _pageSize);
    return RepairListState(
      records: data.records,
      total: data.total,
      summary: data.summary,
      page: 1,
      filters: filters,
    );
  }

  Future<void> refresh() async {
    final filters = state.valueOrNull?.filters ?? const RepairFilters();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchFirstPage(filters));
  }

  Future<void> setFilters(RepairFilters filters) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchFirstPage(filters));
  }

  Future<void> loadMore() async {
    final cur = state.valueOrNull;
    if (cur == null || cur.isLoadingMore || !cur.hasMore) return;

    state = AsyncData(cur.copyWith(isLoadingMore: true));
    try {
      final nextPage = cur.page + 1;
      final data = await ref.read(repairRepositoryProvider).getRecords(
            filters: cur.filters,
            page: nextPage,
            pageSize: _pageSize,
            includeSummary: false,
          );
      final latest = state.valueOrNull ?? cur;
      state = AsyncData(
        latest.copyWith(
          records: [...latest.records, ...data.records],
          total: data.total,
          page: nextPage,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      final latest = state.valueOrNull ?? cur;
      state = AsyncData(latest.copyWith(isLoadingMore: false));
    }
  }

  Future<void> createRecord(CreateRepairDto dto) async {
    await ref.read(repairRepositoryProvider).createRecord(dto);
    await refresh();
  }

  Future<void> updateRecord(UpdateRepairDto dto) async {
    await ref.read(repairRepositoryProvider).updateRecord(dto);
    await refresh();
  }

  Future<void> deleteRecord(int id) async {
    await ref.read(repairRepositoryProvider).deleteRecord(id);
    await refresh();
  }
}

/// Issue name options grouped by category — fetched lazily when a
/// create/edit sheet opens.
final repairIssueOptionsProvider = FutureProvider<Map<String, List<String>>>(
  (ref) => ref.read(repairRepositoryProvider).getIssueOptions(),
);

final techniciansProvider = FutureProvider<List<Technician>>(
  (ref) => ref.read(repairRepositoryProvider).getTechnicians(),
);

final vendorsProvider = FutureProvider<List<Vendor>>(
  (ref) => ref.read(repairRepositoryProvider).getVendors(),
);

final partOptionsProvider = FutureProvider<List<PartOption>>(
  (ref) => ref.read(repairRepositoryProvider).getPartOptions(),
);
