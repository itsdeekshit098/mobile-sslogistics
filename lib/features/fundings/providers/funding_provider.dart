import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/state/paged_result.dart';
import '../../../shared/state/paginated_list_notifier.dart';
import '../../../shared/state/paginated_list_state.dart';
import '../data/funding_models.dart';
import '../data/funding_repository.dart';

final fundingRepositoryProvider = Provider<FundingRepository>((ref) => FundingRepository());

typedef FundingState = PaginatedListState<Funding, FundingFilters, FundingSummary?>;

class FundingNotifier extends PaginatedListNotifier<Funding, FundingFilters, FundingSummary?> {
  @override
  FundingFilters get initialFilters => FundingFilters.none;

  @override
  int get defaultPageSize => 20;

  @override
  Future<PagedResult<Funding, FundingSummary?>> fetchPage({
    required int page,
    required int pageSize,
    required String search,
    required FundingFilters filters,
  }) {
    return ref.read(fundingRepositoryProvider).fetchFundings(
          page: page,
          pageSize: pageSize,
          search: search,
          filters: filters,
          includeSummary: page == 1,
        );
  }

  Future<int> createFunding(FundingDto dto) async {
    final id = await ref.read(fundingRepositoryProvider).createFunding(dto);
    await refresh();
    return id;
  }

  Future<void> deleteFunding(int id) async {
    await ref.read(fundingRepositoryProvider).deleteFunding(id);
    await refresh();
  }
}

final fundingListProvider =
    AsyncNotifierProvider.autoDispose<FundingNotifier, FundingState>(FundingNotifier.new);

/// Money lent out — a separate provider rather than a filter toggle on
/// [fundingListProvider], so money we owe and money owed to us never end up
/// merged in one cached list. Only `initialFilters` differs from
/// [FundingNotifier], so it's reused rather than re-copied.
class LentFundingNotifier extends FundingNotifier {
  @override
  FundingFilters get initialFilters => FundingFilters.lent;
}

final lentFundingListProvider =
    AsyncNotifierProvider.autoDispose<LentFundingNotifier, FundingState>(
  LentFundingNotifier.new,
);
