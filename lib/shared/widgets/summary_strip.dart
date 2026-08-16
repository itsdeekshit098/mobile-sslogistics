import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// One KPI in a [SummaryStrip].
class SummaryStat {
  final String label;
  final String value;
  final Color color;

  const SummaryStat({
    required this.label,
    required this.value,
    this.color = AppColors.primary,
  });
}

/// Row of compact KPI cards pinned above a list — "Outstanding / Monthly EMI /
/// Due / Overdue".
///
/// Promoted from the private `_SummaryStrip` in `trip_bookings_list_screen.dart`
/// so the three finance list screens don't each grow their own copy. Values are
/// `FittedBox`-scaled because a rupee figure is far wider than a count, and
/// four of them have to share the width of a phone.
class SummaryStrip extends StatelessWidget {
  final List<SummaryStat> stats;

  const SummaryStrip({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Row(
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _SummaryCard(stat: stats[i]),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final SummaryStat stat;

  const _SummaryCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCardBg : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                stat.value,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: stat.color,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              stat.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
