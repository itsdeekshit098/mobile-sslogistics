import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../shared/utils/money_format.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../data/loan_models.dart';
import '../providers/loan_calendar_provider.dart';

/// The mobile answer to the web's EMI Calendar — "what's due, across every
/// loan, on which date". Defaults to the current month; overdue installments
/// are pinned above the calendar days regardless of which month is showing.
class DueSoonScreen extends ConsumerStatefulWidget {
  const DueSoonScreen({super.key});

  @override
  ConsumerState<DueSoonScreen> createState() => _DueSoonScreenState();
}

class _DueSoonScreenState extends ConsumerState<DueSoonScreen> {
  late String _monthStart = monthStart(DateTime.now());

  void _changeMonth(int delta) {
    setState(() => _monthStart = shiftMonth(_monthStart, delta));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(loanCalendarProvider(_monthStart));
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
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Due Soon',
          style: TextStyle(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(AppIcons.chevronLeft),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  formatMonthYear(_monthStart),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(AppIcons.chevronRight),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorState(
                message: e.toString().replaceFirst('Exception: ', ''),
                onRetry: () => ref.invalidate(loanCalendarProvider(_monthStart)),
              ),
              data: (calendar) {
                if (calendar.days.isEmpty && calendar.overdue.isEmpty) {
                  return EmptyState(
                    title: 'Nothing due this month',
                    subtitle: 'No EMIs are scheduled in ${formatMonthYear(_monthStart)}.',
                    icon: AppIcons.calendar,
                  );
                }
                return ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    if (calendar.overdue.isNotEmpty)
                      _DaySection(
                        label: 'Overdue',
                        installments: calendar.overdue,
                        isOverdue: true,
                      ),
                    for (final day in calendar.days)
                      if (!day.isOverdue)
                        _DaySection(
                          label:
                              '${formatDisplayDate(day.date)} · ${formatRupees(day.total)}',
                          installments: day.installments,
                          isOverdue: false,
                        ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  final String label;
  final List<CalendarInstallment> installments;
  final bool isOverdue;

  const _DaySection({
    required this.label,
    required this.installments,
    required this.isOverdue,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: isOverdue
                  ? AppColors.error
                  : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
            ),
          ),
        ),
        for (final installment in installments)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCardBg : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isOverdue
                    ? AppColors.error.withValues(alpha: 0.3)
                    : (isDark ? AppColors.darkBorder : AppColors.border),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        installment.loan?.lender?.name ?? installment.loan?.loanType ?? 'Loan',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                      if (installment.loan?.borrower != null)
                        Text(
                          installment.loan!.borrower!.name,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  formatRupees(installment.amountRemaining),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isOverdue ? AppColors.error : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 20),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => context.push('/loans/detail?id=${installment.loanId}'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
