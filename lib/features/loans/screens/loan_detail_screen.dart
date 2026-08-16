import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../shared/data/bank_account_models.dart' show mandateTypeLabel;
import '../../../shared/utils/money_format.dart';
import '../../../shared/widgets/delete_confirmation_dialog.dart';
import '../../../shared/widgets/detail_section_card.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/utils/guarded_action.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/loan_models.dart';
import '../providers/loan_detail_provider.dart';
import '../providers/loan_provider.dart';
import '../widgets/installment_status_chip.dart';
import '../widgets/installment_tile.dart';
import '../widgets/loan_form_sheet.dart';
import '../widgets/loan_payment_sheet.dart';

class LoanDetailScreen extends ConsumerWidget {
  final int loanId;

  const LoanDetailScreen({super.key, required this.loanId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(loanDetailProvider(loanId));
    final user = ref.watch(authProvider).valueOrNull;
    final canManage = user?.isAdmin == true;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkPageBg : AppColors.pageBg,
        appBar: AppBar(
          backgroundColor: isDark ? AppColors.darkCardBg : Colors.white,
          elevation: 0,
          surfaceTintColor: isDark ? AppColors.darkCardBg : Colors.white,
          leading: IconButton(
            icon: Icon(AppIcons.arrowLeft,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
            onPressed: () => context.canPop() ? context.pop() : context.go('/loans'),
          ),
          title: Text(
            async.valueOrNull?.loan.lender?.name ?? async.valueOrNull?.loan.loanType ?? 'Loan',
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
                onSelected: (action) => _handleMenuAction(context, ref, action, async.requireValue),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'prepayment', child: Text('Prepayment')),
                  const PopupMenuItem(value: 'foreclosure', child: Text('Foreclosure')),
                  const PopupMenuItem(value: 'charge', child: Text('Record Charge')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
          ],
          bottom: async.hasValue
              ? const TabBar(tabs: [Tab(text: 'Schedule'), Tab(text: 'Payments')])
              : null,
        ),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
            message: e.toString().replaceFirst('Exception: ', ''),
            onRetry: () => ref.invalidate(loanDetailProvider(loanId)),
          ),
          data: (detail) => Column(
            children: [
              _SummaryCard(detail: detail),
              Expanded(
                child: TabBarView(
                  children: [
                    _ScheduleTab(loanId: loanId, detail: detail, canManage: canManage),
                    _PaymentsTab(loanId: loanId, detail: detail, canManage: canManage),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action, LoanDetail detail) {
    switch (action) {
      case 'prepayment':
        _showPaymentSheet(context, ref, 'PREPAYMENT', null);
      case 'foreclosure':
        _showPaymentSheet(context, ref, 'FORECLOSURE', null);
      case 'charge':
        _showPaymentSheet(context, ref, 'CHARGE', null);
      case 'edit':
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (_) => FractionallySizedBox(
            heightFactor: 0.92,
            child: LoanFormSheet(
              loan: detail.loan,
              onSubmit: (dto) =>
                  ref.read(loanDetailProvider(loanId).notifier).updateLoan(dto.toJson()),
            ),
          ),
        );
      case 'delete':
        showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => DeleteConfirmationDialog(
            title: 'Delete Loan',
            targetName: detail.loan.borrower?.name ?? detail.loan.loanType,
            warningText: 'This action cannot be undone.',
            warningSubtext: 'This will permanently remove the loan, its schedule and payment log.',
            onConfirm: () async {
              await ref.read(loanRepositoryProvider).deleteLoan(loanId);
              ref.invalidate(loanListProvider);
              if (context.mounted) context.pop();
            },
          ),
        );
    }
  }

  void _showPaymentSheet(
    BuildContext context,
    WidgetRef ref,
    String paymentType,
    LoanInstallment? installment,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LoanPaymentSheet(
        paymentType: paymentType,
        installment: installment,
        onSubmit: ({
          required paymentType,
          required amount,
          required paidOn,
          installmentId,
          paymentMethod,
          reference,
          notes,
        }) =>
            ref.read(loanDetailProvider(loanId).notifier).recordPayment(
                  paymentType: paymentType,
                  amount: amount,
                  paidOn: paidOn,
                  installmentId: installmentId,
                  paymentMethod: paymentMethod,
                  reference: reference,
                  notes: notes,
                ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final LoanDetail detail;

  const _SummaryCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final loan = detail.loan;
    final balance = detail.balance;
    final overdue = balance.overdueCount > 0;
    final collateral = loan.vehicle?.vehicleNumber ?? loan.collateralDescription;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: DetailSectionCard(
        title: 'Loan Summary',
        trailing: LoanStatusChip(status: loan.status),
        rows: [
          DetailRowData('Borrower', loan.borrower?.name ?? '—'),
          if (loan.lender != null) DetailRowData('Lender', loan.lender!.name),
          if (loan.loanNumber != null) DetailRowData('Loan No.', loan.loanNumber!),
          if (collateral != null) DetailRowData('Collateral', collateral),
          if (loan.bankAccount != null)
            DetailRowData(
              'Auto-debit',
              loan.mandateType != null
                  ? '${loan.bankAccount!.displayLabel} (${mandateTypeLabel(loan.mandateType)})'
                  : loan.bankAccount!.displayLabel,
            ),
          DetailRowData('Principal', formatRupees(loan.principalAmount)),
          DetailRowData(
            'Outstanding',
            formatRupees(balance.outstanding),
            valueColor: overdue ? AppColors.error : null,
          ),
          DetailRowData(
            'Progress',
            '${balance.installmentsPaid}/${balance.installmentsPaid + balance.installmentsLeft} paid',
          ),
          DetailRowData(
            overdue ? 'Overdue' : 'Next EMI',
            balance.nextDueDate != null
                ? '${formatRupees(balance.nextDueAmount)} · ${formatDisplayDate(balance.nextDueDate)}'
                : 'Fully paid',
            valueColor: overdue ? AppColors.error : null,
          ),
        ],
      ),
    );
  }
}

class _ScheduleTab extends ConsumerWidget {
  final int loanId;
  final LoanDetail detail;
  final bool canManage;

  const _ScheduleTab({required this.loanId, required this.detail, required this.canManage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (detail.installments.isEmpty) {
      return const Center(child: Text('No installments scheduled'));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: detail.installments.length,
      itemBuilder: (context, i) {
        final installment = detail.installments[i];
        return InstallmentTile(
          installment: installment,
          canManage: canManage,
          onMarkPaid: () => _showPaymentSheet(context, ref, installment),
          onMoreActions: () => _showStatusMenu(context, ref, installment),
        );
      },
    );
  }

  void _showPaymentSheet(BuildContext context, WidgetRef ref, LoanInstallment installment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LoanPaymentSheet(
        paymentType: 'EMI',
        installment: installment,
        onSubmit: ({
          required paymentType,
          required amount,
          required paidOn,
          installmentId,
          paymentMethod,
          reference,
          notes,
        }) =>
            ref.read(loanDetailProvider(loanId).notifier).recordPayment(
                  paymentType: paymentType,
                  amount: amount,
                  paidOn: paidOn,
                  installmentId: installmentId,
                  paymentMethod: paymentMethod,
                  reference: reference,
                  notes: notes,
                ),
      ),
    );
  }

  Future<void> _showStatusMenu(
    BuildContext context,
    WidgetRef ref,
    LoanInstallment installment,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            if (installment.manualStatus == null && !installment.isSettled) ...[
              ListTile(
                leading: const Icon(Icons.report_gmailerrorred, color: AppColors.error),
                title: const Text('Mark Bounced'),
                onTap: () => Navigator.pop(context, 'BOUNCED'),
              ),
              ListTile(
                leading: const Icon(Icons.remove_circle_outline),
                title: const Text('Waive Installment'),
                onTap: () => Navigator.pop(context, 'WAIVED'),
              ),
            ] else
              ListTile(
                leading: const Icon(Icons.undo),
                title: const Text('Clear Status'),
                onTap: () => Navigator.pop(context, 'CLEAR'),
              ),
          ],
        ),
      ),
    );
    if (action == null) return;
    await ref.read(loanDetailProvider(loanId).notifier).setInstallmentManualStatus(
          installmentId: installment.id,
          manualStatus: action == 'CLEAR' ? null : action,
        );
  }
}

class _PaymentsTab extends ConsumerWidget {
  final int loanId;
  final LoanDetail detail;
  final bool canManage;

  const _PaymentsTab({required this.loanId, required this.detail, required this.canManage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (detail.payments.isEmpty) {
      return const Center(child: Text('No payments recorded yet'));
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: detail.payments.length,
      itemBuilder: (context, i) {
        final payment = detail.payments[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paymentTypeLabel(payment.paymentType),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        decoration: payment.isReversed ? TextDecoration.lineThrough : null,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      formatDisplayDate(payment.paidOn),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formatRupees(payment.amount),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  decoration: payment.isReversed ? TextDecoration.lineThrough : null,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              if (canManage && payment.canReverse)
                IconButton(
                  icon: const Icon(AppIcons.undo, size: 18),
                  tooltip: 'Reverse',
                  onPressed: () => _confirmReverse(context, ref, payment),
                ),
            ],
          ),
        );
      },
    );
  }

  void _confirmReverse(BuildContext context, WidgetRef ref, LoanPayment payment) {
    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reverse Payment'),
        content: Text(
          'This cancels ${formatRupees(payment.amount)} dated ${formatDisplayDate(payment.paidOn)}. Both the original and the correction stay in the log.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await runGuarded(
                context,
                () => ref.read(loanDetailProvider(loanId).notifier).reversePayment(payment.id),
              );
            },
            child: const Text('Reverse'),
          ),
        ],
      ),
    );
  }
}
