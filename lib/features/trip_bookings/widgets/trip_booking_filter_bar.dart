import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobile_sslogistics/core/constants/app_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../data/trip_booking_models.dart';
import '../providers/trip_booking_provider.dart';

final _apiDateFmt = DateFormat('yyyy-MM-dd');
final _displayDateFmt = DateFormat('dd MMM');

const _statusOptions = ['all', statusConfirmed, statusCompleted, statusCancelled];

String _statusOptionLabel(String status) =>
    status == 'all' ? 'All Statuses' : (tripBookingStatusLabels[status] ?? status);

class TripBookingFilterBar extends ConsumerStatefulWidget {
  const TripBookingFilterBar({super.key});

  @override
  ConsumerState<TripBookingFilterBar> createState() => _TripBookingFilterBarState();
}

class _TripBookingFilterBarState extends ConsumerState<TripBookingFilterBar> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _runSearch(String value, TripBookingListState? state, TripBookingListNotifier notifier) {
    notifier.applyFilters(
      status: state?.status ?? statusConfirmed,
      onDate: state?.onDate,
      fromDate: state?.fromDate,
      toDate: state?.toDate,
      search: value.trim().isEmpty ? null : value.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tripBookingListProvider).valueOrNull;
    final notifier = ref.read(tripBookingListProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    if (_searchCtrl.text != (state?.search ?? '')) {
      _searchCtrl.text = state?.search ?? '';
      _searchCtrl.selection = TextSelection.collapsed(offset: _searchCtrl.text.length);
    }

    final moreFiltersActive =
        state?.onDate != null || state?.fromDate != null || state?.toDate != null;
    final moreFiltersCount = moreFiltersActive ? 1 : 0;

    return Container(
      color: isDark ? AppColors.darkPageBg : AppColors.pageBg,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            onSubmitted: (v) => _runSearch(v, state, notifier),
            onTapOutside: (_) => _runSearch(_searchCtrl.text, state, notifier),
            decoration: InputDecoration(
              hintText: 'Search customer name or phone...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              isDense: true,
              filled: true,
              fillColor: isDark ? AppColors.darkCardBg : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _FilterButton(
                  icon: Icons.filter_list_rounded,
                  label: _statusOptionLabel(state?.status ?? statusConfirmed),
                  active: (state?.status ?? statusConfirmed) != statusConfirmed,
                  onTap: () async {
                    final picked = await showModalBottomSheet<String>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => _StatusPickerSheet(selected: state?.status ?? statusConfirmed),
                    );
                    if (picked != null) {
                      notifier.applyFilters(
                        status: picked,
                        onDate: state?.onDate,
                        fromDate: state?.fromDate,
                        toDate: state?.toDate,
                        search: state?.search,
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              _MoreFiltersButton(
                active: moreFiltersActive,
                count: moreFiltersCount,
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _MoreFiltersSheet(
                    initialOnDate: state?.onDate,
                    initialFromDate: state?.fromDate,
                    initialToDate: state?.toDate,
                    onApply: (onDate, fromDate, toDate) => notifier.applyFilters(
                      status: state?.status ?? statusConfirmed,
                      onDate: onDate,
                      fromDate: fromDate,
                      toDate: toDate,
                      search: state?.search,
                    ),
                  ),
                ),
              ),
              if (state?.hasFilters ?? false) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => notifier.applyFilters(),
                  borderRadius: BorderRadius.circular(13),
                  child: Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCardBg : Colors.white,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: borderColor),
                    ),
                    child: Icon(
                      AppIcons.x,
                      size: 18,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  const _FilterButton({required this.icon, required this.label, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final borderColor = active ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.border);
    final textColor = active ? AppColors.primary : secondaryColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCardBg : Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: borderColor, width: active ? 1.6 : 1.0),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: secondaryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  color: textColor,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreFiltersButton extends StatelessWidget {
  final bool active;
  final int count;
  final VoidCallback onTap;

  const _MoreFiltersButton({required this.active, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = active ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.border);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        width: 46,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCardBg : Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: borderColor, width: active ? 1.6 : 1.0),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Icon(
                AppIcons.calendar,
                size: 18,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
            if (count > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Text(
                    '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusPickerSheet extends StatelessWidget {
  final String selected;
  const _StatusPickerSheet({required this.selected});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    return Material(
      color: isDark ? AppColors.darkCardBg : Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Status',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textPrimary),
                  ),
                ],
              ),
            ),
            ..._statusOptions.map((status) {
              final isSelected = status == selected;
              return ListTile(
                title: Text(
                  _statusOptionLabel(status),
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    color: isSelected ? AppColors.primary : textPrimary,
                  ),
                ),
                trailing: isSelected ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                onTap: () => Navigator.pop(context, status),
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _MoreFiltersSheet extends StatefulWidget {
  final String? initialOnDate;
  final String? initialFromDate;
  final String? initialToDate;
  final void Function(String? onDate, String? fromDate, String? toDate) onApply;

  const _MoreFiltersSheet({
    required this.initialOnDate,
    required this.initialFromDate,
    required this.initialToDate,
    required this.onApply,
  });

  @override
  State<_MoreFiltersSheet> createState() => _MoreFiltersSheetState();
}

class _MoreFiltersSheetState extends State<_MoreFiltersSheet> {
  late DateTime? _onDate =
      widget.initialOnDate != null ? DateTime.tryParse(widget.initialOnDate!) : null;
  late DateTime? _fromDate =
      widget.initialFromDate != null ? DateTime.tryParse(widget.initialFromDate!) : null;
  late DateTime? _toDate = widget.initialToDate != null ? DateTime.tryParse(widget.initialToDate!) : null;

  Future<void> _pickOnDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDate: _onDate ?? now,
    );
    if (picked != null) {
      setState(() {
        _onDate = picked;
        // Exact date and range are alternative ways to narrow by date.
        _fromDate = null;
        _toDate = null;
      });
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initialRange =
        _fromDate != null && _toDate != null ? DateTimeRange(start: _fromDate!, end: _toDate!) : null;
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initialRange,
    );
    if (range != null) {
      setState(() {
        _fromDate = range.start;
        _toDate = range.end;
        _onDate = null;
      });
    }
  }

  void _clearAll() {
    setState(() {
      _onDate = null;
      _fromDate = null;
      _toDate = null;
    });
  }

  void _apply() {
    widget.onApply(
      _onDate != null ? _apiDateFmt.format(_onDate!) : null,
      _fromDate != null ? _apiDateFmt.format(_fromDate!) : null,
      _toDate != null ? _apiDateFmt.format(_toDate!) : null,
    );
    Navigator.pop(context);
  }

  String get _onDateLabel => _onDate != null ? _displayDateFmt.format(_onDate!) : 'Any date';

  String get _dateRangeLabel {
    if (_fromDate == null && _toDate == null) return 'All dates';
    final fromStr = _fromDate != null ? _displayDateFmt.format(_fromDate!) : '…';
    final toStr = _toDate != null ? _displayDateFmt.format(_toDate!) : '…';
    return '$fromStr – $toStr';
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.textMuted;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Material(
        color: isDark ? AppColors.darkCardBg : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filters',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary),
                      ),
                    ),
                    TextButton(onPressed: _clearAll, child: const Text('Clear all')),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'On date',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
                        ),
                      ),
                      InkWell(
                        onTap: _pickOnDate,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: borderColor),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(AppIcons.calendar, size: 17, color: textMuted),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _onDateLabel,
                                  style: TextStyle(fontSize: 14, color: textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_onDate != null)
                                GestureDetector(
                                  onTap: () => setState(() => _onDate = null),
                                  child: Icon(AppIcons.x, size: 15, color: textMuted),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        child: Text(
                          'Date range',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
                        ),
                      ),
                      Opacity(
                        opacity: _onDate != null ? 0.5 : 1,
                        child: InkWell(
                          onTap: _onDate != null ? null : _pickDateRange,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: borderColor),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(AppIcons.calendar, size: 17, color: textMuted),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _dateRangeLabel,
                                    style: TextStyle(fontSize: 14, color: textPrimary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_onDate == null && (_fromDate != null || _toDate != null))
                                  GestureDetector(
                                    onTap: () => setState(() {
                                      _fromDate = null;
                                      _toDate = null;
                                    }),
                                    child: Icon(AppIcons.x, size: 15, color: textMuted),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_onDate != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Clear "On date" to use a range instead.',
                            style: TextStyle(fontSize: 12, color: textMuted),
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: ElevatedButton(onPressed: _apply, child: const Text('Apply Filters')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
