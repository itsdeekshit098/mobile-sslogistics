import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/client_models.dart';
import 'client_provider.dart';

/// Paginated statement state for one client. Kept separate from
/// [ClientDetailNotifier] because a statement can grow without bound and
/// must never be loaded in one request — see the client detail route's own
/// comment on this.
class ClientEntriesState {
  final List<LedgerEntry> entries;
  final int total;
  final int page;
  final int pageSize;
  final num closingBalance;

  const ClientEntriesState({
    required this.entries,
    required this.total,
    required this.closingBalance,
    this.page = 1,
    this.pageSize = 25,
  });

  int get totalPages => total == 0 ? 1 : (total / pageSize).ceil();

  ClientEntriesState copyWith({
    List<LedgerEntry>? entries,
    int? total,
    int? page,
    int? pageSize,
    num? closingBalance,
  }) {
    return ClientEntriesState(
      entries: entries ?? this.entries,
      total: total ?? this.total,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      closingBalance: closingBalance ?? this.closingBalance,
    );
  }
}

class ClientEntriesNotifier
    extends AutoDisposeFamilyAsyncNotifier<ClientEntriesState, int> {
  bool _disposed = false;

  int get _clientId => arg;

  @override
  Future<ClientEntriesState> build(int arg) {
    ref.onDispose(() => _disposed = true);
    return _fetch(page: 1, pageSize: 25);
  }

  Future<ClientEntriesState> _fetch({required int page, required int pageSize}) async {
    final result = await ref.read(clientRepositoryProvider).fetchEntries(
          clientId: _clientId,
          page: page,
          pageSize: pageSize,
        );
    return ClientEntriesState(
      entries: result.data,
      total: result.total,
      closingBalance: result.closingBalance,
      page: page,
      pageSize: pageSize,
    );
  }

  Future<void> _apply({int? page, int? pageSize}) async {
    final cur = state.valueOrNull;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _fetch(page: page ?? cur?.page ?? 1, pageSize: pageSize ?? cur?.pageSize ?? 25),
    );
    if (_disposed) return;
    state = result;
  }

  Future<void> changePage(int page) => _apply(page: page);
  Future<void> changePageSize(int pageSize) => _apply(pageSize: pageSize, page: 1);

  Future<void> refresh() => _apply();

  Future<void> addEntry({
    required String entryType,
    required num amount,
    required String entryDate,
    String? invoiceNo,
    String? periodMonth,
    String? paymentMethod,
    String? reference,
    String? description,
  }) async {
    await ref.read(clientRepositoryProvider).addEntry(
          clientId: _clientId,
          entryType: entryType,
          amount: amount,
          entryDate: entryDate,
          invoiceNo: invoiceNo,
          periodMonth: periodMonth,
          paymentMethod: paymentMethod,
          reference: reference,
          description: description,
        );
    if (_disposed) return;
    // A new entry belongs on page 1 (newest first) regardless of where the
    // user was paging.
    await _apply(page: 1);
  }

  Future<void> reverseEntry(int entryId, {String? reason}) async {
    await ref.read(clientRepositoryProvider).reverseEntry(
          clientId: _clientId,
          entryId: entryId,
          reason: reason,
        );
    if (_disposed) return;
    await refresh();
  }
}

final clientEntriesProvider =
    AsyncNotifierProvider.autoDispose.family<ClientEntriesNotifier, ClientEntriesState, int>(
  ClientEntriesNotifier.new,
);
