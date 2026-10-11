import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../data/attendance_models.dart';

/// A driver's month: totals, the 31 days as one coloured strip, and — when
/// opened — the same days as a calendar whose cells jump to that day.
class AttendanceMonthCard extends StatelessWidget {
  final AttendanceMonthDriver driver;
  final List<String> dates;
  final String today;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<String> onOpenDay;

  const AttendanceMonthCard({
    super.key,
    required this.driver,
    required this.dates,
    required this.today,
    required this.expanded,
    required this.onToggle,
    required this.onOpenDay,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              driver.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${driver.totals.absent} absent · ${driver.totals.leave} leave',
                              style: TextStyle(fontSize: 12.5, color: secondary),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${driver.totals.shifts}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                            ),
                          ),
                          Text('shifts', style: TextStyle(fontSize: 11, color: secondary)),
                        ],
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        expanded ? Icons.expand_more : Icons.chevron_right,
                        color: secondary,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final date in dates)
                        Expanded(
                          child: Container(
                            height: 14,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: _stripColor(driver.days[date], date.compareTo(today) > 0, isDark),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (expanded) _Calendar(driver: driver, dates: dates, today: today, onOpenDay: onOpenDay),
        ],
      ),
    );
  }
}

Color _stripColor(AttendanceMark? mark, bool future, bool isDark) {
  final idle = isDark ? AppColors.darkBorder : AppColors.border;
  if (future) return idle.withValues(alpha: 0.5);
  if (mark == null) return idle;
  if (mark.isAbsent) return AppColors.error;
  if (mark.isLeave) return AppColors.warning;
  return mark.isFullDay ? AppColors.primary : AppColors.primary.withValues(alpha: 0.45);
}

/// The strip's colour key, shown once above the list.
class AttendanceMonthLegend extends StatelessWidget {
  const AttendanceMonthLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final color = context.isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    Widget item(Color swatch, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: swatch, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        );

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        item(AppColors.primary, 'Full day'),
        item(AppColors.primary.withValues(alpha: 0.45), 'Part'),
        item(AppColors.error, 'Absent'),
        item(AppColors.warning, 'Leave'),
      ],
    );
  }
}

class _Calendar extends StatelessWidget {
  final AttendanceMonthDriver driver;
  final List<String> dates;
  final String today;
  final ValueChanged<String> onOpenDay;

  const _Calendar({
    required this.driver,
    required this.dates,
    required this.today,
    required this.onOpenDay,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    // Sunday-first grid: pad the first week, then fill 7 per row.
    final lead = parseDateOnly(dates.first).weekday % 7;
    final cells = <String?>[...List.filled(lead, null), ...dates];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
      child: Column(
        children: [
          Row(
            children: [
              for (final initial in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                Expanded(
                  child: Center(
                    child: Text(
                      initial,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: secondary),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var week = 0; week < cells.length; week += 7)
            Row(
              children: [
                for (final date in cells.sublist(week, week + 7))
                  Expanded(
                    child: date == null
                        ? const SizedBox(height: 46)
                        : _DayCell(
                            date: date,
                            mark: driver.days[date],
                            isToday: date == today,
                            isFuture: date.compareTo(today) > 0,
                            onTap: () => onOpenDay(date),
                          ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final String date;
  final AttendanceMark? mark;
  final bool isToday;
  final bool isFuture;
  final VoidCallback onTap;

  const _DayCell({
    required this.date,
    required this.mark,
    required this.isToday,
    required this.isFuture,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final idle = isDark ? AppColors.darkBorder : AppColors.border;
    final current = mark ?? AttendanceMark.empty;

    Widget marks;
    if (isFuture) {
      marks = const SizedBox(height: 16);
    } else if (current.isOff) {
      final color = current.isAbsent ? AppColors.error : AppColors.warning;
      marks = Container(
        width: 24,
        height: 16,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: current.isAbsent
              ? (isDark ? AppColors.darkErrorBg : AppColors.errorBg)
              : (isDark ? AppColors.darkWarningBg : AppColors.warningBg),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          current.isAbsent ? 'A' : 'L',
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color),
        ),
      );
    } else {
      marks = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final shift in kShifts)
            Container(
              width: 6,
              height: 14,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: current.has(shift) ? AppColors.primary : idle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      );
    }

    return Semantics(
      button: !isFuture,
      label: '${formatDayLabel(date)}: ${current.label}',
      child: InkWell(
        onTap: isFuture ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 46,
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: isToday ? Border.all(color: AppColors.primary, width: 1.5) : null,
          ),
          child: ExcludeSemantics(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${int.parse(date.substring(8))}',
                  style: TextStyle(fontSize: 11, color: secondary),
                ),
                const SizedBox(height: 2),
                marks,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
