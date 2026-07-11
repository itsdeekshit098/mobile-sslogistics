import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/external_trip_repository.dart';
import '../data/external_trip_models.dart';

const _pageSize = 20; // API caps page_size at 50

/// UI state for the external trips list screen (infinite scroll).
class ExternalTripListState {
  /// Accumulated rows across all loaded pages.
  final List<ExternalTrip> trips;
  final int total;
  final int page; // last loaded page
  final ExternalTripSummary? summary;
  final bool isLoadingMore;

  // Active filters
  final String? fromDate; // 'YYYY-MM-DD'
  final String? toDate;
  final int? vehicleId;
  final String? tripType;

  const ExternalTripListState({
    required this.trips,
    required this.total,
    this.page = 1,
    this.summary,
    this.isLoadingMore = false,
    this.fromDate,
    this.toDate,
    this.vehicleId,
    this.tripType,
  });

  bool get hasMore => trips.length < total;

  bool get hasFilters =>
      fromDate != null || toDate != null || vehicleId != null || tripType != null;

  ExternalTripListState copyWith({
    List<ExternalTrip>? trips,
    int? total,
    int? page,
    ExternalTripSummary? summary,
    bool? isLoadingMore,
  }) {
    return ExternalTripListState(
      trips: trips ?? this.trips,
      total: total ?? this.total,
      page: page ?? this.page,
      summary: summary ?? this.summary,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      fromDate: fromDate,
      toDate: toDate,
      vehicleId: vehicleId,
      tripType: tripType,
    );
  }
}

final externalTripRepositoryProvider = Provider<ExternalTripRepository>(
  (ref) => ExternalTripRepository(),
);

/// Active drivers for the driver picker in the create/edit forms.
final driversProvider = FutureProvider<List<Driver>>(
  (ref) => ref.read(externalTripRepositoryProvider).getDrivers(),
);

/// autoDispose so the cached list dies with its last listener — otherwise a
/// logout/login as a different user would briefly show the previous user's
/// external trips (nothing invalidates feature providers on auth changes).
final externalTripListProvider =
    AsyncNotifierProvider.autoDispose<
      ExternalTripListNotifier,
      ExternalTripListState
    >(ExternalTripListNotifier.new);

class ExternalTripListNotifier
    extends AutoDisposeAsyncNotifier<ExternalTripListState> {
  // Tracks disposal explicitly because this riverpod version doesn't expose
  // `ref.mounted`. Without this, a mutator awaiting a fetch can resolve
  // after autoDispose tears the notifier down (e.g. the screen was navigated
  // away from mid-fetch) and writing to `state` then throws
  // "Bad state: Future already completed".
  bool _disposed = false;

  @override
  Future<ExternalTripListState> build() {
    ref.onDispose(() => _disposed = true);
    return _fetchFirstPage();
  }

  /// Loads page 1 (with summary) for the given filters.
  Future<ExternalTripListState> _fetchFirstPage({
    String? fromDate,
    String? toDate,
    int? vehicleId,
    String? tripType,
  }) async {
    final data = await ref.read(externalTripRepositoryProvider).getTrips(
          fromDate: fromDate,
          toDate: toDate,
          vehicleId: vehicleId,
          tripType: tripType,
          page: 1,
          pageSize: _pageSize,
        );
    return ExternalTripListState(
      trips: data.trips,
      total: data.total,
      page: 1,
      summary: data.summary,
      fromDate: fromDate,
      toDate: toDate,
      vehicleId: vehicleId,
      tripType: tripType,
    );
  }

  /// Appends the next page without dropping the rendered list (no
  /// AsyncLoading flash) and skips the summary RPC server-side.
  Future<void> loadMore() async {
    final cur = state.valueOrNull;
    if (cur == null || cur.isLoadingMore || !cur.hasMore) return;

    state = AsyncData(cur.copyWith(isLoadingMore: true));
    try {
      final data = await ref.read(externalTripRepositoryProvider).getTrips(
            fromDate: cur.fromDate,
            toDate: cur.toDate,
            vehicleId: cur.vehicleId,
            tripType: cur.tripType,
            page: cur.page + 1,
            pageSize: _pageSize,
            includeSummary: false,
          );
      if (_disposed) return;
      state = AsyncData(cur.copyWith(
        trips: [...cur.trips, ...data.trips],
        total: data.total,
        page: cur.page + 1,
        isLoadingMore: false,
      ));
    } catch (_) {
      // Keep what's on screen; the scroll trigger will retry naturally.
      if (_disposed) return;
      state = AsyncData(cur.copyWith(isLoadingMore: false));
    }
  }

  /// Replaces all filters and reloads from page 1 (summary included).
  Future<void> applyFilters({
    String? fromDate,
    String? toDate,
    int? vehicleId,
    String? tripType,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _fetchFirstPage(
        fromDate: fromDate,
        toDate: toDate,
        vehicleId: vehicleId,
        tripType: tripType,
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
        fromDate: cur?.fromDate,
        toDate: cur?.toDate,
        vehicleId: cur?.vehicleId,
        tripType: cur?.tripType,
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
        fromDate: cur?.fromDate,
        toDate: cur?.toDate,
        vehicleId: cur?.vehicleId,
        tripType: cur?.tripType,
      ),
    );
    if (_disposed) return;
    state = result;
  }

  Future<void> createTrip(CreateExternalTripDto dto) async {
    await ref.read(externalTripRepositoryProvider).createTrip(dto);
    await _reloadAfterMutation();
  }

  Future<void> updateTrip(UpdateExternalTripDto dto) async {
    await ref.read(externalTripRepositoryProvider).updateTrip(dto);
    await _reloadAfterMutation();
  }

  Future<void> deleteTrip(int id) async {
    await ref.read(externalTripRepositoryProvider).deleteTrip(id);
    await _reloadAfterMutation();
  }
}
