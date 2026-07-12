import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/trip_booking_repository.dart';
import '../data/trip_booking_models.dart';

const _pageSize = 20; // API caps page_size at 50

/// UI state for the trip bookings list screen (infinite scroll).
class TripBookingListState {
  /// Accumulated rows across all loaded pages.
  final List<TripBooking> bookings;
  final int total;
  final int page; // last loaded page
  final TripBookingSummary? summary;
  final bool isLoadingMore;
  final String? loadMoreError;

  // Active filters — status defaults to 'confirmed' to match the web page.
  final String status;
  final String? onDate; // 'YYYY-MM-DD' — exact match, overrides from/toDate
  final String? fromDate; // 'YYYY-MM-DD'
  final String? toDate;
  final String? search;

  const TripBookingListState({
    required this.bookings,
    required this.total,
    this.page = 1,
    this.summary,
    this.isLoadingMore = false,
    this.loadMoreError,
    this.status = statusConfirmed,
    this.onDate,
    this.fromDate,
    this.toDate,
    this.search,
  });

  bool get hasMore => bookings.length < total;

  bool get hasFilters =>
      status != statusConfirmed ||
      onDate != null ||
      fromDate != null ||
      toDate != null ||
      (search != null && search!.isNotEmpty);

  TripBookingListState copyWith({
    List<TripBooking>? bookings,
    int? total,
    int? page,
    TripBookingSummary? summary,
    bool? isLoadingMore,
    String? loadMoreError,
    bool clearLoadMoreError = false,
  }) {
    return TripBookingListState(
      bookings: bookings ?? this.bookings,
      total: total ?? this.total,
      page: page ?? this.page,
      summary: summary ?? this.summary,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError:
          clearLoadMoreError ? null : (loadMoreError ?? this.loadMoreError),
      status: status,
      onDate: onDate,
      fromDate: fromDate,
      toDate: toDate,
      search: search,
    );
  }
}

final tripBookingRepositoryProvider = Provider<TripBookingRepository>(
  (ref) => TripBookingRepository(),
);

/// autoDispose so the cached list dies with its last listener — otherwise a
/// logout/login as a different user would briefly show the previous user's
/// bookings (nothing invalidates feature providers on auth changes).
final tripBookingListProvider =
    AsyncNotifierProvider.autoDispose<
      TripBookingListNotifier,
      TripBookingListState
    >(TripBookingListNotifier.new);

class TripBookingListNotifier
    extends AutoDisposeAsyncNotifier<TripBookingListState> {
  // Tracks disposal explicitly because this riverpod version doesn't expose
  // `ref.mounted`. Without this, a mutator awaiting a fetch can resolve
  // after autoDispose tears the notifier down (e.g. the screen was navigated
  // away from mid-fetch) and writing to `state` then throws
  // "Bad state: Future already completed".
  bool _disposed = false;

  @override
  Future<TripBookingListState> build() {
    ref.onDispose(() => _disposed = true);
    return _fetchFirstPage(status: statusConfirmed);
  }

  /// Loads page 1 (with summary) for the given filters.
  Future<TripBookingListState> _fetchFirstPage({
    required String status,
    String? onDate,
    String? fromDate,
    String? toDate,
    String? search,
  }) async {
    final data = await ref.read(tripBookingRepositoryProvider).getBookings(
          status: status == 'all' ? null : status,
          onDate: onDate,
          fromDate: fromDate,
          toDate: toDate,
          search: search,
          page: 1,
          pageSize: _pageSize,
        );
    return TripBookingListState(
      bookings: data.bookings,
      total: data.total,
      page: 1,
      summary: data.summary,
      status: status,
      onDate: onDate,
      fromDate: fromDate,
      toDate: toDate,
      search: search,
    );
  }

  /// Appends the next page without dropping the rendered list (no
  /// AsyncLoading flash) and skips the summary RPC server-side.
  Future<void> loadMore() async {
    final cur = state.valueOrNull;
    if (cur == null || cur.isLoadingMore || !cur.hasMore) return;

    state = AsyncData(cur.copyWith(isLoadingMore: true, clearLoadMoreError: true));
    try {
      final data = await ref.read(tripBookingRepositoryProvider).getBookings(
            status: cur.status == 'all' ? null : cur.status,
            onDate: cur.onDate,
            fromDate: cur.fromDate,
            toDate: cur.toDate,
            search: cur.search,
            page: cur.page + 1,
            pageSize: _pageSize,
            includeSummary: false,
          );
      if (_disposed) return;
      state = AsyncData(cur.copyWith(
        bookings: [...cur.bookings, ...data.bookings],
        total: data.total,
        page: cur.page + 1,
        isLoadingMore: false,
      ));
    } catch (e) {
      // Keep what's on screen; the scroll trigger will retry naturally.
      if (_disposed) return;
      state = AsyncData(cur.copyWith(
        isLoadingMore: false,
        loadMoreError: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  /// Replaces all filters and reloads from page 1 (summary included).
  Future<void> applyFilters({
    String status = statusConfirmed,
    String? onDate,
    String? fromDate,
    String? toDate,
    String? search,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _fetchFirstPage(
        status: status,
        onDate: onDate,
        fromDate: onDate == null ? fromDate : null,
        toDate: onDate == null ? toDate : null,
        search: search,
      ),
    );
    if (_disposed) return;
    state = result;
  }

  /// Pull-to-refresh: reload page 1 with the current filters, no flash.
  Future<void> refresh() async {
    final cur = state.valueOrNull;
    final result = await AsyncValue.guard(
      () => _fetchFirstPage(
        status: cur?.status ?? statusConfirmed,
        onDate: cur?.onDate,
        fromDate: cur?.fromDate,
        toDate: cur?.toDate,
        search: cur?.search,
      ),
    );
    if (_disposed) return;
    state = result;
  }

  Future<void> _reloadAfterMutation() async {
    final cur = state.valueOrNull;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _fetchFirstPage(
        status: cur?.status ?? statusConfirmed,
        onDate: cur?.onDate,
        fromDate: cur?.fromDate,
        toDate: cur?.toDate,
        search: cur?.search,
      ),
    );
    if (_disposed) return;
    state = result;
  }

  Future<void> createBooking(CreateTripBookingDto dto) async {
    await ref.read(tripBookingRepositoryProvider).createBooking(dto);
    await _reloadAfterMutation();
  }

  Future<void> updateBooking(UpdateTripBookingDto dto) async {
    await ref.read(tripBookingRepositoryProvider).updateBooking(dto);
    await _reloadAfterMutation();
  }

  Future<void> cancelBooking(int id) async {
    await ref.read(tripBookingRepositoryProvider).cancelBooking(id);
    await _reloadAfterMutation();
  }
}
