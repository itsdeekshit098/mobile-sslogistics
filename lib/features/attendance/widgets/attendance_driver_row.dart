import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/theme/theme_extensions.dart';
import '../data/attendance_models.dart';

/// One driver, one line: a tick for "present all day", the three shifts for
/// part days, and a menu for absent / leave / clear.
///
/// The tick reads as a tri-state checkbox over the A/B/C block beside it —
/// filled for a full day, a dash for some shifts, empty for none.
class AttendanceDriverRow extends StatelessWidget {
  final AttendanceDayDriver driver;
  final AttendanceMark mark;

  /// False for a date this role may not change, or while a save is running.
  final bool enabled;
  final ValueChanged<AttendanceMark> onChanged;

  const AttendanceDriverRow({
    super.key,
    required this.driver,
    required this.mark,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final unmarked = !mark.isMarked;

    return Container(
      // Tight on purpose: with 30–40 drivers, every pixel of row height is
      // another driver on screen.
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unmarked
              ? AppColors.warning.withValues(alpha: 0.55)
              : (isDark ? AppColors.darkBorder : AppColors.border),
        ),
      ),
      child: Row(
        children: [
          _Tick(
            mark: mark,
            onTap: enabled ? () => onChanged(mark.toggleFullDay()) : null,
            semanticLabel: 'Full day, ${driver.name}',
          ),
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
                  driver.isActive ? mark.label : '${mark.label} · Inactive',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: unmarked ? FontWeight.w700 : FontWeight.w400,
                    color: unmarked
                        ? AppColors.warning
                        : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (mark.isOff)
            _OffPill(mark: mark, onClear: enabled ? () => onChanged(AttendanceMark.empty) : null)
          else
            _ShiftBlock(
              mark: mark,
              onToggle: enabled ? (shift) => onChanged(mark.toggleShift(shift)) : null,
            ),
          PopupMenuButton<AttendanceMark>(
            enabled: enabled,
            tooltip: 'More for ${driver.name}',
            padding: EdgeInsets.zero,
            icon: Icon(
              AppIcons.moreVert,
              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
            ),
            onSelected: onChanged,
            itemBuilder: (context) => [
              const PopupMenuItem(value: AttendanceMark.absent, child: Text('Absent')),
              const PopupMenuItem(value: AttendanceMark.leave, child: Text('Leave')),
              PopupMenuItem(
                value: AttendanceMark.empty,
                enabled: mark.isMarked,
                child: const Text('Clear'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tick extends StatelessWidget {
  final AttendanceMark mark;
  final VoidCallback? onTap;
  final String semanticLabel;

  const _Tick({required this.mark, required this.onTap, required this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    final idle = context.isDark ? AppColors.darkTextMuted : AppColors.textMuted;
    final full = mark.isFullDay;
    final partial = mark.isPartial;

    return Semantics(
      button: true,
      checked: full,
      label: semanticLabel,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: full ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  width: 2,
                  color: full || partial ? AppColors.primary : idle,
                ),
              ),
              child: full
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : partial
                      ? const Icon(Icons.remove, size: 16, color: AppColors.primary)
                      : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _ShiftBlock extends StatelessWidget {
  final AttendanceMark mark;
  final ValueChanged<String>? onToggle;

  const _ShiftBlock({required this.mark, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final border = isDark ? AppColors.darkBorder : AppColors.border;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final shift in kShifts)
            Semantics(
              button: true,
              selected: mark.has(shift),
              label: 'Shift $shift',
              child: InkWell(
                onTap: onToggle == null ? null : () => onToggle!(shift),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 38,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: mark.has(shift) ? AppColors.primary : Colors.transparent,
                    border: shift == kShifts.first
                        ? null
                        : Border(
                            left: BorderSide(
                              color: mark.has(shift)
                                  ? Colors.white.withValues(alpha: 0.35)
                                  : border,
                            ),
                          ),
                  ),
                  child: ExcludeSemantics(
                    child: Text(
                      shift,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: mark.has(shift)
                            ? Colors.white
                            : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Stands in for the shift block on an absent / leave day; tapping clears it.
class _OffPill extends StatelessWidget {
  final AttendanceMark mark;
  final VoidCallback? onClear;

  const _OffPill({required this.mark, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final color = mark.isAbsent ? AppColors.error : AppColors.warning;
    final bg = mark.isAbsent
        ? (isDark ? AppColors.darkErrorBg : AppColors.errorBg)
        : (isDark ? AppColors.darkWarningBg : AppColors.warningBg);

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onClear,
        child: SizedBox(
          // Same footprint as the three-shift block, so rows stay aligned.
          width: 116,
          height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                mark.isAbsent ? 'Absent' : 'Leave',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: color),
              ),
              if (onClear != null) ...[
                const SizedBox(width: 6),
                Icon(AppIcons.x, size: 15, color: color),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
