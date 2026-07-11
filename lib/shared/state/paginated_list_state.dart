import 'list_filters.dart';

/// Generic UI state for a server-paginated list screen: page/pageSize/search
/// plus a feature-specific [filters] object and an optional [extras]
/// side-payload (e.g. fleet stats). Replaces the near-identical hand-rolled
/// `XState` class each feature used to define.
class PaginatedListState<T, F extends ListFilters, X> {
  final List<T> items;
  final int total;
  final int page;
  final int pageSize;
  final String search;
  final F filters;
  final X extras;

  const PaginatedListState({
    required this.items,
    required this.total,
    required this.filters,
    required this.extras,
    this.page = 1,
    this.pageSize = 10,
    this.search = '',
  });

  int get totalPages => total == 0 ? 1 : (total / pageSize).ceil();
  bool get hasFilters => search.isNotEmpty || filters.isActive;

  PaginatedListState<T, F, X> copyWith({
    List<T>? items,
    int? total,
    int? page,
    int? pageSize,
    String? search,
    F? filters,
    X? extras,
  }) {
    return PaginatedListState<T, F, X>(
      items: items ?? this.items,
      total: total ?? this.total,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      search: search ?? this.search,
      filters: filters ?? this.filters,
      extras: extras ?? this.extras,
    );
  }
}
