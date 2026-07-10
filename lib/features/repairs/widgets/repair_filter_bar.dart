import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobile_sslogistics/core/constants/app_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/models/vehicle_model.dart';
import '../../diesel/providers/vehicle_provider.dart';
import '../data/repair_models.dart';
import '../providers/repair_provider.dart';

final _dateFmt = DateFormat('dd MMM yyyy');

class RepairFilterBar extends ConsumerWidget {
  const RepairFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final techniciansAsync = ref.watch(techniciansProvider);
    final listState = ref.watch(repairListProvider).valueOrNull;
    final filters = listState?.filters ?? const RepairFilters();

    return Container(
      color: AppColors.pageBg,
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
              data: (vehicles) => _VehicleFilterButton(
                vehicles: vehicles,
                selectedId: filters.vehicleId,
                onChanged: (id) => ref.read(repairListProvider.notifier).setFilters(
                      filters.copyWith(vehicleId: id, clearVehicle: id == null),
                    ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _MoreFiltersButton(
            filters: filters,
            technicians: techniciansAsync.valueOrNull ?? const [],
            onApply: (next) =>
                ref.read(repairListProvider.notifier).setFilters(next),
          ),
        ],
      ),
    );
  }
}

// ── Reusable tappable filter button ─────────────────────────────────────────

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
    final borderColor = active ? AppColors.primary : AppColors.border;
    final textColor = active ? AppColors.primary : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: borderColor, width: active ? 1.6 : 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: textColor,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Vehicle filter with searchable bottom sheet ─────────────────────────────

class _VehicleFilterButton extends StatelessWidget {
  final List<Vehicle> vehicles;
  final int? selectedId;
  final ValueChanged<int?> onChanged;

  const _VehicleFilterButton({
    required this.vehicles,
    required this.selectedId,
    required this.onChanged,
  });

  String get _label {
    if (selectedId == null) return 'All vehicles';
    try {
      return vehicles.firstWhere((v) => v.id == selectedId).plateNumber;
    } catch (_) {
      return 'All vehicles';
    }
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _VehiclePickerSheet(
        vehicles: vehicles,
        selectedId: selectedId,
        onSelected: (id) {
          Navigator.pop(context);
          onChanged(id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _FilterButton(
      icon: AppIcons.truck,
      label: _label,
      active: selectedId != null,
      onTap: () => _showPicker(context),
    );
  }
}

class _VehiclePickerSheet extends StatefulWidget {
  final List<Vehicle> vehicles;
  final int? selectedId;
  final ValueChanged<int?> onSelected;

  const _VehiclePickerSheet({
    required this.vehicles,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  State<_VehiclePickerSheet> createState() => _VehiclePickerSheetState();
}

class _VehiclePickerSheetState extends State<_VehiclePickerSheet> {
  String _query = '';

  List<Vehicle> get _filteredVehicles {
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
    final filtered = _filteredVehicles;
    final media = MediaQuery.of(context);
    final keyboardHeight = media.viewInsets.bottom;
    final maxListHeight = (media.size.height - keyboardHeight) * 0.42;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Material(
        color: Colors.white,
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
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    const Icon(AppIcons.truck, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Select vehicle (${widget.vehicles.length})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (widget.selectedId != null)
                      TextButton(
                        onPressed: () => widget.onSelected(null),
                        child: const Text('Clear'),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  autofocus: true,
                  onChanged: (value) => setState(() => _query = value),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search vehicle number, make, model',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.pageBg,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 1.4),
                    ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: maxListHeight.clamp(160.0, 420.0),
                ),
                child: filtered.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            'No vehicles found',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: AppColors.border,
                        ),
                        itemBuilder: (_, i) {
                          final v = filtered[i];
                          final selected = widget.selectedId == v.id;
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 2),
                            title: Text(
                              v.plateNumber,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight:
                                    selected ? FontWeight.w600 : FontWeight.w400,
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                              ),
                            ),
                            subtitle:
                                [v.make, v.model].whereType<String>().join(' ').isEmpty
                                    ? null
                                    : Text(
                                        [v.make, v.model]
                                            .whereType<String>()
                                            .join(' '),
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary),
                                      ),
                            trailing: selected
                                ? const Icon(Icons.check_rounded,
                                    size: 18, color: AppColors.primary)
                                : null,
                            onTap: () => widget.onSelected(v.id),
                          );
                        },
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

// ── "More filters" sheet: category, status, date range, technician ─────────

class _MoreFiltersButton extends StatelessWidget {
  final RepairFilters filters;
  final List<Technician> technicians;
  final ValueChanged<RepairFilters> onApply;

  const _MoreFiltersButton({
    required this.filters,
    required this.technicians,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _MoreFiltersSheet(
          initial: filters,
          technicians: technicians,
          onApply: onApply,
        ),
      ),
      child: Container(
        height: 50,
        width: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: filters.activeCount > 0 ? AppColors.primary : AppColors.border,
            width: filters.activeCount > 0 ? 1.6 : 1.0,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Center(
              child: Icon(Icons.tune_rounded, size: 22, color: AppColors.textSecondary),
            ),
            if (filters.activeCount > 0)
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
                    '${filters.activeCount}',
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
  final RepairFilters initial;
  final List<Technician> technicians;
  final ValueChanged<RepairFilters> onApply;

  const _MoreFiltersSheet({
    required this.initial,
    required this.technicians,
    required this.onApply,
  });

  @override
  State<_MoreFiltersSheet> createState() => _MoreFiltersSheetState();
}

class _MoreFiltersSheetState extends State<_MoreFiltersSheet> {
  late String? _category = widget.initial.category;
  late String? _status = widget.initial.status;
  late DateTime? _fromDate =
      widget.initial.fromDate != null ? DateTime.tryParse(widget.initial.fromDate!) : null;
  late DateTime? _toDate =
      widget.initial.toDate != null ? DateTime.tryParse(widget.initial.toDate!) : null;
  late int? _technicianId = widget.initial.technicianId;

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _fromDate = picked);
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _toDate = picked);
  }

  void _apply() {
    widget.onApply(
      RepairFilters(
        vehicleId: widget.initial.vehicleId,
        category: _category,
        status: _status,
        fromDate: _fromDate != null ? DateFormat('yyyy-MM-dd').format(_fromDate!) : null,
        toDate: _toDate != null ? DateFormat('yyyy-MM-dd').format(_toDate!) : null,
        technicianId: _technicianId,
      ),
    );
    Navigator.pop(context);
  }

  void _clearAll() {
    setState(() {
      _category = null;
      _status = null;
      _fromDate = null;
      _toDate = null;
      _technicianId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Material(
        color: Colors.white,
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
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
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
                      const _FieldLabel('Category'),
                      _SegmentedRow(
                        options: const [null, repairCategoryElectrical, repairCategoryMechanical],
                        labels: const {
                          null: 'All',
                          repairCategoryElectrical: 'Electrical',
                          repairCategoryMechanical: 'Mechanical',
                        },
                        selected: _category,
                        onSelected: (v) => setState(() => _category = v),
                      ),
                      const SizedBox(height: 16),
                      const _FieldLabel('Status'),
                      _SegmentedRow(
                        options: const [null, repairStatusOpen, repairStatusClosed],
                        labels: const {
                          null: 'All',
                          repairStatusOpen: 'Open',
                          repairStatusClosed: 'Closed',
                        },
                        selected: _status,
                        onSelected: (v) => setState(() => _status = v),
                      ),
                      const SizedBox(height: 16),
                      const _FieldLabel('Date range'),
                      Row(
                        children: [
                          Expanded(
                            child: _DateChip(
                              label: _fromDate != null ? _dateFmt.format(_fromDate!) : 'From',
                              onTap: _pickFromDate,
                              onClear: _fromDate != null ? () => setState(() => _fromDate = null) : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _DateChip(
                              label: _toDate != null ? _dateFmt.format(_toDate!) : 'To',
                              onTap: _pickToDate,
                              onClear: _toDate != null ? () => setState(() => _toDate = null) : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const _FieldLabel('Technician'),
                      _TechnicianFieldButton(
                        technicians: widget.technicians,
                        selectedId: _technicianId,
                        onChanged: (id) => setState(() => _technicianId = id),
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

// ── Technician filter with searchable bottom sheet ──────────────────────────

class _TechnicianFieldButton extends StatelessWidget {
  final List<Technician> technicians;
  final int? selectedId;
  final ValueChanged<int?> onChanged;

  const _TechnicianFieldButton({
    required this.technicians,
    required this.selectedId,
    required this.onChanged,
  });

  String get _label {
    if (selectedId == null) return 'All technicians';
    try {
      return technicians.firstWhere((t) => t.id == selectedId).name;
    } catch (_) {
      return 'All technicians';
    }
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TechnicianPickerSheet(
        technicians: technicians,
        selectedId: selectedId,
        onSelected: (id) {
          Navigator.pop(context);
          onChanged(id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showPicker(context),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: selectedId != null ? AppColors.primary : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(AppIcons.userCog, size: 17, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selectedId != null ? FontWeight.w600 : FontWeight.w400,
                  color: selectedId != null ? AppColors.primary : AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.expand_more_rounded, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _TechnicianPickerSheet extends StatefulWidget {
  final List<Technician> technicians;
  final int? selectedId;
  final ValueChanged<int?> onSelected;

  const _TechnicianPickerSheet({
    required this.technicians,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  State<_TechnicianPickerSheet> createState() => _TechnicianPickerSheetState();
}

class _TechnicianPickerSheetState extends State<_TechnicianPickerSheet> {
  String _query = '';

  List<Technician> get _filteredTechnicians {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.technicians;
    return widget.technicians.where((t) {
      final haystack = [
        t.name,
        if (t.phone != null) t.phone!,
        ...t.specializations,
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTechnicians;
    final media = MediaQuery.of(context);
    final keyboardHeight = media.viewInsets.bottom;
    final maxListHeight = (media.size.height - keyboardHeight) * 0.42;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Material(
        color: Colors.white,
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
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    const Icon(AppIcons.userCog, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Select technician (${widget.technicians.length})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (widget.selectedId != null)
                      TextButton(
                        onPressed: () => widget.onSelected(null),
                        child: const Text('Clear'),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  autofocus: true,
                  onChanged: (value) => setState(() => _query = value),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search technician name',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.pageBg,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 1.4),
                    ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: maxListHeight.clamp(160.0, 420.0),
                ),
                child: filtered.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            'No technicians found',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: AppColors.border,
                        ),
                        itemBuilder: (_, i) {
                          final t = filtered[i];
                          final selected = widget.selectedId == t.id;
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 2),
                            title: Text(
                              t.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight:
                                    selected ? FontWeight.w600 : FontWeight.w400,
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                              ),
                            ),
                            subtitle: t.specializations.isEmpty
                                ? null
                                : Text(
                                    t.specializations.join(', '),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary),
                                  ),
                            trailing: selected
                                ? const Icon(Icons.check_rounded,
                                    size: 18, color: AppColors.primary)
                                : null,
                            onTap: () => widget.onSelected(t.id),
                          );
                        },
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

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
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
                  color: isSelected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Center(
                  child: Text(
                    labels[opt] ?? opt ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
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

class _DateChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateChip({required this.label, required this.onTap, this.onClear});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(AppIcons.calendar, size: 15, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(AppIcons.x, size: 15, color: AppColors.textMuted),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Loading skeleton ─────────────────────────────────────────────────────────

class _FilterSkeleton extends StatelessWidget {
  const _FilterSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(13),
      ),
    );
  }
}
