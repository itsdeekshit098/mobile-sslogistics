import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobile_sslogistics/core/constants/app_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/models/vehicle_model.dart';
import '../../diesel/providers/vehicle_provider.dart';
import '../data/external_trip_models.dart';
import '../providers/external_trip_provider.dart';

final _apiDateFmt = DateFormat('yyyy-MM-dd');
final _displayDateFmt = DateFormat('dd MMM');

class ExternalTripFilterBar extends ConsumerWidget {
  const ExternalTripFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(externalTripListProvider).valueOrNull;
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final notifier = ref.read(externalTripListProvider.notifier);

    void apply({
      String? fromDate,
      String? toDate,
      int? vehicleId,
      String? tripType,
      bool keepDates = false,
      bool keepVehicle = false,
      bool keepTripType = false,
    }) {
      notifier.applyFilters(
        fromDate: keepDates ? state?.fromDate : fromDate,
        toDate: keepDates ? state?.toDate : toDate,
        vehicleId: keepVehicle ? state?.vehicleId : vehicleId,
        tripType: keepTripType ? state?.tripType : tripType,
      );
    }

    final moreFiltersActive = state?.tripType != null ||
        state?.fromDate != null ||
        state?.toDate != null;
    final moreFiltersCount = (state?.tripType != null ? 1 : 0) +
        (state?.fromDate != null || state?.toDate != null ? 1 : 0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? AppColors.darkPageBg : AppColors.pageBg,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: vehiclesAsync.when(
              loading: () => const _FilterSkeleton(),
              error: (e, _) => const _FilterButton(
                icon: AppIcons.truck,
                label: 'Vehicles unavailable',
                onTap: null,
              ),
              data: (vehicles) => _FilterButton(
                icon: AppIcons.truck,
                label: _vehicleLabel(vehicles, state?.vehicleId),
                active: state?.vehicleId != null,
                onTap: () async {
                  final picked = await showModalBottomSheet<_VehiclePick>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _VehiclePickerSheet(
                      vehicles: vehicles,
                      selectedId: state?.vehicleId,
                    ),
                  );
                  if (picked != null) {
                    apply(
                      vehicleId: picked.vehicleId,
                      keepDates: true,
                      keepTripType: true,
                    );
                  }
                },
              ),
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
                initialTripType: state?.tripType,
                initialFromDate: state?.fromDate,
                initialToDate: state?.toDate,
                onApply: (tripType, fromDate, toDate) => apply(
                  tripType: tripType,
                  fromDate: fromDate,
                  toDate: toDate,
                  keepVehicle: true,
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
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
                ),
                child: Icon(
                  AppIcons.x,
                  size: 18,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _vehicleLabel(List<Vehicle> vehicles, int? selectedId) {
    if (selectedId == null) return 'All vehicles';
    try {
      return vehicles.firstWhere((v) => v.id == selectedId).plateNumber;
    } catch (_) {
      return 'All vehicles';
    }
  }
}

class _FilterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  const _FilterButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBorder = isDark ? AppColors.darkBorder : AppColors.border;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final primaryTextColor =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final borderColor = active ? AppColors.primary : defaultBorder;
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
              color: primaryTextColor,
            ),
          ],
        ),
      ),
    );
  }
}

// ── "More filters" button + bottom sheet: trip type, date range ────────────

class _MoreFiltersButton extends StatelessWidget {
  final bool active;
  final int count;
  final VoidCallback onTap;

  const _MoreFiltersButton({
    required this.active,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        width: 46,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCardBg : Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: active
                ? AppColors.primary
                : (isDark ? AppColors.darkBorder : AppColors.border),
            width: active ? 1.6 : 1.0,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Icon(
                Icons.tune_rounded,
                size: 20,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
            if (count > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Text(
                    '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MoreFiltersSheet extends StatefulWidget {
  final String? initialTripType;
  final String? initialFromDate;
  final String? initialToDate;
  final void Function(String? tripType, String? fromDate, String? toDate) onApply;

  const _MoreFiltersSheet({
    required this.initialTripType,
    required this.initialFromDate,
    required this.initialToDate,
    required this.onApply,
  });

  @override
  State<_MoreFiltersSheet> createState() => _MoreFiltersSheetState();
}

class _MoreFiltersSheetState extends State<_MoreFiltersSheet> {
  late String? _tripType = widget.initialTripType;
  late DateTime? _fromDate =
      widget.initialFromDate != null ? DateTime.tryParse(widget.initialFromDate!) : null;
  late DateTime? _toDate =
      widget.initialToDate != null ? DateTime.tryParse(widget.initialToDate!) : null;

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initialRange = _fromDate != null && _toDate != null
        ? DateTimeRange(start: _fromDate!, end: _toDate!)
        : null;
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
      });
    }
  }

  void _clearAll() {
    setState(() {
      _tripType = null;
      _fromDate = null;
      _toDate = null;
    });
  }

  void _apply() {
    widget.onApply(
      _tripType,
      _fromDate != null ? _apiDateFmt.format(_fromDate!) : null,
      _toDate != null ? _apiDateFmt.format(_toDate!) : null,
    );
    Navigator.pop(context);
  }

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
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final primaryTextColor =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.textMuted;
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
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: primaryTextColor,
                        ),
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
                          'Trip type',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor,
                          ),
                        ),
                      ),
                      _SegmentedRow(
                        options: const [null, tripTypeCompanyOncall, tripTypeExternalUser],
                        labels: const {
                          null: 'All',
                          tripTypeCompanyOncall: 'Company On-Call',
                          tripTypeExternalUser: 'External',
                        },
                        selected: _tripType,
                        onSelected: (v) => setState(() => _tripType = v),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Date range',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: _pickDateRange,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: borderColor),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(AppIcons.calendar, size: 17, color: mutedColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _dateRangeLabel,
                                  style: TextStyle(fontSize: 14, color: primaryTextColor),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_fromDate != null || _toDate != null)
                                GestureDetector(
                                  onTap: () => setState(() {
                                    _fromDate = null;
                                    _toDate = null;
                                  }),
                                  child: Icon(AppIcons.x, size: 15, color: mutedColor),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: ElevatedButton(
                  onPressed: _apply,
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentedRow extends StatelessWidget {
  final List<String?> options;
  final Map<String?, String> labels;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _SegmentedRow({
    required this.options,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final unselectedBg = isDark ? AppColors.darkCardBg : Colors.white;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    return Row(
      children: options.map((opt) {
        final isSelected = opt == selected;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: opt == options.last ? 0 : 8),
            child: InkWell(
              onTap: () => onSelected(opt),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : unselectedBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : borderColor,
                  ),
                ),
                child: Center(
                  child: Text(
                    labels[opt] ?? opt ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : secondaryColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Wrapper so "All vehicles" (null id) is distinguishable from a dismissed
/// sheet (null result).
class _VehiclePick {
  final int? vehicleId;
  const _VehiclePick(this.vehicleId);
}

class _VehiclePickerSheet extends StatefulWidget {
  final List<Vehicle> vehicles;
  final int? selectedId;

  const _VehiclePickerSheet({required this.vehicles, this.selectedId});

  @override
  State<_VehiclePickerSheet> createState() => _VehiclePickerSheetState();
}

class _VehiclePickerSheetState extends State<_VehiclePickerSheet> {
  String _query = '';

  List<Vehicle> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.vehicles;
    return widget.vehicles.where((vehicle) {
      final haystack = [
        vehicle.plateNumber,
        vehicle.make,
        vehicle.model,
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final media = MediaQuery.of(context);
    final keyboardHeight = media.viewInsets.bottom;
    final maxListHeight = (media.size.height - keyboardHeight) * 0.42;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final primaryTextColor =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

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
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    const Icon(
                      AppIcons.truck,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Filter by vehicle (${widget.vehicles.length})',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TextField(
                  autofocus: true,
                  onChanged: (value) => setState(() => _query = value),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search vehicle number, make, model',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: isDark ? AppColors.darkPageBg : AppColors.pageBg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: maxListHeight.clamp(160.0, 420.0),
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      dense: true,
                      title: Text(
                        'All vehicles',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: widget.selectedId == null
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: widget.selectedId == null
                              ? AppColors.primary
                              : primaryTextColor,
                        ),
                      ),
                      trailing: widget.selectedId == null
                          ? const Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: AppColors.primary,
                            )
                          : null,
                      onTap: () =>
                          Navigator.pop(context, const _VehiclePick(null)),
                    ),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            'No vehicles found',
                            style: TextStyle(color: secondaryColor),
                          ),
                        ),
                      )
                    else
                      ...filtered.map(
                        (v) => ListTile(
                          dense: true,
                          title: Text(
                            v.plateNumber,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: widget.selectedId == v.id
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: widget.selectedId == v.id
                                  ? AppColors.primary
                                  : primaryTextColor,
                            ),
                          ),
                          subtitle: [v.make, v.model]
                                  .whereType<String>()
                                  .join(' ')
                                  .isEmpty
                              ? null
                              : Text(
                                  [v.make, v.model]
                                      .whereType<String>()
                                      .join(' '),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: secondaryColor,
                                  ),
                                ),
                          trailing: widget.selectedId == v.id
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: AppColors.primary,
                                )
                              : null,
                          onTap: () =>
                              Navigator.pop(context, _VehiclePick(v.id)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterSkeleton extends StatelessWidget {
  const _FilterSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBorder : AppColors.border,
        borderRadius: BorderRadius.circular(13),
      ),
    );
  }
}
