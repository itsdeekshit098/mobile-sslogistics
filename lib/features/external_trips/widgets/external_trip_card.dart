import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_sslogistics/core/constants/app_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../data/external_trip_models.dart';

final _dateFormat = DateFormat('dd MMM yyyy');
final _moneyFmt = NumberFormat('#,##0', 'en_IN');

Color tripTypeColor(String tripType) => tripType == tripTypeCompanyOncall
    ? AppColors.tileExternalIcon
    : AppColors.tileClientsIcon;

Color tripTypeBg(String tripType) => tripType == tripTypeCompanyOncall
    ? AppColors.tileExternalBg
    : AppColors.tileClientsBg;

String formatTripDate(String? isoDate) {
  if (isoDate == null || isoDate.isEmpty) return '—';
  final parsed = DateTime.tryParse(isoDate);
  return parsed != null ? _dateFormat.format(parsed) : isoDate;
}

String formatMoney(double amount) => '₹${_moneyFmt.format(amount)}';

class ExternalTripCard extends StatelessWidget {
  final ExternalTrip trip;
  final bool canManage;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ExternalTripCard({
    super.key,
    required this.trip,
    this.canManage = false,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final accent = tripTypeColor(trip.tripType);
    final hasRoute = (trip.fromLocation?.isNotEmpty ?? false) ||
        (trip.toLocation?.isNotEmpty ?? false);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      surfaceTintColor: Colors.transparent,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border, width: 0.8),
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
                              _TripTypeBadge(tripType: trip.tripType),
                              const SizedBox(height: 10),
                              Text(
                                trip.vehicleNumber,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _InfoRow(
                                icon: AppIcons.calendar,
                                text: formatTripDate(trip.startDate),
                              ),
                              if (hasRoute) ...[
                                const SizedBox(height: 4),
                                _InfoRow(
                                  icon: AppIcons.mapPin,
                                  text:
                                      '${trip.fromLocation ?? '—'} → ${trip.toLocation ?? '—'}',
                                ),
                              ],
                              if (trip.driverName != null &&
                                  trip.driverName!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                _InfoRow(
                                  icon: AppIcons.user,
                                  text: trip.driverName!,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Icon(
                              AppIcons.chevronRight,
                              size: 24,
                              color: onTap != null
                                  ? AppColors.textPrimary
                                  : AppColors.textMuted,
                            ),
                            if (canManage) ...[
                              const SizedBox(height: 12),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _IconActionBtn(
                                    icon: AppIcons.pencil,
                                    color: AppColors.primary,
                                    onTap: onEdit,
                                  ),
                                  const SizedBox(width: 8),
                                  _IconActionBtn(
                                    icon: AppIcons.trash2,
                                    color: AppColors.error,
                                    onTap: onDelete,
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _MoneyBand(
                      cost: trip.totalCost,
                      received: trip.amountReceived,
                      profit: trip.profit,
                    ),
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

class _TripTypeBadge extends StatelessWidget {
  final String tripType;
  const _TripTypeBadge({required this.tripType});

  @override
  Widget build(BuildContext context) {
    final color = tripTypeColor(tripType);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tripTypeBg(tripType),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        (tripTypeLabels[tripType] ?? tripType).toUpperCase(),
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textMuted),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _MoneyBand extends StatelessWidget {
  final double cost;
  final double received;
  final double profit;

  const _MoneyBand({
    required this.cost,
    required this.received,
    required this.profit,
  });

  @override
  Widget build(BuildContext context) {
    final profitColor = profit >= 0 ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _MoneyItem(
                label: 'Cost',
                value: formatMoney(cost),
                color: AppColors.textPrimary,
              ),
            ),
            const VerticalDivider(color: AppColors.border, width: 18),
            Expanded(
              child: _MoneyItem(
                label: 'Received',
                value: formatMoney(received),
                color: AppColors.textPrimary,
              ),
            ),
            const VerticalDivider(color: AppColors.border, width: 18),
            Expanded(
              child: _MoneyItem(
                label: 'Profit',
                value:
                    '${profit >= 0 ? '+' : '−'}${formatMoney(profit.abs())}',
                color: profitColor,
              ),
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
  final Color color;

  const _MoneyItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
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
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
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

  const _IconActionBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

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
