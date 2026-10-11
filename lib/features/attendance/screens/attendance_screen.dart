import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/notification_bell_button.dart';
import '../../../shared/widgets/selectable_chip.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/attendance_models.dart';
import '../providers/attendance_provider.dart';
import '../widgets/attendance_driver_row.dart';
import '../widgets/attendance_month_card.dart';

enum _View { day, month }

/// Daily driver attendance across shifts A, B and C, plus the month register.
///
/// Marks are edited locally and sent together by the Save bar, so a patchy
/// connection costs one retry rather than a half-marked day.
class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  _View _view = _View.day;

  /// 'all' | 'unmarked' | 'off' | 'A' | 'B' | 'C'
  String _filter = 'all';

  /// YYYY-MM shown in the register; null until first opened, then follows
  /// the month stepper.
  String? _month;
  int? _openMonthDriver;

  /// The search field is folded behind an icon so the pinned header stays
  /// short; [_query] is what the lists are filtered by (lower-cased).
  bool _searchOpen = false;
  String _query = '';
  bool _exporting = false;

  AttendanceDayNotifier get _notifier => ref.read(attendanceDayProvider.notifier);

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
    );
  }

  /// Changing the date drops unsaved marks, so ask first when there are any.
  Future<void> _goToDate(AttendanceDayState state, String date) async {
    if (date.compareTo(state.day.currentDay) > 0) return;
    if (state.changes.isNotEmpty) {
      final count = state.changes.length;
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard unsaved changes?'),
          content: Text(
            '$count ${count == 1 ? 'change' : 'changes'} for '
            '${formatDayLabel(state.day.date)} ${count == 1 ? 'has' : 'have'} not been saved.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() {
      _view = _View.day;
      _filter = 'all';
    });
    try {
      await _notifier.goToDate(date);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _pickDate(AttendanceDayState state) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: parseDateOnly(state.day.date),
      firstDate: DateTime.utc(2020),
      lastDate: parseDateOnly(state.day.currentDay),
    );
    if (picked == null || !mounted) return;
    await _goToDate(state, formatDateOnly(picked));
  }

  Future<void> _save() async {
    try {
      await _notifier.save();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance saved')),
      );
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _export(String month) async {
    setState(() => _exporting = true);
    try {
      final path = await ref.read(attendanceRepositoryProvider).downloadMonthExport(month);
      final saved = await FileSaver.instance.saveAs(
        name: 'driver_attendance_$month',
        filePath: path,
        fileExtension: 'csv',
        mimeType: MimeType.csv,
      );
      if (saved != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export saved')),
        );
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  bool _matches(AttendanceMark mark) => switch (_filter) {
        'all' => true,
        'unmarked' => !mark.isMarked,
        'off' => mark.isOff,
        _ => mark.has(_filter),
      };

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(attendanceDayProvider);
    final state = async.valueOrNull;
    final isDark = context.isDark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkPageBg : AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkCardBg : Colors.white,
        elevation: 0,
        surfaceTintColor: isDark ? AppColors.darkCardBg : Colors.white,
        leading: IconButton(
          icon: Icon(AppIcons.arrowLeft, color: textPrimary),
          onPressed: () => context.go('/dashboard'),
          tooltip: 'Back',
        ),
        title: Text(
          'Attendance',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          NotificationBellButton(color: textPrimary),
          Builder(
            builder: (ctx) => IconButton(
              icon: Icon(AppIcons.menu, color: textPrimary),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
              tooltip: 'Open menu',
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(currentPath: '/attendance'),
      body: state == null
          ? async.when(
              loading: () => const SkeletonListCards(infoLines: 1),
              error: (e, _) => ErrorState(
                message: e.toString().replaceFirst('Exception: ', ''),
                onRetry: () => ref.invalidate(attendanceDayProvider),
              ),
              data: (_) => const SizedBox.shrink(),
            )
          : Column(
              children: [
                _Header(
                  state: state,
                  view: _view,
                  filter: _filter,
                  month: _month ?? state.day.date.substring(0, 7),
                  searchOpen: _searchOpen,
                  onToggleSearch: () => setState(() {
                    _searchOpen = !_searchOpen;
                    if (!_searchOpen) _query = '';
                  }),
                  onSearchChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
                  onViewChanged: (view) => setState(() {
                    _view = view;
                    _month ??= state.day.date.substring(0, 7);
                  }),
                  onFilterChanged: (filter) => setState(() => _filter = filter),
                  onStepDay: (days) => _goToDate(state, addDaysTo(state.day.date, days)),
                  onPickDate: () => _pickDate(state),
                  onStepMonth: (months) => setState(() {
                    _month = addMonthsTo(_month ?? state.day.date.substring(0, 7), months);
                    _openMonthDriver = null;
                  }),
                ),
                Expanded(
                  child: _view == _View.day ? _buildDay(state) : _buildMonth(state),
                ),
                if (state.changes.isNotEmpty) _SaveBar(state: state, onSave: _save, onDiscard: _notifier.discard),
              ],
            ),
    );
  }

  Widget _buildDay(AttendanceDayState state) {
    final drivers = state.day.drivers
        .where((d) =>
            _matches(state.markOf(d.driverId)) && matchesDriverSearch(_query, d.name, d.place))
        .toList();
    final showBulk = state.day.editable && state.unmarked > 0;

    if (state.day.drivers.isEmpty) {
      return const EmptyState(
        title: 'No drivers yet',
        subtitle: 'Add drivers first to start marking attendance.',
      );
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: state.loading ? 0.45 : 1,
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        children: [
          if (!state.day.editable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              child: Text(
                'Only an admin can mark attendance.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
            ),
          if (showBulk)
            _BulkStrip(
              state: state,
              onFullDay: () => _notifier.fillUnmarked((_) => AttendanceMark.fullDay),
              onAbsent: () => _notifier.fillUnmarked((_) => AttendanceMark.absent),
              onYesterday: () => _notifier.fillUnmarked(
                (d) => (d.previous?.isMarked ?? false) ? d.previous : null,
              ),
            ),
          if (drivers.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: EmptyState(
                title: _filter == 'unmarked' && _query.isEmpty
                    ? 'Everyone is marked'
                    : 'No drivers here',
                subtitle: _filter == 'unmarked' && _query.isEmpty
                    ? 'Every driver has a mark for this day.'
                    : 'No drivers match this search or filter.',
              ),
            ),
          for (final driver in drivers)
            AttendanceDriverRow(
              key: ValueKey(driver.driverId),
              driver: driver,
              mark: state.markOf(driver.driverId),
              enabled: state.canEdit,
              onChanged: (mark) => _notifier.setMark(driver.driverId, mark),
            ),
        ],
      ),
    );
  }

  Widget _buildMonth(AttendanceDayState state) {
    final month = _month ?? state.day.date.substring(0, 7);
    final async = ref.watch(attendanceMonthProvider(month));

    return async.when(
      loading: () => const SkeletonListCards(infoLines: 1),
      error: (e, _) => ErrorState(
        message: e.toString().replaceFirst('Exception: ', ''),
        onRetry: () => ref.invalidate(attendanceMonthProvider(month)),
      ),
      data: (data) {
        if (data.drivers.isEmpty) {
          return const EmptyState(
            title: 'Nothing marked',
            subtitle: 'No attendance has been marked in this month.',
            icon: AppIcons.calendar,
          );
        }
        final dates = datesInMonth(data.month);
        final drivers = data.drivers
            .where((d) => matchesDriverSearch(_query, d.name, d.place))
            .toList();
        // Wages are worked out from the export, so only admins are offered it.
        final canExport = ref.watch(authProvider).valueOrNull?.isAdmin ?? false;
        return RefreshIndicator(
          onRefresh: () => ref.refresh(attendanceMonthProvider(month).future),
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            itemCount: drivers.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 12, 6),
                  child: Row(
                    children: [
                      const Expanded(child: AttendanceMonthLegend()),
                      if (canExport)
                        TextButton.icon(
                          onPressed: _exporting ? null : () => _export(month),
                          icon: const Icon(Icons.download_outlined, size: 18),
                          label: Text(_exporting ? 'Preparing…' : 'Export'),
                        ),
                    ],
                  ),
                );
              }
              final driver = drivers[i - 1];
              return AttendanceMonthCard(
                key: ValueKey(driver.driverId),
                driver: driver,
                dates: dates,
                today: data.today,
                expanded: _openMonthDriver == driver.driverId,
                onToggle: () => setState(() {
                  _openMonthDriver = _openMonthDriver == driver.driverId ? null : driver.driverId;
                }),
                onOpenDay: (date) => _goToDate(state, date),
              );
            },
          ),
        );
      },
    );
  }
}

/// Stays put while the list scrolls: where you are, how far along the day is,
/// and the counts — which double as the filter.
class _Header extends StatelessWidget {
  final AttendanceDayState state;
  final _View view;
  final String filter;
  final String month;
  final ValueChanged<_View> onViewChanged;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<int> onStepDay;
  final VoidCallback onPickDate;
  final ValueChanged<int> onStepMonth;
  final bool searchOpen;
  final VoidCallback onToggleSearch;
  final ValueChanged<String> onSearchChanged;

  const _Header({
    required this.searchOpen,
    required this.onToggleSearch,
    required this.onSearchChanged,
    required this.state,
    required this.view,
    required this.filter,
    required this.month,
    required this.onViewChanged,
    required this.onFilterChanged,
    required this.onStepDay,
    required this.onPickDate,
    required this.onStepMonth,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final day = state.day;
    final isDayView = view == _View.day;
    final marked = state.total - state.unmarked;

    final canStepForward =
        isDayView ? !day.isToday : month.compareTo(day.currentDay.substring(0, 7)) < 0;
    // Day view: "11 Oct" over "Today" / "Sunday". Month view: one line.
    final label =
        isDayView ? formatDayLabel(day.date).split(', ').last : formatMonthShortLabel(month);
    final sublabel = isDayView ? (day.isToday ? 'Today' : formatWeekdayLabel(day.date)) : null;

    final filters = <(String, String, int)>[
      ('all', 'All', state.total),
      ('unmarked', 'Unmarked', state.unmarked),
      for (final shift in kShifts) (shift, shift, state.onShift(shift)),
      ('off', 'Off', state.off),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : Colors.white,
        border: Border(
          bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 12, 4),
            child: Row(
              children: [
                // The stepper takes whatever the search button and the
                // Day / Month switch leave over; the label is two short lines
                // so it never has to be cut on a narrow phone.
                Expanded(
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(AppIcons.chevronLeft, color: textPrimary),
                        tooltip: isDayView ? 'Previous day' : 'Previous month',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        onPressed: () => isDayView ? onStepDay(-1) : onStepMonth(-1),
                      ),
                      Flexible(
                        child: InkWell(
                          onTap: isDayView ? onPickDate : null,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                                if (sublabel != null)
                                  Text(
                                    sublabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11, color: secondary),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          AppIcons.chevronRight,
                          color: canStepForward ? textPrimary : secondary,
                        ),
                        tooltip: isDayView ? 'Next day' : 'Next month',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        onPressed: canStepForward
                            ? () => isDayView ? onStepDay(1) : onStepMonth(1)
                            : null,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(searchOpen ? AppIcons.x : Icons.search, color: textPrimary),
                  tooltip: searchOpen ? 'Close search' : 'Search drivers',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  onPressed: onToggleSearch,
                ),
                SegmentedButton<_View>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  segments: const [
                    ButtonSegment(value: _View.day, label: Text('Day')),
                    ButtonSegment(value: _View.month, label: Text('Month')),
                  ],
                  selected: {view},
                  onSelectionChanged: (selection) => onViewChanged(selection.first),
                ),
              ],
            ),
          ),
          if (searchOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: TextField(
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search driver or place',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          if (isDayView) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: state.total == 0 ? 0 : marked / state.total,
                        minHeight: 4,
                        backgroundColor: isDark ? AppColors.darkBorder : AppColors.border,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$marked of ${state.total} marked',
                    style: TextStyle(fontSize: 11.5, color: secondary),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(
                children: [
                  for (final (key, label, count) in filters)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SelectableChip(
                        label: '$label  $count',
                        selected: filter == key,
                        onTap: () => onFilterChanged(key),
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

/// Finishes everyone still unmarked in one tap; gone once the day is complete.
class _BulkStrip extends StatelessWidget {
  final AttendanceDayState state;
  final VoidCallback onFullDay;
  final VoidCallback onAbsent;
  final VoidCallback onYesterday;

  const _BulkStrip({
    required this.state,
    required this.onFullDay,
    required this.onAbsent,
    required this.onYesterday,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final enabled = state.canEdit;

    Widget action(String label, VoidCallback? onTap) => Padding(
          padding: const EdgeInsets.only(left: 6),
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              backgroundColor: isDark ? AppColors.darkCardBg : Colors.white,
              foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              side: BorderSide(color: AppColors.warning.withValues(alpha: 0.45)),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            child: Text(label),
          ),
        );

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 2, 12, 6),
      padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkWarningBg : AppColors.warningBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${state.unmarked} left',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.warning,
              ),
            ),
          ),
          action('Full day', enabled ? onFullDay : null),
          action('Absent', enabled ? onAbsent : null),
          action(
            'As yesterday',
            enabled && state.copyableFromYesterday > 0 ? onYesterday : null,
          ),
        ],
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  final AttendanceDayState state;
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  const _SaveBar({required this.state, required this.onSave, required this.onDiscard});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final count = state.changes.length;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : Colors.white,
        border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              TextButton(
                onPressed: state.saving ? null : onDiscard,
                child: const Text('Discard'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: state.saving ? null : onSave,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  child: Text(
                    state.saving
                        ? 'Saving…'
                        : 'Save $count ${count == 1 ? 'change' : 'changes'}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
