import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/utils/money_format.dart';
import '../data/loan_models.dart';
import 'installment_status_chip.dart';

/// One row of the EMI schedule. Tapping "Mark Paid" on an unsettled row opens
/// the payment sheet with the remaining amount prefilled — the schedule
/// itself is read-only otherwise, since its rows are generated server-side.
class InstallmentTile extends StatelessWidget {
  final LoanInstallment installment;
  final bool canManage;
  final VoidCallback? onMarkPaid;
  final VoidCallback? onMoreActions;

  const InstallmentTile({
    super.key,
    required this.installment,
    required this.canManage,
    this.onMarkPaid,
    this.onMoreActions,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overdue = installment.status == 'OVERDUE';
    final settled = installment.isSettled;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#${installment.installmentNo}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatDisplayDate(installment.dueDate),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                Text(
                  relativeDueLabel(installment.dueDate),
                  style: TextStyle(
                    fontSize: 11,
                    color: overdue ? AppColors.error : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatRupees(installment.amountDue),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  decoration: installment.status == 'WAIVED' ? TextDecoration.lineThrough : null,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              InstallmentStatusChip(status: installment.status),
            ],
          ),
          if (canManage) ...[
            const SizedBox(width: 6),
            if (!settled && onMarkPaid != null)
              IconButton(
                onPressed: onMarkPaid,
                icon: const Icon(Icons.check_circle_outline, color: AppColors.success),
                tooltip: 'Mark Paid',
                visualDensity: VisualDensity.compact,
              )
            // A row settled by a real payment (manualStatus == null) has
            // nothing to offer here — Bounced/Waive only make sense on an
            // unsettled row, and Clear Status only applies when a manual
            // override is what made it settled (WAIVED). Matches the web
            // app's `!settled` guard on the same action.
            else if (onMoreActions != null && (!settled || installment.manualStatus != null))
              IconButton(
                onPressed: onMoreActions,
                icon: const Icon(Icons.more_vert, size: 18),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ],
      ),
    );
  }
}
