import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/state/list_filters.dart';
import '../../../shared/state/paged_result.dart';
import '../../../shared/state/paginated_list_notifier.dart';
import '../../../shared/state/paginated_list_state.dart';
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

class TechnicianFilters implements ListFilters {
  final bool includeInactive;

  const TechnicianFilters({this.includeInactive = false});

  @override
  bool get isActive => includeInactive;
}

typedef TechniciansState = PaginatedListState<Technician, TechnicianFilters, void>;

extension TechniciansStateX on TechniciansState {
  List<Technician> get technicians => items;
  bool get includeInactive => filters.includeInactive;
}

final techniciansListProvider =
    AsyncNotifierProvider.autoDispose<TechniciansNotifier, TechniciansState>(
  TechniciansNotifier.new,
);

class TechniciansNotifier
    extends PaginatedListNotifier<Technician, TechnicianFilters, void> {
  @override
  TechnicianFilters get initialFilters => const TechnicianFilters();

  @override
  int get defaultPageSize => 20;

  // Only clamp to the last page for a true out-of-bounds page request —
  // when filtering to inactive-only, an empty page can legitimately mean
  // "no inactive technicians on this page", not "past the end of the list".
  @override
  bool shouldClampPage(TechnicianFilters filters) => !filters.includeInactive;

  @override
  Future<PagedResult<Technician, void>> fetchPage({
    required int page,
    required int pageSize,
    required String search,
    required TechnicianFilters filters,
  }) async {
    // The API's include_inactive flag is additive (active+inactive together),
    // not an inactive-only filter — it has no server-side way to ask for
    // "only inactive". So when the "Inactive" chip is on, fetch with the
    // flag set to get inactive rows included at all, then filter this page
    // down to inactive-only client-side so the chip actually does what its
    // label says instead of just silently adding rows that may not exist.
    final data = await ref.read(technicianRepositoryProvider).getTechnicians(
          page: page,
          pageSize: pageSize,
          search: search,
          includeInactive: filters.includeInactive,
        );
    final technicians = filters.includeInactive
        ? data.technicians.where((t) => !t.isActive).toList()
        : data.technicians;
    final total = filters.includeInactive ? technicians.length : data.total;
    return PagedResult(items: technicians, total: total, extras: null);
  }

  Future<void> toggleIncludeInactive(bool value) =>
      applyFilters(TechnicianFilters(includeInactive: value));

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
