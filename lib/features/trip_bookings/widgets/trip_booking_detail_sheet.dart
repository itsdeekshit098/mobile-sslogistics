import 'package:flutter/material.dart';
import 'package:mobile_sslogistics/core/constants/app_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../data/trip_booking_models.dart';
import 'trip_booking_card.dart'
    show
        statusColor,
        statusBg,
        formatBookingDate,
        formatBookingMoney,
        isBookingOverdue,
        isBookingToday;

class TripBookingDetailSheet extends StatelessWidget {
  final TripBooking booking;
  final bool canComplete;
  final bool canManage;
  final VoidCallback? onComplete;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;

  const TripBookingDetailSheet({
    super.key,
    required this.booking,
    this.canComplete = false,
    this.canManage = false,
    this.onComplete,
    this.onEdit,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = statusColor(booking.status, isDark: isDark);
    final overdue = isBookingOverdue(booking);
    final today = isBookingToday(booking);
    final isActionable = booking.status == statusConfirmed;

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
                        booking.customerName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusBg(booking.status, isDark: isDark),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: accent.withValues(alpha: 0.28)),
                            ),
                            child: Text(
                              booking.statusLabel,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: accent),
                            ),
                          ),
                          if (overdue)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
                              ),
                              child: const Text(
                                'OVERDUE',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.error),
                              ),
                            ),
                          if (today)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
                              ),
                              child: const Text(
                                'TODAY',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.warning),
                              ),
                            ),
                        ],
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
                    title: 'Customer',
                    rows: [
                      _DetailRowData('Phone', booking.customerPhone ?? '—'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _DetailGroup(
                    title: 'Trip',
                    rows: [
                      _DetailRowData('Route', '${booking.fromLocation} → ${booking.toLocation}'),
                      _DetailRowData('Start Date', formatBookingDate(booking.startDate)),
                      _DetailRowData('End Date', formatBookingDate(booking.endDate)),
                      _DetailRowData(
                        'Vehicle',
                        booking.vehicleNumber ??
                            '${booking.vehicleTypeLabelText}'
                                '${booking.seatingCapacity != null ? ' · ${booking.seatingCapacity} seats' : ''}'
                                ' (not assigned)',
                      ),
                      _DetailRowData('Driver', booking.driverName ?? '—'),
                      if (booking.driverPhone != null && booking.driverPhone!.isNotEmpty)
                        _DetailRowData('Driver Phone', booking.driverPhone!),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _DetailGroup(
                    title: 'Payment',
                    rows: [
                      _DetailRowData(
                        'Quoted Amount',
                        booking.quotedAmount != null ? formatBookingMoney(booking.quotedAmount!) : '—',
                      ),
                      _DetailRowData('Advance Received', formatBookingMoney(booking.advanceAmount)),
                    ],
                  ),
                  if (booking.notes != null && booking.notes!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _DetailGroup(title: 'Notes', rows: [_DetailRowData(null, booking.notes!)]),
                  ],
                ],
              ),
            ),
          ),
          if (isActionable && (canComplete || canManage)) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                children: [
                  if (canComplete)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onComplete,
                        icon: const Icon(AppIcons.checkCircle, size: 16),
                        label: const Text('Complete Booking'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                      ),
                    ),
                  if (canManage) ...[
                    if (canComplete) const SizedBox(height: 12),
                    Row(
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
                            onPressed: onCancel,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                            ),
                            icon: const Icon(AppIcons.x, size: 16),
                            label: const Text('Cancel'),
                          ),
                        ),
                      ],
                    ),
                  ],
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
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
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
                      width: 110,
                      child: Text(
                        r.label!,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      r.value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
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
