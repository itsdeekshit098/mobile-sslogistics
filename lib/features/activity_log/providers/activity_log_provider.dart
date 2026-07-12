import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/activity_log_models.dart';
import '../data/activity_log_repository.dart';

const _pageSize = 20;

final activityLogRepositoryProvider = Provider<ActivityLogRepository>(
  (ref) => ActivityLogRepository(),
);

/// Infinite-scroll feed state — unlike the page-numbered lists elsewhere in
/// the app, Activity Log is read-only and chronological, so scrolling
/// further back reads more naturally than jumping between page numbers.
class ActivityLogState {
  final List<ActivityLogEntry> entries;
  final int total;
  final int page;
  final bool isLoadingMore;
  final String? loadMoreError;

  const ActivityLogState({
    required this.entries,
    required this.total,
    this.page = 1,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  bool get hasMore => entries.length < total;

  ActivityLogState copyWith({
    List<ActivityLogEntry>? entries,
    int? total,
    int? page,
    bool? isLoadingMore,
    String? loadMoreError,
    bool clearLoadMoreError = false,
  }) {
    return ActivityLogState(
      entries: entries ?? this.entries,
      total: total ?? this.total,
      page: page ?? this.page,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError:
          clearLoadMoreError ? null : (loadMoreError ?? this.loadMoreError),
    );
  }
}

/// autoDispose so a switched-user login doesn't briefly show the previous
/// user's cached activity feed.
final activityLogProvider =
    AsyncNotifierProvider.autoDispose<ActivityLogNotifier, ActivityLogState>(
      ActivityLogNotifier.new,
    );

class ActivityLogNotifier extends AutoDisposeAsyncNotifier<ActivityLogState> {
  bool _disposed = false;

  @override
  Future<ActivityLogState> build() {
    ref.onDispose(() => _disposed = true);
    return _fetchFirstPage();
  }

  Future<ActivityLogState> _fetchFirstPage() async {
    final data = await ref.read(activityLogRepositoryProvider).getEntries(page: 1, limit: _pageSize);
    return ActivityLogState(entries: data.entries, total: data.total, page: 1);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(_fetchFirstPage);
    if (_disposed) return;
    state = result;
  }

  Future<void> loadMore() async {
    final cur = state.valueOrNull;
    if (cur == null || cur.isLoadingMore || !cur.hasMore) return;

    state = AsyncData(cur.copyWith(isLoadingMore: true, clearLoadMoreError: true));
    try {
      final nextPage = cur.page + 1;
      final data = await ref
          .read(activityLogRepositoryProvider)
          .getEntries(page: nextPage, limit: _pageSize);
      if (_disposed) return;
      final latest = state.valueOrNull ?? cur;
      state = AsyncData(
        latest.copyWith(
          entries: [...latest.entries, ...data.entries],
          total: data.total,
          page: nextPage,
          isLoadingMore: false,
        ),
      );
    } catch (e) {
      if (_disposed) return;
      final latest = state.valueOrNull ?? cur;
      state = AsyncData(latest.copyWith(
        isLoadingMore: false,
        loadMoreError: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }
}
