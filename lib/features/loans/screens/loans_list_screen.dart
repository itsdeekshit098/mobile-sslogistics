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
import '../../../shared/widgets/skeleton_loader.dart';
import '../../../shared/widgets/summary_strip.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/loan_models.dart';
import '../providers/loan_provider.dart';
import '../widgets/loan_card.dart';
import '../widgets/loan_filter_sheet.dart';
import '../widgets/loan_form_sheet.dart';

class LoansListScreen extends ConsumerWidget {
  const LoansListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(loanListProvider);
    final user = ref.watch(authProvider).valueOrNull;
    final canManage = user?.isAdmin == true;
    final state = async.valueOrNull;
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
          tooltip: 'Back',
        ),
        title: Text(
          'Loans',
          style: TextStyle(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(AppIcons.calendar,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
            onPressed: () => context.push('/loans/due-soon'),
            tooltip: 'Due Soon',
          ),
          NotificationBellButton(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
          Builder(
            builder: (ctx) => IconButton(
              icon: Icon(AppIcons.menu,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
              tooltip: 'Open menu',
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(currentPath: '/loans'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: DebouncedSearchField(
                    hintText: 'Search account no., collateral...',
                    onDebouncedChanged: (q) => ref.read(loanListProvider.notifier).search(q),
                  ),
                ),
                const SizedBox(width: 10),
                _FilterButton(
                  activeCount: (state?.filters.isActive ?? false) ? 1 : 0,
                  onTap: () => _showFilterSheet(context, ref, state?.filters ?? LoanFilters.none),
                ),
              ],
            ),
          ),
          if (state?.extras != null) SummaryStrip(stats: _summaryStats(state!.extras!)),
          Expanded(
            child: async.when(
              loading: () =>
                  const SkeletonListCards(shape: SkeletonCardShape.plain, infoLines: 3),
              error: (e, _) => ErrorState(
                message: e.toString().replaceFirst('Exception: ', ''),
                onRetry: () => ref.invalidate(loanListProvider),
              ),
              data: (state) {
                if (state.items.isEmpty) {
                  return EmptyState(
                    title: 'No loans found',
                    subtitle: state.hasFilters
                        ? 'No loans match your filters.'
                        : 'Add an institutional loan to start tracking its EMI schedule.',
                    actionLabel: canManage ? 'Add Loan' : null,
                    onAction: canManage ? () => _showForm(context, ref, null) : null,
                    icon: AppIcons.landmark,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(loanListProvider.notifier).refresh(),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 4, bottom: 8),
                          itemCount: state.items.length,
                          itemBuilder: (context, i) {
                            final loan = state.items[i];
                            return LoanCard(
                              key: ValueKey(loan.id),
                              loan: loan,
                              onTap: () => context.push('/loans/detail?id=${loan.id}'),
                            );
                          },
                        ),
                      ),
                      ListPaginationBar(
                        page: state.page,
                        totalPages: state.totalPages,
                        total: state.total,
                        pageSize: state.pageSize,
                        itemLabel: 'loans',
                        endPadding: 86,
                        onPageChange: ref.read(loanListProvider.notifier).changePage,
                        onPageSizeChange: ref.read(loanListProvider.notifier).changePageSize,
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
              onPressed: () => _showForm(context, ref, null),
              backgroundColor: AppColors.tileLoansIcon,
              foregroundColor: Colors.white,
              child: const Icon(AppIcons.plus),
            )
          : null,
    );
  }

  List<SummaryStat> _summaryStats(LoanSummary summary) => [
        SummaryStat(label: 'Outstanding', value: formatRupees(summary.totalOutstanding)),
        SummaryStat(label: 'Monthly EMI', value: formatRupees(summary.totalMonthlyEmi)),
        SummaryStat(
          label: 'Overdue',
          value: '${summary.overdueCount}',
          color: summary.overdueCount > 0 ? AppColors.error : AppColors.success,
        ),
        SummaryStat(label: 'Active', value: '${summary.activeLoans}'),
      ];

  Future<void> _showFilterSheet(BuildContext context, WidgetRef ref, LoanFilters current) async {
    final result = await showModalBottomSheet<LoanFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LoanFilterSheet(initial: current),
    );
    if (result != null) {
      ref.read(loanListProvider.notifier).applyFilters(result);
    }
  }

  void _showForm(BuildContext context, WidgetRef ref, Loan? loan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: LoanFormSheet(
          loan: loan,
          onSubmit: (dto) => loan == null
              ? ref.read(loanListProvider.notifier).createLoan(dto)
              : ref.read(loanListProvider.notifier).updateLoan(loan.id, dto),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final int activeCount;
  final VoidCallback onTap;

  const _FilterButton({required this.activeCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 46,
        width: 46,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCardBg : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: activeCount > 0
                ? AppColors.primary
                : (isDark ? AppColors.darkBorder : AppColors.border),
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Icon(
                Icons.filter_list_rounded,
                color: activeCount > 0
                    ? AppColors.primary
                    : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
              ),
            ),
            if (activeCount > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    '$activeCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
