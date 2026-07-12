import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_sslogistics/core/constants/app_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../data/diesel_models.dart';

final _dateTimeFmt = DateFormat('dd MMM yyyy, hh:mm a');
final _numFmt = NumberFormat('#,##0.0', 'en_IN');
final _moneyFmt = NumberFormat('#,##0.00', 'en_IN');
final _kmFmt = NumberFormat('#,##0', 'en_IN');

class DieselDetailSheet extends StatelessWidget {
  final DieselRecord record;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const DieselDetailSheet({
    super.key,
    required this.record,
    this.canEdit = false,
    this.canDelete = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillDate = DateTime.tryParse(record.fillDate)?.toLocal();
    final dateTime = fillDate != null
        ? _dateTimeFmt.format(fillDate)
        : _display(record.fillDate);
    final isFull = record.fillType == 'full';
    final isClosed = record.cycleStatus == 'closed';
    final accent = isFull ? AppColors.primary : AppColors.tileDieselIcon;
    final statusColor = isClosed ? AppColors.success : AppColors.tileDieselIcon;
    final mileageGood =
        record.kml != null &&
        record.expectedKml != null &&
        record.kml! >= record.expectedKml!;
    final mileageBad =
        record.kml != null &&
        record.expectedKml != null &&
        record.kml! < record.expectedKml!;
    final performanceColor = mileageBad ? AppColors.error : AppColors.success;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkPageBg : AppColors.pageBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(AppIcons.chevronLeft),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      'Record Details',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                children: [
                  _HeroCard(
                    accent: accent,
                    isFull: isFull,
                    cycleId: record.cycleId,
                    status: isClosed ? 'CLOSED' : 'OPEN',
                    statusColor: statusColor,
                  ),
                  const SizedBox(height: 14),
                  _DetailsCard(
                    rows: [
                      _DetailRowData(
                        AppIcons.calendar,
                        'Date & Time',
                        dateTime,
                      ),
                      _DetailRowData(
                        AppIcons.user,
                        'Driver',
                        _display(record.driverName),
                      ),
                      _DetailRowData(
                        AppIcons.truck,
                        'Vehicle',
                        _display(record.vehiclePlate),
                      ),
                      _DetailRowData(
                        AppIcons.droplets,
                        'Fuel Filled',
                        '${_numFmt.format(record.fuelLitres)} L',
                      ),
                      _DetailRowData(
                        AppIcons.gauge,
                        'Odometer Reading',
                        '${_kmFmt.format(record.currentOdo)} km',
                      ),
                      _DetailRowData(
                        Icons.history_rounded,
                        'Previous Odometer',
                        _km(record.prevOdo),
                      ),
                      _DetailRowData(
                        Icons.route_outlined,
                        'Distance',
                        _km(record.distance),
                      ),
                      if (isFull && record.cycleDistance != null)
                        _DetailRowData(
                          Icons.route_outlined,
                          'Distance (for this cycle)',
                          _km(record.cycleDistance),
                          highlight: true,
                          valueColor: performanceColor,
                        ),
                      if (isFull && record.cycleFuel != null)
                        _DetailRowData(
                          AppIcons.droplets,
                          'Total Fuel (for this cycle)',
                          _litres(record.cycleFuel),
                          highlight: true,
                          valueColor: performanceColor,
                        ),
                      if (isFull && record.kml != null)
                        _DetailRowData(
                          AppIcons.trendingUp,
                          'Mileage (for this cycle)',
                          _kml(record.kml),
                          highlight: true,
                          prominent: true,
                          valueColor: performanceColor,
                          suffixIcon: mileageGood
                              ? Icons.arrow_upward_rounded
                              : mileageBad
                              ? Icons.arrow_downward_rounded
                              : null,
                        ),
                      if (isFull && record.costPerKm != null)
                        _DetailRowData(
                          AppIcons.indianRupee,
                          'Cost / km',
                          _money(record.costPerKm),
                          highlight: true,
                          valueColor: performanceColor,
                        ),
                      if (isFull && record.devPct != null)
                        _DetailRowData(
                          Icons.percent_rounded,
                          'Deviation (vs expected)',
                          _percent(record.devPct),
                          highlight: true,
                          valueColor: performanceColor,
                          suffixIcon: record.devPct! >= 0
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                        ),
                      _DetailRowData(
                        Icons.loop_rounded,
                        'Cycle',
                        '#${record.cycleId}',
                      ),
                      _DetailRowData(
                        AppIcons.indianRupee,
                        'Price / Litre',
                        _money(record.pricePerL),
                      ),
                      _DetailRowData(
                        AppIcons.indianRupee,
                        'Amount',
                        _money(record.amount),
                      ),
                      if (!isFull)
                        _DetailRowData(
                          AppIcons.indianRupee,
                          'Cost / km',
                          _money(record.costPerKm),
                        ),
                      _DetailRowData(
                        AppIcons.mapPin,
                        'Station',
                        _display(record.station),
                      ),
                      _DetailRowData(
                        Icons.payments_outlined,
                        'Payment',
                        _display(record.paymentMethod),
                      ),
                      _DetailRowData(
                        AppIcons.fileText,
                        'Receipt',
                        _display(record.receiptNumber),
                      ),
                      _DetailRowData(
                        AppIcons.checkCircle,
                        'Verified By',
                        _display(record.verifiedBy),
                      ),
                      _DetailRowData(
                        AppIcons.clock,
                        'Created At',
                        _date(record.createdAt),
                      ),
                      _DetailRowData(
                        AppIcons.fileText,
                        'Remarks',
                        _display(record.notes),
                      ),
                    ],
                  ),
                  if (canEdit || canDelete) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (canEdit)
                          Expanded(
                            child: _ActionButton(
                              icon: AppIcons.pencil,
                              label: 'Edit',
                              color: AppColors.primary,
                              onTap: onEdit,
                            ),
                          ),
                        if (canEdit && canDelete) const SizedBox(width: 12),
                        if (canDelete)
                          Expanded(
                            child: _ActionButton(
                              icon: AppIcons.trash2,
                              label: 'Delete',
                              color: AppColors.error,
                              onTap: onDelete,
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  _CycleHint(isFull: isFull, isClosed: isClosed),
                  if (record.hasWarnings) ...[
                    const SizedBox(height: 12),
                    _WarningBox(warnings: record.warnings),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _display(String? value) =>
      value == null || value.trim().isEmpty ? '-' : value.trim();
  static String _date(String? value) {
    final parsed = value == null ? null : DateTime.tryParse(value)?.toLocal();
    return parsed == null ? '-' : _dateTimeFmt.format(parsed);
  }

  static String _km(double? value) =>
      value == null ? '-' : '${_kmFmt.format(value)} km';
  static String _litres(double? value) =>
      value == null ? '-' : '${_numFmt.format(value)} L';
  static String _kml(double? value) =>
      value == null ? '-' : '${_numFmt.format(value)} km/L';
  static String _percent(double? value) =>
      value == null ? '-' : '${value >= 0 ? '+' : ''}${_numFmt.format(value)}%';
  static String _money(double? value) =>
      value == null ? '-' : '₹ ${_moneyFmt.format(value)}';
}

class _HeroCard extends StatelessWidget {
  final Color accent;
  final bool isFull;
  final int cycleId;
  final String status;
  final Color statusColor;

  const _HeroCard({
    required this.accent,
    required this.isFull,
    required this.cycleId,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent.withValues(alpha: 0.28)),
            ),
            child: Icon(AppIcons.fuel, color: accent, size: 32),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFull ? 'FULL FILL' : 'PARTIAL FILL',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Text(
                      'Cycle #$cycleId',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _TinyBadge(label: status, color: statusColor),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final List<_DetailRowData> rows;

  const _DetailsCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            _DetailRow(data: rows[i], showDivider: i != rows.length - 1),
        ],
      ),
    );
  }
}

class _DetailRowData {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;
  final bool prominent;
  final Color? valueColor;
  final IconData? suffixIcon;

  const _DetailRowData(
    this.icon,
    this.label,
    this.value, {
    this.highlight = false,
    this.prominent = false,
    this.valueColor,
    this.suffixIcon,
  });
}

class _DetailRow extends StatelessWidget {
  final _DetailRowData data;
  final bool showDivider;

  const _DetailRow({required this.data, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final isStatus = data.label == 'Status';
    final statusColor = data.value == 'CLOSED'
        ? AppColors.success
        : AppColors.tileDieselIcon;
    final valueColor = data.valueColor ?? secondaryColor;
    return Column(
      children: [
        Container(
          color: data.highlight
              ? valueColor.withValues(alpha: 0.07)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                data.icon,
                size: 18,
                color: data.highlight ? valueColor : secondaryColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  data.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: secondaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: isStatus
                      ? _TinyBadge(label: data.value, color: statusColor)
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                data.value,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: data.prominent ? 20 : 13,
                                  fontWeight: data.highlight
                                      ? FontWeight.w900
                                      : FontWeight.w700,
                                  color: valueColor,
                                ),
                              ),
                            ),
                            if (data.suffixIcon != null) ...[
                              const SizedBox(width: 4),
                              Icon(
                                data.suffixIcon,
                                size: 16,
                                color: valueColor,
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 42,
            endIndent: 14,
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
      ],
    );
  }
}

class _TinyBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _TinyBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.45)),
        padding: const EdgeInsets.symmetric(vertical: 13),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _CycleHint extends StatelessWidget {
  final bool isFull;
  final bool isClosed;

  const _CycleHint({required this.isFull, required this.isClosed});

  @override
  Widget build(BuildContext context) {
    final text = isFull
        ? (isClosed
              ? 'This full fill closed the cycle. Mileage and cycle totals are now available.'
              : 'This is a full fill. The cycle may close when the backend links the previous partial fills.')
        : 'This is a partial fill. Add a Full Fill to close the cycle and calculate mileage.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tileDieselBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.tileDieselIcon.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.hourglass_empty_rounded,
            size: 22,
            color: AppColors.tileDieselIcon,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningBox extends StatelessWidget {
  final List<String> warnings;

  const _WarningBox({required this.warnings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: warnings
            .map(
              (warning) => Row(
                children: [
                  const Icon(
                    AppIcons.alertTriangle,
                    size: 18,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warning,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}
