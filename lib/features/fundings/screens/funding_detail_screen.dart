import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../shared/utils/money_format.dart';
import '../../../shared/widgets/delete_confirmation_dialog.dart';
import '../../../shared/widgets/detail_section_card.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/utils/guarded_action.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/funding_models.dart';
import '../providers/funding_detail_provider.dart';
import '../providers/funding_provider.dart';
import '../widgets/funding_entry_sheet.dart';
import '../widgets/funding_rate_sheet.dart';

class FundingDetailScreen extends ConsumerWidget {
  final int fundingId;

  const FundingDetailScreen({super.key, required this.fundingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(fundingDetailProvider(fundingId));
    final user = ref.watch(authProvider).valueOrNull;
    final canManage = user?.isAdmin == true;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkPageBg : AppColors.pageBg,
        appBar: AppBar(
          backgroundColor: isDark ? AppColors.darkCardBg : Colors.white,
          elevation: 0,
          surfaceTintColor: isDark ? AppColors.darkCardBg : Colors.white,
          leading: IconButton(
            icon: Icon(AppIcons.arrowLeft,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
            onPressed: () => context.canPop() ? context.pop() : context.go('/fundings'),
          ),
          title: Text(
            async.valueOrNull?.funding.counterpartyName ?? 'Funding',
            style: TextStyle(
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            if (canManage && async.hasValue)
              PopupMenuButton<String>(
                icon: Icon(AppIcons.moreVert,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                onSelected: (action) => _handleMenu(context, ref, action, async.requireValue),
                itemBuilder: (_) {
                  final isLent = async.requireValue.funding.direction == 'LENT';
                  return [
                    PopupMenuItem(
                      value: 'pay_interest',
                      child: Text(isLent ? 'Receive Interest' : 'Pay Interest'),
                    ),
                    PopupMenuItem(
                      value: 'repay_principal',
                      child: Text(isLent ? 'Recover Principal' : 'Repay Principal'),
                    ),
                    PopupMenuItem(
                      value: 'borrow_more',
                      child: Text(isLent ? 'Lend More' : 'Borrow More'),
                    ),
                    const PopupMenuItem(value: 'change_rate', child: Text('Change Rate')),
                    const PopupMenuDivider(),
                    if (async.requireValue.funding.status == 'OPEN')
                      const PopupMenuItem(value: 'settle', child: Text('Settle')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ];
                },
              ),
          ],
          bottom: async.hasValue
              ? const TabBar(tabs: [Tab(text: 'Interest'), Tab(text: 'Entries'), Tab(text: 'Rates')])
              : null,
        ),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
            message: e.toString().replaceFirst('Exception: ', ''),
            onRetry: () => ref.invalidate(fundingDetailProvider(fundingId)),
          ),
          data: (detail) => Column(
            children: [
              _SummaryCard(detail: detail),
              Expanded(
                child: TabBarView(
                  children: [
                    _InterestTab(computed: detail.computed),
                    _EntriesTab(fundingId: fundingId, detail: detail, canManage: canManage),
                    _RatesTab(rates: detail.rates, interestMode: detail.funding.interestMode),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleMenu(BuildContext context, WidgetRef ref, String action, FundingDetail detail) {
    switch (action) {
      case 'pay_interest':
        _showEntrySheet(
          context, ref, 'INTEREST_PAID', detail.computed.interestDue, detail.funding.direction);
      case 'repay_principal':
        _showEntrySheet(context, ref, 'PRINCIPAL_REPAID', detail.computed.principalOutstanding,
            detail.funding.direction);
      case 'borrow_more':
        _showEntrySheet(context, ref, 'PRINCIPAL_TAKEN', null, detail.funding.direction);
      case 'change_rate':
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => FundingRateSheet(
            interestMode: detail.funding.interestMode,
            onSubmit: ({required effectiveFrom, roi, roiBasis, fixedInterestAmount, note}) =>
                ref.read(fundingDetailProvider(fundingId).notifier).changeRate(
                      effectiveFrom: effectiveFrom,
                      roi: roi,
                      roiBasis: roiBasis,
                      fixedInterestAmount: fixedInterestAmount,
                      note: note,
                    ),
          ),
        );
      case 'settle':
        ref.read(fundingDetailProvider(fundingId).notifier).settle();
      case 'delete':
        showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => DeleteConfirmationDialog(
            title: 'Delete Funding',
            targetName: detail.funding.counterpartyName != '—'
                ? detail.funding.counterpartyName
                : 'this funding',
            warningText: 'This action cannot be undone.',
            warningSubtext: 'This will permanently remove the funding, its rate history and entries.',
            onConfirm: () async {
              await ref.read(fundingRepositoryProvider).deleteFunding(fundingId);
              ref.invalidate(fundingListProvider);
              if (context.mounted) context.pop();
            },
          ),
        );
    }
  }

  void _showEntrySheet(
    BuildContext context,
    WidgetRef ref,
    String entryType,
    num? prefill,
    String direction,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FundingEntrySheet(
        entryType: entryType,
        direction: direction,
        prefillAmount: prefill,
        onSubmit: ({
          required entryType,
          required amount,
          required entryDate,
          paymentMethod,
          reference,
          description,
        }) =>
            ref.read(fundingDetailProvider(fundingId).notifier).recordEntry(
                  entryType: entryType,
                  amount: amount,
                  entryDate: entryDate,
                  paymentMethod: paymentMethod,
                  reference: reference,
                  description: description,
                ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final FundingDetail detail;

  const _SummaryCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final funding = detail.funding;
    final computed = detail.computed;
    final rate = funding.currentRate ?? (detail.rates.isNotEmpty ? detail.rates.last : null);
    final rateLabel = funding.interestMode == 'FIXED'
        ? '${formatRupees(rate?.fixedInterestAmount)}/month'
        : rate?.roi != null
            ? '${rate!.roi}% ${rate.roiBasis == 'ANNUAL' ? 'p.a.' : 'per month'}'
            : '—';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: DetailSectionCard(
        title: 'Funding Summary',
        rows: [
          if (funding.borrower != null) DetailRowData('In Name Of', funding.borrower!.name),
          DetailRowData('Principal Outstanding', formatRupees(computed.principalOutstanding)),
          DetailRowData('Rate', rateLabel),
          DetailRowData(
            funding.direction == 'LENT' ? 'Interest Receivable' : 'Interest Due',
            formatRupeesPrecise(computed.interestDue),
            valueColor: computed.interestDue > 0 ? AppColors.warning : AppColors.success,
          ),
          DetailRowData('Since', formatDisplayDate(funding.startDate)),
        ],
      ),
    );
  }
}

class _InterestTab extends StatelessWidget {
  final FundingComputation computed;

  const _InterestTab({required this.computed});

  @override
  Widget build(BuildContext context) {
    if (computed.monthlyBreakdown.isEmpty) {
      return const Center(child: Text('No interest accrued yet'));
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: computed.monthlyBreakdown.length,
      itemBuilder: (context, i) {
        // Newest month first, matching the web's month-by-month table.
        final row = computed.monthlyBreakdown[computed.monthlyBreakdown.length - 1 - i];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCardBg : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formatMonthYear(row.month),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (row.monthlyRate != null)
                    Text('${row.monthlyRate}%/mo',
                        style: TextStyle(fontSize: 11.5,
                            color: isDark ? AppColors.darkTextMuted : AppColors.textMuted)),
                ],
              ),
              const SizedBox(height: 6),
              _kv(context, 'Avg. Principal', formatRupees(row.averagePrincipal)),
              _kv(context, 'Accrued (${row.days}d)', formatRupeesPrecise(row.interestAccrued)),
              _kv(context, 'Paid', formatRupeesPrecise(row.interestPaid)),
              _kv(
                context,
                'Balance',
                formatRupeesPrecise(row.interestBalance),
                valueColor: row.interestBalance > 0 ? AppColors.warning : AppColors.success,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _kv(BuildContext context, String label, String value, {Color? valueColor}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(fontSize: 12.5,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: valueColor ?? (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntriesTab extends ConsumerWidget {
  final int fundingId;
  final FundingDetail detail;
  final bool canManage;

  const _EntriesTab({required this.fundingId, required this.detail, required this.canManage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (detail.entries.isEmpty) {
      return const Center(child: Text('No entries recorded yet'));
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: detail.entries.length,
      itemBuilder: (context, i) {
        final entry = detail.entries[i];
        final isCredit = entry.entryType == 'PRINCIPAL_REPAID' || entry.entryType == 'INTEREST_PAID';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fundingEntryTypeLabel(entry.entryType, direction: detail.funding.direction),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        decoration: entry.isReversed ? TextDecoration.lineThrough : null,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                    Text(formatDisplayDate(entry.entryDate),
                        style: TextStyle(fontSize: 11.5,
                            color: isDark ? AppColors.darkTextMuted : AppColors.textMuted)),
                  ],
                ),
              ),
              Text(
                formatRupees(entry.amount),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  decoration: entry.isReversed ? TextDecoration.lineThrough : null,
                  color: isCredit ? AppColors.success : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                ),
              ),
              if (canManage && entry.canReverse)
                IconButton(
                  icon: const Icon(AppIcons.undo, size: 18),
                  tooltip: 'Reverse',
                  onPressed: () => _confirmReverse(context, ref, entry),
                ),
            ],
          ),
        );
      },
    );
  }

  void _confirmReverse(BuildContext context, WidgetRef ref, FundingEntry entry) {
    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reverse Entry'),
        content: Text(
          'This cancels ${formatRupees(entry.amount)} dated ${formatDisplayDate(entry.entryDate)}.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await runGuarded(
                context,
                () => ref.read(fundingDetailProvider(fundingId).notifier).reverseEntry(entry.id),
              );
            },
            child: const Text('Reverse'),
          ),
        ],
      ),
    );
  }
}

class _RatesTab extends StatelessWidget {
  final List<FundingRate> rates;
  final String interestMode;

  const _RatesTab({required this.rates, required this.interestMode});

  @override
  Widget build(BuildContext context) {
    if (rates.isEmpty) {
      return const Center(child: Text('No rate history'));
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sorted = [...rates]..sort((a, b) => b.effectiveFrom.compareTo(a.effectiveFrom));

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: sorted.length,
      itemBuilder: (context, i) {
        final rate = sorted[i];
        final label = interestMode == 'FIXED'
            ? '${formatRupees(rate.fixedInterestAmount)}/month'
            : '${rate.roi}% ${rate.roiBasis == 'ANNUAL' ? 'p.a.' : 'per month'}';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
                    if (rate.note != null)
                      Text(rate.note!,
                          style: TextStyle(fontSize: 11.5,
                              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted)),
                  ],
                ),
              ),
              Text('from ${formatDisplayDate(rate.effectiveFrom)}',
                  style: TextStyle(fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
            ],
          ),
        );
      },
    );
  }
}
