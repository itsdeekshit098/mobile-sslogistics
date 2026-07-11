/// Contract a feature's filter object must satisfy to plug into
/// [PaginatedListState.hasFilters]. [isActive] should be true whenever any
/// filter differs from its "no filter applied" default.
abstract interface class ListFilters {
  bool get isActive;
}

/// Filters object for features with no filter bar (search-only lists).
class NoFilters implements ListFilters {
  const NoFilters();

  @override
  bool get isActive => false;
}
