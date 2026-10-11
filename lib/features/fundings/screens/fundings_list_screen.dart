import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../shared/utils/money_format.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/debounced_search_field.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/list_pagination_bar.dart';
import '../../../shared/widgets/notification_bell_button.dart';
import '../../../shared/widgets/option_picker_sheet.dart';
import '../../../shared/widgets/selectable_chip.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../../../shared/widgets/summary_strip.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/funding_models.dart';
import '../providers/funding_provider.dart';
import '../widgets/funding_card.dart';
import '../widgets/funding_form_sheet.dart';

/// Money we borrowed and money we lent out are two different lists — never
/// totaled together — so a segmented control switches between two separate
/// providers rather than filtering one shared list.
class FundingsListScreen extends ConsumerStatefulWidget {
  const FundingsListScreen({super.key});

  @override
  ConsumerState<FundingsListScreen> createState() => _FundingsListScreenState();
}

class _FundingsListScreenState extends ConsumerState<FundingsListScreen> {
  String _direction = 'BORROWED';

  bool get _isLent => _direction == 'LENT';

  @override
  Widget build(BuildContext context) {
    final provider = _isLent ? lentFundingListProvider : fundingListProvider;
    final async = ref.watch(provider);
    final state = async.valueOrNull;
    final user = ref.watch(authProvider).valueOrNull;
    final canManage = user?.isAdmin == true;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkPageBg : AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkCardBg : Colors.white,
        elevation: 0,
        surfaceTintColor: isDark ? AppColors.darkCardBg : Colors.white,
        leading: IconButton(
          icon: Icon(AppIcons.arrowLeft,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
          onPressed: () => context.go('/dashboard'),
        ),
        title: Text(
          'Private Fundings',
          style: TextStyle(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          NotificationBellButton(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
          Builder(
            builder: (ctx) => IconButton(
              icon: Icon(AppIcons.menu,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(currentPath: '/fundings'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                SelectableChip(
                  label: 'Borrowed',
                  selected: !_isLent,
                  onTap: () => setState(() => _direction = 'BORROWED'),
                ),
                const SizedBox(width: 8),
                SelectableChip(
                  label: 'Lent Out',
                  selected: _isLent,
                  onTap: () => setState(() => _direction = 'LENT'),
                ),
                const Spacer(),
                if (state != null) _sortButton(context, provider, state.filters, isDark),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: DebouncedSearchField(
              hintText: _isLent ? 'Search borrower...' : 'Search funder or entity...',
              onDebouncedChanged: (q) => ref.read(provider.notifier).search(q),
            ),
          ),
          if (state?.extras != null) SummaryStrip(stats: _summaryStats(state!.extras!)),
          Expanded(
            child: async.when(
              loading: () =>
                  const SkeletonListCards(shape: SkeletonCardShape.plain, infoLines: 2),
              error: (e, _) => ErrorState(
                message: e.toString().replaceFirst('Exception: ', ''),
                onRetry: () => ref.invalidate(provider),
              ),
              data: (state) {
                if (state.items.isEmpty) {
                  return EmptyState(
                    title: _isLent ? 'Nothing lent out' : 'No private fundings found',
                    subtitle: _isLent
                        ? 'Record money lent to an individual at an agreed rate.'
                        : 'Record money borrowed from an individual at an agreed rate.',
                    actionLabel: canManage ? (_isLent ? 'Lend Money' : 'Add Funding') : null,
                    onAction: canManage ? () => _showForm(context, ref) : null,
                    icon: AppIcons.handCoins,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(provider.notifier).refresh(),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 4, bottom: 8),
                          itemCount: state.items.length,
                          itemBuilder: (context, i) {
                            final funding = state.items[i];
                            return FundingCard(
                              key: ValueKey(funding.id),
                              funding: funding,
                              onTap: () => context.push('/fundings/detail?id=${funding.id}'),
                            );
                          },
                        ),
                      ),
                      ListPaginationBar(
                        page: state.page,
                        totalPages: state.totalPages,
                        total: state.total,
                        pageSize: state.pageSize,
                        itemLabel: 'fundings',
                        endPadding: 86,
                        onPageChange: ref.read(provider.notifier).changePage,
                        onPageSizeChange: ref.read(provider.notifier).changePageSize,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: canManage && async.hasValue
          ? FloatingActionButton(
              onPressed: () => _showForm(context, ref),
              backgroundColor: AppColors.tileFundingsIcon,
              foregroundColor: Colors.white,
              child: const Icon(AppIcons.plus),
            )
          : null,
    );
  }

  /// Borrowed and Lent Out each keep their own sort, since each tab has its
  /// own provider. Changing it reloads from page 1 via applyFilters.
  Widget _sortButton(
    BuildContext context,
    AutoDisposeAsyncNotifierProvider<FundingNotifier, FundingState> provider,
    FundingFilters filters,
    bool isDark,
  ) {
    final sorted = filters.sort != 'newest';
    final color = sorted
        ? AppColors.primary
        : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary);
    return TextButton.icon(
      onPressed: () async {
        final choice = await showOptionPicker<String>(
          context,
          title: 'Sort by',
          options: kFundingSorts,
          selected: filters.sort,
          labelBuilder: fundingSortLabel,
        );
        if (choice == null || choice == filters.sort) return;
        await ref.read(provider.notifier).applyFilters(filters.copyWith(sort: choice));
      },
      icon: Icon(AppIcons.arrowUpDown, size: 18, color: color),
      label: Text(
        'Sort',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  List<SummaryStat> _summaryStats(FundingSummary summary) => [
        SummaryStat(
          label: 'Principal Out.',
          value: formatRupees(summary.principalOutstanding),
        ),
        SummaryStat(
          label: _isLent ? 'Interest Recv.' : 'Interest Due',
          value: formatRupees(summary.interestDue),
          color: summary.interestDue > 0 ? AppColors.warning : AppColors.success,
        ),
        SummaryStat(label: 'Open', value: '${summary.openCount}'),
      ];

  void _showForm(BuildContext context, WidgetRef ref) {
    final direction = _direction;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: FundingFormSheet(
          direction: direction,
          onSubmit: (dto) => direction == 'LENT'
              ? ref.read(lentFundingListProvider.notifier).createFunding(dto)
              : ref.read(fundingListProvider.notifier).createFunding(dto),
        ),
      ),
    );
  }
}
