import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/entity_models.dart';
import '../../../shared/data/entity_repository.dart';
import '../../../shared/state/list_filters.dart';
import '../../../shared/state/paged_result.dart';
import '../../../shared/state/paginated_list_notifier.dart';
import '../../../shared/state/paginated_list_state.dart';

final entityRepositoryProvider = Provider<EntityRepository>((ref) => EntityRepository());

class OwnerFilters implements ListFilters {
  final String? entityKind;
  final String? relationship;

  const OwnerFilters({this.entityKind, this.relationship});

  @override
  bool get isActive => entityKind != null || relationship != null;

  OwnerFilters copyWith({
    String? entityKind,
    bool clearEntityKind = false,
    String? relationship,
    bool clearRelationship = false,
  }) =>
      OwnerFilters(
        entityKind: clearEntityKind ? null : (entityKind ?? this.entityKind),
        relationship: clearRelationship ? null : (relationship ?? this.relationship),
      );
}

typedef OwnersState = PaginatedListState<Entity, OwnerFilters, void>;

/// autoDispose so a switched-user login doesn't briefly show stale entities.
final ownersListProvider =
    AsyncNotifierProvider.autoDispose<OwnersNotifier, OwnersState>(OwnersNotifier.new);

class OwnersNotifier extends PaginatedListNotifier<Entity, OwnerFilters, void> {
  @override
  OwnerFilters get initialFilters => const OwnerFilters();

  @override
  int get defaultPageSize => 20;

  @override
  Future<PagedResult<Entity, void>> fetchPage({
    required int page,
    required int pageSize,
    required String search,
    required OwnerFilters filters,
  }) async {
    final data = await ref.read(entityRepositoryProvider).fetchPage(
          page: page,
          pageSize: pageSize,
          search: search,
          entityKind: filters.entityKind,
          relationship: filters.relationship,
        );
    return PagedResult(items: data.entities, total: data.total, extras: null);
  }

  Future<void> setFilters(OwnerFilters filters) => applyFilters(filters);

  Future<void> createEntity({
    required String name,
    required String entityKind,
    String relationship = 'INTERNAL',
    int? proprietorEntityId,
    String? phone,
    String? email,
    String? pan,
    String? gstNumber,
    String? address,
    String? notes,
  }) async {
    await ref.read(entityRepositoryProvider).create(
          name: name,
          entityKind: entityKind,
          relationship: relationship,
          proprietorEntityId: proprietorEntityId,
          phone: phone,
          email: email,
          pan: pan,
          gstNumber: gstNumber,
          address: address,
          notes: notes,
        );
    await refresh();
  }

  Future<void> updateEntity({
    required int id,
    String? name,
    String? entityKind,
    String? relationship,
    int? proprietorEntityId,
    bool clearProprietor = false,
    String? phone,
    String? email,
    String? pan,
    String? gstNumber,
    String? address,
    String? notes,
  }) async {
    await ref.read(entityRepositoryProvider).update(
          id: id,
          name: name,
          entityKind: entityKind,
          relationship: relationship,
          proprietorEntityId: proprietorEntityId,
          clearProprietor: clearProprietor,
          phone: phone,
          email: email,
          pan: pan,
          gstNumber: gstNumber,
          address: address,
          notes: notes,
        );
    await refresh();
  }

  Future<void> deleteEntity(int id) async {
    await ref.read(entityRepositoryProvider).delete(id);
    await refresh();
  }
}
