import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/owner_models.dart';
import '../data/owner_repository.dart';

final ownerRepositoryProvider = Provider<OwnerRepository>((ref) => OwnerRepository());

class OwnersState {
  final List<VehicleOwner> owners;
  final String search;
  final String? ownerTypeFilter;

  const OwnersState({required this.owners, this.search = '', this.ownerTypeFilter});

  OwnersState copyWith({
    List<VehicleOwner>? owners,
    String? search,
    String? ownerTypeFilter,
    bool clearOwnerTypeFilter = false,
  }) {
    return OwnersState(
      owners: owners ?? this.owners,
      search: search ?? this.search,
      ownerTypeFilter: clearOwnerTypeFilter ? null : (ownerTypeFilter ?? this.ownerTypeFilter),
    );
  }
}

/// autoDispose so a switched-user login doesn't briefly show stale owners.
final ownersListProvider =
    AsyncNotifierProvider.autoDispose<OwnersNotifier, OwnersState>(OwnersNotifier.new);

class OwnersNotifier extends AutoDisposeAsyncNotifier<OwnersState> {
  bool _disposed = false;

  @override
  Future<OwnersState> build() {
    ref.onDispose(() => _disposed = true);
    return _fetch();
  }

  Future<OwnersState> _fetch({String search = '', String? ownerTypeFilter}) async {
    final owners = await ref
        .read(ownerRepositoryProvider)
        .getOwners(ownerType: ownerTypeFilter, search: search);
    return OwnersState(owners: owners, search: search, ownerTypeFilter: ownerTypeFilter);
  }

  Future<void> refresh({bool showLoading = true}) async {
    final current = state.valueOrNull;
    if (showLoading) state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _fetch(search: current?.search ?? '', ownerTypeFilter: current?.ownerTypeFilter),
    );
    if (_disposed) return;
    state = result;
  }

  Future<void> search(String value) async {
    final current = state.valueOrNull;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _fetch(search: value, ownerTypeFilter: current?.ownerTypeFilter),
    );
    if (_disposed) return;
    state = result;
  }

  Future<void> setOwnerTypeFilter(String? ownerType) async {
    final current = state.valueOrNull;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _fetch(search: current?.search ?? '', ownerTypeFilter: ownerType),
    );
    if (_disposed) return;
    state = result;
  }

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
