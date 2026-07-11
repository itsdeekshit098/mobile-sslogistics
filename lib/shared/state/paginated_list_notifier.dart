import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'list_filters.dart';
import 'paged_result.dart';
import 'paginated_list_state.dart';

/// Base AsyncNotifier for a server-paginated list screen. Owns pagination,
/// search, filtering, the autoDispose "was I torn down mid-fetch" guard, and
/// the page-clamp-after-delete behavior every feature used to hand-roll.
/// Subclasses implement [initialFilters] and [fetchPage]; CRUD methods that
/// need custom follow-up behavior stay feature-local and call [refresh].
abstract class PaginatedListNotifier<T, F extends ListFilters, X>
    extends AutoDisposeAsyncNotifier<PaginatedListState<T, F, X>> {
  // Tracks disposal explicitly because this riverpod version doesn't expose
  // `ref.mounted`. Without this, a mutator awaiting a fetch can resolve
  // after autoDispose tears the notifier down (e.g. the screen was navigated
  // away from mid-search) and writing to `state` then throws
  // "Bad state: Future already completed".
  bool _disposed = false;

  /// The "no filters applied" value, used for the first fetch and by
  /// [clearFilters].
  F get initialFilters;

  /// Page size used for the first fetch (before [changePageSize] runs).
  int get defaultPageSize => 10;

  /// Whether an empty page past page 1 should clamp back to the last
  /// non-empty page. True for ordinary out-of-bounds requests (e.g. the
  /// last item on the final page was just deleted); a feature whose filters
  /// can legitimately produce a valid empty page (e.g. a client-side
  /// inactive-only filter where "no inactive rows on this page" isn't the
  /// same as "past the end of the list") should override this per-filters.
  bool shouldClampPage(F filters) => true;

  /// Fetches one page. Implementations call their repository and translate
  /// its response into a [PagedResult]; pagination/filter bookkeeping is
  /// handled by this base class.
  Future<PagedResult<T, X>> fetchPage({
    required int page,
    required int pageSize,
    required String search,
    required F filters,
  });

  @override
  Future<PaginatedListState<T, F, X>> build() {
    ref.onDispose(() => _disposed = true);
    return _fetch(page: 1, pageSize: defaultPageSize, search: '', filters: initialFilters);
  }

  Future<PaginatedListState<T, F, X>> _fetch({
    required int page,
    required int pageSize,
    required String search,
    required F filters,
  }) async {
    var result = await fetchPage(page: page, pageSize: pageSize, search: search, filters: filters);
    // The requested page can fall past the end (e.g. the last item on the
    // final page was just deleted) — clamp to the last non-empty page.
    if (result.items.isEmpty && result.total > 0 && page > 1 && shouldClampPage(filters)) {
      final lastPage = (result.total / pageSize).ceil();
      page = lastPage < 1 ? 1 : lastPage;
      result = await fetchPage(page: page, pageSize: pageSize, search: search, filters: filters);
    }
    return PaginatedListState<T, F, X>(
      items: result.items,
      total: result.total,
      extras: result.extras,
      page: page,
      pageSize: pageSize,
      search: search,
      filters: filters,
    );
  }

  Future<void> _apply({
    int? page,
    int? pageSize,
    String? search,
    F? filters,
    bool showLoading = true,
  }) async {
    final cur = state.valueOrNull;
    if (showLoading) state = const AsyncLoading();
    final result = await AsyncValue.guard(() => _fetch(
          page: page ?? 1,
          pageSize: pageSize ?? cur?.pageSize ?? defaultPageSize,
          search: search ?? cur?.search ?? '',
          filters: filters ?? cur?.filters ?? initialFilters,
        ));
    // Guard against the provider being torn down (autoDispose, e.g. the
    // screen was navigated away from) while the fetch above was in flight —
    // writing to `state` after disposal throws "Bad state: Future already
    // completed".
    if (_disposed) return;
    state = result;
  }

  /// Re-fetches the current page/search/filters. Used for pull-to-refresh
  /// and after a create/update/delete.
  Future<void> refresh({bool showLoading = true}) =>
      _apply(page: state.valueOrNull?.page, showLoading: showLoading);

  Future<void> search(String value) => _apply(search: value.trim());

  Future<void> applyFilters(F filters) => _apply(filters: filters);

  Future<void> clearFilters() => _apply(search: '', filters: initialFilters);

  Future<void> changePage(int page) => _apply(page: page);

  Future<void> changePageSize(int pageSize) => _apply(pageSize: pageSize);
}
