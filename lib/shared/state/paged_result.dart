/// Raw result of a single page fetch, before it's wrapped into
/// [PaginatedListState]. [extras] carries any side-payload a feature's list
/// endpoint returns alongside the page (e.g. vehicle fleet stats); features
/// without one use `void`/`null`.
class PagedResult<T, X> {
  final List<T> items;
  final int total;
  final X extras;

  const PagedResult({required this.items, required this.total, required this.extras});
}
