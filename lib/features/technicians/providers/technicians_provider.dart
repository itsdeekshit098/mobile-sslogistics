import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/technician_models.dart';
import '../data/technician_repository.dart';

final technicianRepositoryProvider =
    Provider<TechnicianRepository>((ref) => TechnicianRepository());

/// Specialization options for the multi-select chips — invalidated whenever
/// a new one is added inline from the form sheet.
final specializationOptionsProvider =
    FutureProvider.autoDispose<List<SpecializationOption>>(
  (ref) => ref.read(technicianRepositoryProvider).getSpecializations(),
);

class TechniciansState {
  final List<Technician> technicians;
  final int total;
  final int page;
  final int pageSize;
  final String search;
  final bool includeInactive;

  const TechniciansState({
    required this.technicians,
    required this.total,
    this.page = 1,
    this.pageSize = 20,
    this.search = '',
    this.includeInactive = false,
  });

  int get totalPages => total == 0 ? 1 : (total / pageSize).ceil();

  TechniciansState copyWith({
    List<Technician>? technicians,
    int? total,
    int? page,
    int? pageSize,
    String? search,
    bool? includeInactive,
  }) {
    return TechniciansState(
      technicians: technicians ?? this.technicians,
      total: total ?? this.total,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      search: search ?? this.search,
      includeInactive: includeInactive ?? this.includeInactive,
    );
  }
}

final techniciansListProvider =
    AsyncNotifierProvider.autoDispose<TechniciansNotifier, TechniciansState>(
  TechniciansNotifier.new,
);

class TechniciansNotifier extends AutoDisposeAsyncNotifier<TechniciansState> {
  bool _disposed = false;

  @override
  Future<TechniciansState> build() {
    ref.onDispose(() => _disposed = true);
    return _fetch();
  }

  Future<TechniciansState> _fetch({
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
    var data = await ref.read(technicianRepositoryProvider).getTechnicians(
          page: page,
          pageSize: pageSize,
          search: search,
          includeInactive: includeInactive,
        );
    // Only clamp to the last page for a true out-of-bounds page request —
    // when filtering to inactive-only, an empty page can legitimately mean
    // "no inactive technicians on this page", not "past the end of the list".
    if (!includeInactive && data.technicians.isEmpty && data.total > 0 && page > 1) {
      final lastPage = (data.total / pageSize).ceil();
      page = lastPage < 1 ? 1 : lastPage;
      data = await ref.read(technicianRepositoryProvider).getTechnicians(
            page: page,
            pageSize: pageSize,
            search: search,
            includeInactive: includeInactive,
          );
    }
    final technicians =
        includeInactive ? data.technicians.where((t) => !t.isActive).toList() : data.technicians;
    final total = includeInactive ? technicians.length : data.total;
    return TechniciansState(
      technicians: technicians,
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

  Future<void> createTechnician(CreateTechnicianDto dto) async {
    await ref.read(technicianRepositoryProvider).createTechnician(dto);
    await refresh();
  }

  Future<void> updateTechnician(UpdateTechnicianDto dto) async {
    await ref.read(technicianRepositoryProvider).updateTechnician(dto);
    await refresh();
  }

  Future<void> toggleActive(Technician technician) async {
    await ref
        .read(technicianRepositoryProvider)
        .updateTechnician(UpdateTechnicianDto(id: technician.id, isActive: !technician.isActive));
    await refresh(showLoading: false);
  }

  Future<void> deleteTechnician(int id) async {
    await ref.read(technicianRepositoryProvider).deleteTechnician(id);
    await refresh();
  }
}
