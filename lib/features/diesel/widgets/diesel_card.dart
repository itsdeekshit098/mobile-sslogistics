import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_sslogistics/core/constants/app_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../data/diesel_models.dart';

final _dateFormat = DateFormat('dd MMM yyyy');
final _timeFormat = DateFormat('hh:mm a');
final _numFmt = NumberFormat('#,##0.0', 'en_IN');
final _kmFmt = NumberFormat('#,##0', 'en_IN');

class DieselCard extends StatelessWidget {
  final DieselRecord record;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const DieselCard({
    super.key,
    required this.record,
    this.canEdit = false,
    this.canDelete = false,
    this.onEdit,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillDate = DateTime.tryParse(record.fillDate)?.toLocal();
    final dateStr = fillDate != null
        ? _dateFormat.format(fillDate)
        : record.fillDate;
    final timeStr = fillDate != null ? _timeFormat.format(fillDate) : '';

    final isClosed = record.cycleStatus == 'closed';
    final hasStats = record.cycleFuel != null && record.cycleDistance != null;
    final cycleColor = isClosed ? AppColors.success : AppColors.tileDieselIcon;
    final fillColor = record.fillType == 'full'
        ? AppColors.primary
        : AppColors.tileDieselIcon;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      surfaceTintColor: Colors.transparent,
      color: isDark ? AppColors.darkCardBg : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.border,
          width: 0.8,
        ),
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
                child: Container(color: fillColor),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RecordHeader(
                      isFull: record.fillType == 'full',
                      date: dateStr,
                      time: timeStr,
                      driverName: record.driverName,
                      cycleId: record.cycleId,
                      isClosed: isClosed,
                      cycleColor: cycleColor,
                      onTap: onTap,
                      canEdit: canEdit,
                      canDelete: canDelete,
                      onEdit: onEdit,
                      onDelete: onDelete,
                    ),
                    const SizedBox(height: 14),
                    _PrimaryMetricsRow(
                      fillColor: fillColor,
                      fuel: '${_numFmt.format(record.fuelLitres)} L',
                      odometer: '${_kmFmt.format(record.currentOdo)} km',
                    ),
                    if (record.notes != null && record.notes!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _ExpandableNotes(notes: record.notes!),
                    ],
                    if (record.hasWarnings) ...[
                      const SizedBox(height: 10),
                      _WarningPanel(warnings: record.warnings),
                    ],
                    if (hasStats) ...[
                      const SizedBox(height: 14),
                      _CycleSummaryBand(
                        cycleFuel: '${_numFmt.format(record.cycleFuel)} L',
                        cycleDistance:
                            '${_kmFmt.format(record.cycleDistance)} km',
                        mileage: record.kml != null
                            ? '${_numFmt.format(record.kml)} km/L'
                            : null,
                        mileageColor: _kmlColor(
                          record.kml,
                          record.expectedKml,
                          isDark,
                        ),
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

  Color _kmlColor(double? kml, double? expected, bool isDark) {
    if (kml == null || expected == null || expected == 0) {
      return isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    }
    return kml >= expected ? AppColors.success : AppColors.error;
  }
}

class _RecordHeader extends StatelessWidget {
  final bool isFull;
  final String date;
  final String time;
  final String driverName;
  final int cycleId;
  final bool isClosed;
  final Color cycleColor;
  final VoidCallback? onTap;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _RecordHeader({
    required this.isFull,
    required this.date,
    required this.time,
    required this.driverName,
    required this.cycleId,
    required this.isClosed,
    required this.cycleColor,
    required this.onTap,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.textMuted;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FillTypeBadge(isFull: isFull),
              const SizedBox(height: 10),
              Text(
                date,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: primaryColor,
                ),
              ),
              if (time.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  time,
                  style: TextStyle(fontSize: 15, color: secondaryColor),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(AppIcons.user, size: 18, color: mutedColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      driverName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: secondaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Cycle #$cycleId',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  AppIcons.chevronRight,
                  size: 24,
                  color: onTap != null ? primaryColor : mutedColor,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _StatusBadge(
              label: isClosed ? 'CLOSED' : 'OPEN',
              color: cycleColor,
            ),
            if (canEdit || canDelete) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canEdit)
                    _IconActionBtn(
                      icon: AppIcons.pencil,
                      color: AppColors.primary,
                      onTap: onEdit,
                    ),
                  if (canDelete) ...[
                    const SizedBox(width: 8),
                    _IconActionBtn(
                      icon: AppIcons.trash2,
                      color: AppColors.error,
                      onTap: onDelete,
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _PrimaryMetricsRow extends StatelessWidget {
  final Color fillColor;
  final String fuel;
  final String odometer;

  const _PrimaryMetricsRow({
    required this.fillColor,
    required this.fuel,
    required this.odometer,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkPageBg : AppColors.pageBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _MetricSummaryItem(
                icon: AppIcons.droplets,
                iconColor: fillColor,
                value: fuel,
                label: 'This Fill',
              ),
            ),
            VerticalDivider(color: borderColor, width: 22),
            Expanded(
              child: _MetricSummaryItem(
                icon: AppIcons.gauge,
                iconColor: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
                value: odometer,
                label: 'Odometer',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricSummaryItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _MetricSummaryItem({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 28, color: iconColor),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
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

class _FillTypeBadge extends StatelessWidget {
  final bool isFull;
  const _FillTypeBadge({required this.isFull});

  @override
  Widget build(BuildContext context) {
    final color = isFull ? AppColors.primary : AppColors.tileDieselIcon;
    final bg = isFull ? AppColors.tileVehiclesBg : AppColors.tileDieselBg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        isFull ? 'FULL' : 'PARTIAL',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _CycleSummaryBand extends StatelessWidget {
  final String cycleFuel;
  final String cycleDistance;
  final String? mileage;
  final Color mileageColor;

  const _CycleSummaryBand({
    required this.cycleFuel,
    required this.cycleDistance,
    required this.mileage,
    required this.mileageColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.successBg.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _SummaryItem(
                icon: AppIcons.droplets,
                iconColor: AppColors.success,
                value: cycleFuel,
                label: 'Total Fuel',
              ),
            ),
            VerticalDivider(color: borderColor, width: 12),
            Expanded(
              child: _SummaryItem(
                icon: Icons.route_outlined,
                iconColor: secondaryColor,
                value: cycleDistance,
                label: 'Total Distance',
              ),
            ),
            if (mileage != null) ...[
              VerticalDivider(color: borderColor, width: 12),
              Expanded(
                child: _SummaryItem(
                  icon: AppIcons.trendingUp,
                  iconColor: mileageColor,
                  value: mileage!,
                  label: 'Mileage (vs Avg)',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _SummaryItem({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: iconColor == secondaryColor
                        ? AppColors.success
                        : iconColor,
                  ),
                ),
              ),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.15,
                  color: secondaryColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WarningPanel extends StatelessWidget {
  final List<String> warnings;

  const _WarningPanel({required this.warnings});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: warnings
            .map(
              (warning) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  children: [
                    const Icon(
                      AppIcons.alertTriangle,
                      size: 12,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        warning,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ExpandableNotes extends StatefulWidget {
  final String notes;
  const _ExpandableNotes({required this.notes});

  @override
  State<_ExpandableNotes> createState() => _ExpandableNotesState();
}

class _ExpandableNotesState extends State<_ExpandableNotes> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.textMuted;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notes_rounded, size: 13, color: mutedColor),
              const SizedBox(width: 6),
              SizedBox(
                width: 52,
                child: Text(
                  'Notes',
                  style: TextStyle(fontSize: 11, color: mutedColor),
                ),
              ),
              Expanded(
                child: AnimatedCrossFade(
                  duration: const Duration(milliseconds: 200),
                  crossFadeState: _expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: Text(
                    widget.notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: secondaryColor),
                  ),
                  secondChild: Text(
                    widget.notes,
                    style: TextStyle(fontSize: 12, color: secondaryColor),
                  ),
                ),
              ),
            ],
          ),
          // Show toggle only when text overflows (approximated by length)
          if (widget.notes.length > 80 || widget.notes.contains('\n'))
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.only(left: 71, top: 2),
                child: Text(
                  _expanded ? 'Show less' : 'Show more',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
