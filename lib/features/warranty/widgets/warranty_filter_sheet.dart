import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../shared/models/vehicle_model.dart';
import '../../../shared/widgets/selectable_chip.dart';
import '../../diesel/providers/vehicle_provider.dart';
import '../../repairs/data/repair_models.dart';
import '../../repairs/providers/repair_provider.dart';
import '../data/warranty_models.dart';

final _dateFmt = DateFormat('dd MMM yyyy');

const _statusOptions = [
  (null, 'All'),
  (warrantyStatusActive, 'Active'),
  (warrantyStatusExpiringSoon, 'Expiring Soon'),
  (warrantyStatusExpired, 'Expired'),
];

class WarrantyFilterSheet extends ConsumerStatefulWidget {
  final WarrantyFilters initial;

  const WarrantyFilterSheet({super.key, required this.initial});

  @override
  ConsumerState<WarrantyFilterSheet> createState() => _WarrantyFilterSheetState();
}

class _WarrantyFilterSheetState extends ConsumerState<WarrantyFilterSheet> {
  late Vehicle? _vehicle;
  late Vendor? _vendor;
  late DateTime? _fromDate;
  late DateTime? _toDate;
  late String? _status;

  @override
  void initState() {
    super.initState();
    _vehicle = null;
    _vendor = null;
    _fromDate = widget.initial.fromDate;
    _toDate = widget.initial.toDate;
    _status = widget.initial.status;
    // Resolve the already-applied vehicle/vendor filter (stored as bare IDs)
    // back to full entities once the lookup lists are available, so
    // reopening this sheet doesn't silently drop them on the next Apply.
    if (widget.initial.vehicleId != null) {
      ref.read(vehiclesProvider.future).then((vehicles) {
        if (!mounted) return;
        final match = vehicles.where((v) => v.id == widget.initial.vehicleId);
        if (match.isNotEmpty) setState(() => _vehicle = match.first);
      });
    }
    if (widget.initial.vendorId != null) {
      ref.read(vendorsProvider.future).then((vendors) {
        if (!mounted) return;
        final match = vendors.where((v) => v.id == widget.initial.vendorId);
        if (match.isNotEmpty) setState(() => _vendor = match.first);
      });
    }
  }

  Future<void> _pickVehicle(List<Vehicle> vehicles) async {
    final picked = await showModalBottomSheet<Vehicle?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EntityPickerSheet<Vehicle>(
        title: 'Filter by vehicle',
        entities: vehicles,
        selected: _vehicle,
        labelBuilder: (v) => v.plateNumber,
        subtitleBuilder: (v) => v.model,
      ),
    );
    if (picked != null || mounted) setState(() => _vehicle = picked);
  }

  Future<void> _pickVendor(List<Vendor> vendors) async {
    final picked = await showModalBottomSheet<Vendor?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EntityPickerSheet<Vendor>(
        title: 'Filter by vendor',
        entities: vendors,
        selected: _vendor,
        labelBuilder: (v) => v.name,
        subtitleBuilder: (v) => v.location,
      ),
    );
    if (picked != null || mounted) setState(() => _vendor = picked);
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _fromDate : _toDate) ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => isFrom ? _fromDate = picked : _toDate = picked);
    }
  }

  void _apply() {
    Navigator.pop(
      context,
      widget.initial.copyWith(
        vehicleId: _vehicle?.id,
        clearVehicleId: _vehicle == null,
        vendorId: _vendor?.id,
        clearVendorId: _vendor == null,
        status: _status,
        clearStatus: _status == null,
        fromDate: _fromDate,
        clearFromDate: _fromDate == null,
        toDate: _toDate,
        clearToDate: _toDate == null,
      ),
    );
  }

  void _clear() {
    setState(() {
      _vehicle = null;
      _vendor = null;
      _status = null;
      _fromDate = null;
      _toDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final vendorsAsync = ref.watch(vendorsProvider);
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return Material(
      color: isDark ? AppColors.darkCardBg : Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    TextButton(onPressed: _clear, child: const Text('Clear all')),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FieldLabel('Status'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _statusOptions.map((option) {
                        final (value, label) = option;
                        return SelectableChip(
                          label: label,
                          selected: _status == value,
                          onTap: () => setState(() => _status = value),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    _FieldLabel('Vehicle'),
                    vehiclesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => const Text('Failed to load vehicles'),
                      data: (vehicles) => _TapField(
                        value: _vehicle?.plateNumber ?? 'All vehicles',
                        icon: AppIcons.truck,
                        muted: _vehicle == null,
                        onTap: () => _pickVehicle(vehicles),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _FieldLabel('Vendor'),
                    vendorsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => const Text('Failed to load vendors'),
                      data: (vendors) => _TapField(
                        value: _vendor?.name ?? 'All vendors',
                        icon: Icons.storefront_outlined,
                        muted: _vendor == null,
                        onTap: () => _pickVendor(vendors),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldLabel('Expiry from'),
                              _TapField(
                                value: _fromDate != null ? _dateFmt.format(_fromDate!) : 'Any',
                                icon: AppIcons.calendar,
                                muted: _fromDate == null,
                                onTap: () => _pickDate(isFrom: true),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldLabel('Expiry to'),
                              _TapField(
                                value: _toDate != null ? _dateFmt.format(_toDate!) : 'Any',
                                icon: AppIcons.calendar,
                                muted: _toDate == null,
                                onTap: () => _pickDate(isFrom: false),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(onPressed: _apply, child: const Text('Apply Filters')),
                    const SizedBox(height: 12),
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

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _TapField extends StatelessWidget {
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final bool muted;

  const _TapField({required this.value, required this.icon, required this.onTap, this.muted = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: mutedColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: muted ? mutedColor : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: mutedColor),
          ],
        ),
      ),
    );
  }
}

/// Generic searchable picker sheet with a leading "All" option to clear the
/// filter — reused for both the vehicle and vendor filters.
class _EntityPickerSheet<T> extends StatefulWidget {
  final String title;
  final List<T> entities;
  final T? selected;
  final String Function(T) labelBuilder;
  final String? Function(T) subtitleBuilder;

  const _EntityPickerSheet({
    required this.title,
    required this.entities,
    required this.selected,
    required this.labelBuilder,
    required this.subtitleBuilder,
  });

  @override
  State<_EntityPickerSheet<T>> createState() => _EntityPickerSheetState<T>();
}

class _EntityPickerSheetState<T> extends State<_EntityPickerSheet<T>> {
  String _query = '';

  List<T> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.entities;
    return widget.entities.where((e) {
      final haystack = [widget.labelBuilder(e), widget.subtitleBuilder(e)]
          .whereType<String>()
          .join(' ')
          .toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filtered;
    final media = MediaQuery.of(context);
    final maxListHeight = (media.size.height - media.viewInsets.bottom) * 0.5;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
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
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  autofocus: true,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: isDark ? AppColors.darkPageBg : AppColors.pageBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                    ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxListHeight.clamp(160.0, 420.0)),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      title: Text(
                        'All',
                        style: TextStyle(
                          fontWeight: widget.selected == null ? FontWeight.w800 : FontWeight.w400,
                          color: widget.selected == null
                              ? AppColors.primary
                              : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                        ),
                      ),
                      trailing: widget.selected == null
                          ? const Icon(Icons.check_rounded, color: AppColors.primary)
                          : null,
                      onTap: () => Navigator.pop(context, null),
                    ),
                    ...filtered.map((e) {
                      final selected = e == widget.selected;
                      final subtitle = widget.subtitleBuilder(e);
                      return ListTile(
                        title: Text(
                          widget.labelBuilder(e),
                          style: TextStyle(
                            fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
                            color: selected
                                ? AppColors.primary
                                : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                          ),
                        ),
                        subtitle: subtitle != null && subtitle.isNotEmpty ? Text(subtitle) : null,
                        trailing: selected ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                        onTap: () => Navigator.pop(context, e),
                      );
                    }),
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
