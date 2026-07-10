import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../data/repair_models.dart';

final _moneyFmt = NumberFormat('#,##0', 'en_IN');

class RepairSummaryChips extends StatelessWidget {
  final RepairSummary summary;

  const RepairSummaryChips({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          _StatChip(
            label: 'Total Cost',
            value: '₹${_moneyFmt.format(summary.totalCost)}',
            color: AppColors.primary,
          ),
          _StatChip(
            label: 'Electrical',
            value: '₹${_moneyFmt.format(summary.electricalCost)}',
            color: AppColors.tileTechIcon,
          ),
          _StatChip(
            label: 'Mechanical',
            value: '₹${_moneyFmt.format(summary.mechanicalCost)}',
            color: AppColors.tileRepairIcon,
          ),
          _StatChip(
            label: 'Records',
            value: '${summary.totalCount}',
            color: AppColors.textSecondary,
          ),
          _StatChip(
            label: 'Open',
            value: '${summary.openCount}',
            color: AppColors.warning,
          ),
          _StatChip(
            label: 'Closed',
            value: '${summary.closedCount}',
            color: AppColors.success,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
