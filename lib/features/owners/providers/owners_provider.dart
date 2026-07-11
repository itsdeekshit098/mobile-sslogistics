import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/state/list_filters.dart';
import '../../../shared/state/paged_result.dart';
import '../../../shared/state/paginated_list_notifier.dart';
import '../../../shared/state/paginated_list_state.dart';
import '../data/owner_models.dart';
import '../data/owner_repository.dart';

final ownerRepositoryProvider = Provider<OwnerRepository>((ref) => OwnerRepository());

class OwnerFilters implements ListFilters {
  final String? ownerType;

  const OwnerFilters({this.ownerType});

  @override
  bool get isActive => ownerType != null;

  OwnerFilters copyWith({String? ownerType, bool clearOwnerType = false}) =>
      OwnerFilters(ownerType: clearOwnerType ? null : (ownerType ?? this.ownerType));
}

typedef OwnersState = PaginatedListState<VehicleOwner, OwnerFilters, void>;

extension OwnersStateX on OwnersState {
  List<VehicleOwner> get owners => items;
  String? get ownerTypeFilter => filters.ownerType;
}

/// autoDispose so a switched-user login doesn't briefly show stale owners.
final ownersListProvider =
    AsyncNotifierProvider.autoDispose<OwnersNotifier, OwnersState>(OwnersNotifier.new);

class OwnersNotifier extends PaginatedListNotifier<VehicleOwner, OwnerFilters, void> {
  @override
  OwnerFilters get initialFilters => const OwnerFilters();

  @override
  int get defaultPageSize => 20;

  @override
  Future<PagedResult<VehicleOwner, void>> fetchPage({
    required int page,
    required int pageSize,
    required String search,
    required OwnerFilters filters,
  }) async {
    final data = await ref.read(ownerRepositoryProvider).getOwners(
          page: page,
          pageSize: pageSize,
          search: search,
          ownerType: filters.ownerType,
        );
    return PagedResult(items: data.owners, total: data.total, extras: null);
  }

  Future<void> setOwnerTypeFilter(String? ownerType) =>
      applyFilters(OwnerFilters(ownerType: ownerType));

  Future<void> createOwner(CreateOwnerDto dto) async {
    await ref.read(ownerRepositoryProvider).createOwner(dto);
    await refresh();
  }

  Future<void> updateOwner(UpdateOwnerDto dto) async {
    await ref.read(ownerRepositoryProvider).updateOwner(dto);
    await refresh();
  }

  Future<void> deleteOwner(int id) async {
    await ref.read(ownerRepositoryProvider).deleteOwner(id);
    await refresh();
  }
}
