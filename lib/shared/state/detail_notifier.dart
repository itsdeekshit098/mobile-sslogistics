import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Base notifier for a "fetch one record by id" detail screen — the loan,
/// funding and client detail screens all sit on this.
///
/// Carries the same explicit `_disposed` guard as [PaginatedListNotifier]: this
/// riverpod version doesn't expose `ref.mounted`, so a mutator that awaits a
/// refetch can resolve after autoDispose has torn the notifier down (the user
/// backed out while a payment was saving) and writing to `state` then throws
/// "Bad state: Future already completed".
abstract class DetailNotifier<T> extends AutoDisposeFamilyAsyncNotifier<T, int> {
  bool _disposed = false;

  /// The record id this notifier was created for.
  int get recordId => arg;

  /// Fetches the record. Implementations call their repository; everything
  /// else here is bookkeeping.
  Future<T> fetchDetail(int id);

  @override
  Future<T> build(int arg) {
    ref.onDispose(() => _disposed = true);
    return fetchDetail(arg);
  }

  /// Re-fetches the record after a mutation.
  ///
  /// [showLoading] false keeps the current data on screen while the refetch is
  /// in flight — the detail screens use that so recording a payment doesn't
  /// blank the whole page and lose the user's scroll position in a 36-row
  /// schedule.
  Future<void> refresh({bool showLoading = false}) async {
    if (showLoading) state = const AsyncLoading();
    final result = await AsyncValue.guard(() => fetchDetail(recordId));
    if (_disposed) return;
    state = result;
  }

  /// Runs a mutation, then refreshes. Rethrows so the calling sheet can show
  /// the server's message inline and keep the user's input.
  Future<void> mutate(Future<void> Function() action) async {
    await action();
    if (_disposed) return;
    await refresh();
  }
}
