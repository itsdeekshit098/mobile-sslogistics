import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_sslogistics/core/constants/app_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../data/external_trip_models.dart';
import 'external_trip_card.dart' show tripTypeColor, tripTypeBg, formatTripDate;

final _moneyFmt = NumberFormat('#,##0.00', 'en_IN');

class ExternalTripDetailSheet extends StatelessWidget {
  final ExternalTrip trip;
  final bool canManage;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ExternalTripDetailSheet({
    super.key,
    required this.trip,
    this.canManage = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = tripTypeColor(trip.tripType);
    final profitColor =
        trip.profit >= 0 ? AppColors.success : AppColors.error;

    return Material(
      color: isDark ? AppColors.darkCardBg : Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.vehicleNumber,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: tripTypeBg(trip.tripType, isDark: isDark),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Text(
                          trip.tripTypeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(AppIcons.x, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DetailGroup(
                    title: 'Trip',
                    rows: [
                      _DetailRowData('Route',
                          '${trip.fromLocation ?? '—'} → ${trip.toLocation ?? '—'}'),
                      _DetailRowData(
                          'Start Date', formatTripDate(trip.startDate)),
                      _DetailRowData('End Date', formatTripDate(trip.endDate)),
                      _DetailRowData('Driver', trip.driverName ?? '—'),
                      if (trip.driverPhone != null &&
                          trip.driverPhone!.isNotEmpty)
                        _DetailRowData('Driver Phone', trip.driverPhone!),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _DetailGroup(
                    title: 'Customer',
                    rows: [
                      _DetailRowData('Name', trip.customerName ?? '—'),
                      _DetailRowData('Phone', trip.customerPhone ?? '—'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _CostBreakdown(trip: trip, profitColor: profitColor),
                  if (trip.notes != null && trip.notes!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _DetailGroup(
                      title: 'Notes',
                      rows: [_DetailRowData(null, trip.notes!)],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (canManage) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(AppIcons.pencil, size: 16),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDelete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.5),
                        ),
                      ),
                      icon: const Icon(AppIcons.trash2, size: 16),
                      label: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRowData {
  final String? label;
  final String value;
  const _DetailRowData(this.label, this.value);
}

class _DetailGroup extends StatelessWidget {
  final String title;
  final List<_DetailRowData> rows;

  const _DetailGroup({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkPageBg : AppColors.pageBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          ...rows.map(
            (r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (r.label != null)
                    SizedBox(
                      width: 100,
                      child: Text(
                        r.label!,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      r.value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CostBreakdown extends StatelessWidget {
  final ExternalTrip trip;
  final Color profitColor;

  const _CostBreakdown({required this.trip, required this.profitColor});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final valueColor =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkPageBg : AppColors.pageBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COSTS & PAYMENT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          ...trip.costItems.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(fontSize: 13, color: labelColor),
                    ),
                  ),
                  Text(
                    '₹${_moneyFmt.format(item.amount)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: valueColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(
            height: 18,
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
          _TotalRow(
            label: 'Total Cost',
            value: '₹${_moneyFmt.format(trip.totalCost)}',
            color: valueColor,
          ),
          const SizedBox(height: 4),
          _TotalRow(
            label: 'Amount Received',
            value: '₹${_moneyFmt.format(trip.amountReceived)}',
            color: valueColor,
          ),
          const SizedBox(height: 4),
          _TotalRow(
            label: 'Profit',
            value:
                '${trip.profit >= 0 ? '+' : '−'}₹${_moneyFmt.format(trip.profit.abs())}',
            color: profitColor,
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _TotalRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}
