import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/state/paged_result.dart';
import '../../../shared/state/paginated_list_notifier.dart';
import '../../../shared/state/paginated_list_state.dart';
import '../data/loan_models.dart';
import '../data/loan_repository.dart';

final loanRepositoryProvider = Provider<LoanRepository>((ref) => LoanRepository());

typedef LoanState = PaginatedListState<Loan, LoanFilters, LoanSummary?>;

class LoanNotifier extends PaginatedListNotifier<Loan, LoanFilters, LoanSummary?> {
  @override
  LoanFilters get initialFilters => LoanFilters.none;

  @override
  Future<PagedResult<Loan, LoanSummary?>> fetchPage({
    required int page,
    required int pageSize,
    required String search,
    required LoanFilters filters,
  }) {
    return ref.read(loanRepositoryProvider).fetchLoans(
          page: page,
          pageSize: pageSize,
          search: search,
          filters: filters,
          includeSummary: page == 1,
        );
  }

  Future<int> createLoan(LoanDto dto) async {
    final id = await ref.read(loanRepositoryProvider).createLoan(dto);
    await refresh();
    return id;
  }

  Future<void> updateLoan(int id, LoanDto dto) async {
    await ref.read(loanRepositoryProvider).updateLoan(id, dto.toJson());
    await refresh();
  }

  Future<void> deleteLoan(int id) async {
    await ref.read(loanRepositoryProvider).deleteLoan(id);
    await refresh();
  }
}

final loanListProvider =
    AsyncNotifierProvider.autoDispose<LoanNotifier, LoanState>(LoanNotifier.new);
