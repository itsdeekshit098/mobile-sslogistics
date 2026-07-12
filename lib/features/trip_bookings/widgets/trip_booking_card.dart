import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_sslogistics/core/constants/app_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../data/trip_booking_models.dart';

final _dateFormat = DateFormat('dd MMM yyyy');
final _moneyFmt = NumberFormat('#,##0', 'en_IN');

String todayIsoStr() => DateTime.now().toIso8601String().substring(0, 10);

bool isBookingOverdue(TripBooking booking) =>
    booking.status == statusConfirmed && booking.startDate.compareTo(todayIsoStr()) < 0;

bool isBookingToday(TripBooking booking) =>
    booking.status == statusConfirmed && booking.startDate == todayIsoStr();

Color statusColor(String status) {
  switch (status) {
    case statusConfirmed:
      return AppColors.primary;
    case statusCompleted:
      return AppColors.success;
    case statusCancelled:
      return AppColors.textMuted;
    default:
      return AppColors.textMuted;
  }
}

Color statusBg(String status) {
  switch (status) {
    case statusConfirmed:
      return AppColors.tileVehiclesBg;
    case statusCompleted:
      return AppColors.successBg;
    case statusCancelled:
      return AppColors.pageBg;
    default:
      return AppColors.pageBg;
  }
}

String formatBookingDate(String? isoDate) {
  if (isoDate == null || isoDate.isEmpty) return '—';
  final parsed = DateTime.tryParse(isoDate);
  return parsed != null ? _dateFormat.format(parsed) : isoDate;
}

String formatBookingMoney(num amount) => '₹${_moneyFmt.format(amount)}';

class TripBookingCard extends StatelessWidget {
  final TripBooking booking;
  final bool canComplete;
  final bool canManage;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;

  const TripBookingCard({
    super.key,
    required this.booking,
    this.canComplete = false,
    this.canManage = false,
    this.onTap,
    this.onComplete,
    this.onEdit,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overdue = isBookingOverdue(booking);
    final today = isBookingToday(booking);
    final accent = overdue
        ? AppColors.error
        : today
            ? AppColors.warning
            : statusColor(booking.status);
    final isActionable = booking.status == statusConfirmed;
    final route = '${booking.fromLocation} → ${booking.toLocation}';
    final vehicleLine = booking.vehicleNumber ??
        '${booking.vehicleTypeLabelText}'
            '${booking.seatingCapacity != null ? ' · ${booking.seatingCapacity} seats' : ''}'
            ' — not assigned yet';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      surfaceTintColor: Colors.transparent,
      color: isDark ? AppColors.darkCardBg : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: overdue
            ? BorderSide(color: AppColors.error.withValues(alpha: 0.4), width: 1.2)
            : today
                ? BorderSide(color: AppColors.warning.withValues(alpha: 0.4), width: 1.2)
                : BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border, width: 0.8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 4,
                child: Container(color: accent),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _StatusBadge(status: booking.status),
                                  if (overdue) const _HighlightBadge(label: 'Overdue', color: AppColors.error),
                                  if (today) const _HighlightBadge(label: 'Today', color: AppColors.warning),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                booking.customerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                ),
                              ),
                              if (booking.customerPhone != null &&
                                  booking.customerPhone!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                _InfoRow(icon: Icons.phone_outlined, text: booking.customerPhone!),
                              ],
                              const SizedBox(height: 4),
                              _InfoRow(icon: AppIcons.calendar, text: formatBookingDate(booking.startDate)),
                              const SizedBox(height: 4),
                              _InfoRow(icon: AppIcons.mapPin, text: route),
                              const SizedBox(height: 4),
                              _InfoRow(icon: AppIcons.truck, text: vehicleLine),
                              if (booking.driverName != null && booking.driverName!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                _InfoRow(icon: AppIcons.user, text: booking.driverName!),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          AppIcons.chevronRight,
                          size: 24,
                          color: onTap != null
                              ? (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)
                              : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _MoneyBand(quoted: booking.quotedAmount, advance: booking.advanceAmount),
                    if (isActionable && (canComplete || canManage)) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (canComplete)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: onComplete,
                                icon: const Icon(AppIcons.checkCircle, size: 15),
                                label: const Text('Complete'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  foregroundColor: AppColors.success,
                                  side: BorderSide(color: AppColors.success.withValues(alpha: 0.5)),
                                ),
                              ),
                            ),
                          if (canManage) ...[
                            if (canComplete) const SizedBox(width: 8),
                            _IconActionBtn(icon: AppIcons.pencil, color: AppColors.primary, onTap: onEdit),
                            const SizedBox(width: 8),
                            _IconActionBtn(icon: AppIcons.x, color: AppColors.error, onTap: onCancel),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: statusBg(status),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        (tripBookingStatusLabels[status] ?? status).toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _HighlightBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _HighlightBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 15, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _MoneyBand extends StatelessWidget {
  final double? quoted;
  final double advance;

  const _MoneyBand({required this.quoted, required this.advance});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkPageBg : AppColors.pageBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _MoneyItem(
                label: 'Quoted',
                value: quoted != null ? formatBookingMoney(quoted!) : '—',
              ),
            ),
            VerticalDivider(color: borderColor, width: 18),
            Expanded(
              child: _MoneyItem(label: 'Advance', value: formatBookingMoney(advance)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoneyItem extends StatelessWidget {
  final String label;
  final String value;

  const _MoneyItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _IconActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _IconActionBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.32)),
        ),
        child: Icon(icon, size: 17, color: color),
      ),
    );
  }
}
