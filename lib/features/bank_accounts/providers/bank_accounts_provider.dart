import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/bank_account_models.dart';
import '../../../shared/data/bank_account_repository.dart';
import '../../../shared/state/list_filters.dart';
import '../../../shared/state/paged_result.dart';
import '../../../shared/state/paginated_list_notifier.dart';
import '../../../shared/state/paginated_list_state.dart';

final bankAccountRepositoryProvider =
    Provider<BankAccountRepository>((ref) => BankAccountRepository());

typedef BankAccountsState = PaginatedListState<BankAccount, NoFilters, void>;

final bankAccountsListProvider = AsyncNotifierProvider.autoDispose<BankAccountsNotifier,
    BankAccountsState>(BankAccountsNotifier.new);

class BankAccountsNotifier extends PaginatedListNotifier<BankAccount, NoFilters, void> {
  @override
  NoFilters get initialFilters => const NoFilters();

  @override
  int get defaultPageSize => 20;

  @override
  Future<PagedResult<BankAccount, void>> fetchPage({
    required int page,
    required int pageSize,
    required String search,
    required NoFilters filters,
  }) async {
    final data = await ref.read(bankAccountRepositoryProvider).fetchPage(
          page: page,
          pageSize: pageSize,
          search: search,
        );
    return PagedResult(items: data.accounts, total: data.total, extras: null);
  }

  Future<BankAccount> createAccount({
    required int holderEntityId,
    required String bankName,
    required String accountNumber,
    String accountType = 'SAVINGS',
    String? ifsc,
    String? branch,
    String? nickname,
    String? notes,
  }) async {
    final created = await ref.read(bankAccountRepositoryProvider).create(
          holderEntityId: holderEntityId,
          bankName: bankName,
          accountNumber: accountNumber,
          accountType: accountType,
          ifsc: ifsc,
          branch: branch,
          nickname: nickname,
          notes: notes,
        );
    await refresh();
    return created;
  }

  Future<void> deleteAccount(int id) async {
    await ref.read(bankAccountRepositoryProvider).delete(id);
    await refresh();
  }
}
