import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../shared/models/vehicle_model.dart';
import '../../../shared/utils/validated_field.dart';
import '../../../shared/widgets/form_error_banner.dart';
import '../../../shared/widgets/server_error_banner.dart';
import '../../diesel/providers/vehicle_provider.dart';
import '../../repairs/data/repair_models.dart';
import '../../repairs/providers/repair_provider.dart';
import '../data/warranty_models.dart';

final _dateFmt = DateFormat('dd MMM yyyy');
final _isoFmt = DateFormat('yyyy-MM-dd');

/// Create + edit in one sheet. Vehicle is locked once a part is linked to a
/// repair record — the backend rejects reassigning it in that case.
class WarrantyFormSheet extends ConsumerStatefulWidget {
  final WarrantyItem? item;
  final Future<void> Function(WarrantyDto dto) onSubmit;

  const WarrantyFormSheet({super.key, this.item, required this.onSubmit});

  @override
  ConsumerState<WarrantyFormSheet> createState() => _WarrantyFormSheetState();
}

class _WarrantyFormSheetState extends ConsumerState<WarrantyFormSheet> {
  Vehicle? _vehicle;
  Vendor? _vendor;
  String _partName = '';
  DateTime? _purchaseDate;
  String _unit = warrantyUnitMonths;
  bool _seeded = false;

  final _costCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  final _vehicleKey = GlobalKey();
  final _partNameKey = GlobalKey();
  final _vendorKey = GlobalKey();
  final _dateKey = GlobalKey();
  final _costFieldKey = GlobalKey<FormFieldState>();
  final _costFocus = FocusNode();
  final _durationFieldKey = GlobalKey<FormFieldState>();
  final _durationFocus = FocusNode();

  bool _isSubmitting = false;
  int _errorCount = 0;
  // Shown as a banner inside the sheet rather than a SnackBar — a SnackBar
  // anchors to the screen underneath and renders hidden behind this modal
  // bottom sheet, so the user never sees it even though it technically fired.
  String? _serverError;

  bool get _isEdit => widget.item != null;
  bool get _vehicleLocked => widget.item?.isLinkedToRepair ?? false;

  List<ValidatedField> get _validatedFields => [
        ValidatedField(key: _vehicleKey, hasError: () => _vehicle == null),
        ValidatedField(key: _partNameKey, hasError: () => _partName.isEmpty),
        ValidatedField(key: _vendorKey, hasError: () => _vendor == null),
        ValidatedField(
          key: _costFieldKey,
          hasError: () => _costFieldKey.currentState?.hasError ?? false,
          focusNode: _costFocus,
        ),
        ValidatedField(key: _dateKey, hasError: () => _purchaseDate == null),
        ValidatedField(
          key: _durationFieldKey,
          hasError: () => _durationFieldKey.currentState?.hasError ?? false,
          focusNode: _durationFocus,
        ),
      ];

  @override
  void dispose() {
    _costCtrl.dispose();
    _durationCtrl.dispose();
    _notesCtrl.dispose();
    _costFocus.dispose();
    _durationFocus.dispose();
    super.dispose();
  }

  void _seedFromExisting(List<Vehicle> vehicles, List<Vendor> vendors) {
    if (_seeded || widget.item == null) return;
    _seeded = true;
    final item = widget.item!;
    _partName = item.partName;
    _costCtrl.text = _trimZeros(item.cost);
    _purchaseDate = DateTime.tryParse(item.purchaseDate);
    _durationCtrl.text = item.warrantyDuration.toString();
    _unit = item.warrantyDurationUnit;
    _notesCtrl.text = item.notes ?? '';
    try {
      _vehicle = vehicles.firstWhere((v) => v.id == item.vehicleId);
    } catch (_) {
      _vehicle = item.vehicle != null
          ? Vehicle(id: item.vehicle!.id, plateNumber: item.vehicle!.vehicleNumber, model: item.vehicle!.model)
          : null;
    }
    if (item.vendorId != null) {
      try {
        _vendor = vendors.firstWhere((v) => v.id == item.vendorId);
      } catch (_) {
        _vendor = item.vendor != null
            ? Vendor(id: item.vendor!.id, name: item.vendor!.name, phone: item.vendor!.phone, location: item.vendor!.location)
            : null;
      }
    }
  }

  DateTime? get _expiryPreview {
    if (_purchaseDate == null) return null;
    final n = int.tryParse(_durationCtrl.text);
    if (n == null || n <= 0) return null;
    return _unit == warrantyUnitYears
        ? DateTime(_purchaseDate!.year + n, _purchaseDate!.month, _purchaseDate!.day)
        : DateTime(_purchaseDate!.year, _purchaseDate!.month + n, _purchaseDate!.day);
  }

  Future<void> _pickVehicle(List<Vehicle> vehicles) async {
    if (_vehicleLocked) return;
    final picked = await showModalBottomSheet<Vehicle>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VehiclePickerSheet(vehicles: vehicles, selected: _vehicle),
    );
    if (picked != null) setState(() => _vehicle = picked);
  }

  Future<void> _pickPartName(List<PartOption> options) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SearchAddSheet(
        title: 'Select part',
        options: options.map((p) => p.name).toList(),
        selected: _partName.isEmpty ? null : _partName,
        onAddNew: (name) async {
          final result = await ref.read(repairRepositoryProvider).addPartOption(name);
          ref.invalidate(partOptionsProvider);
          return result?.name ?? name;
        },
      ),
    );
    if (picked != null) setState(() => _partName = picked);
  }

  Future<void> _pickVendor(List<Vendor> vendors) async {
    final picked = await showModalBottomSheet<Vendor>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VendorPickerSheet(
        vendors: vendors,
        selected: _vendor,
        onAddNew: () => _showAddVendorDialog(),
      ),
    );
    if (picked != null) setState(() => _vendor = picked);
  }

  Future<Vendor?> _showAddVendorDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Declared outside the StatefulBuilder's builder callback — that
    // callback re-runs on every setDialogState, so locals declared inside
    // it would reset to their initial value on each rebuild instead of
    // persisting across them.
    var adding = false;
    String? error;

    return showDialog<Vendor>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkCardBg : Colors.white,
            title: const Text('Add Vendor'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name *')),
                const SizedBox(height: 8),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
                const SizedBox(height: 8),
                TextField(controller: locationCtrl, decoration: const InputDecoration(labelText: 'Location')),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: adding
                    ? null
                    : () async {
                        if (nameCtrl.text.trim().isEmpty) {
                          setDialogState(() => error = 'Name is required');
                          return;
                        }
                        setDialogState(() => adding = true);
                        try {
                          final vendor = await ref.read(repairRepositoryProvider).addVendor(
                                name: nameCtrl.text.trim(),
                                phone: phoneCtrl.text.trim(),
                                location: locationCtrl.text.trim(),
                              );
                          ref.invalidate(vendorsProvider);
                          if (dialogContext.mounted) Navigator.pop(dialogContext, vendor);
                        } catch (e) {
                          setDialogState(() {
                            adding = false;
                            error = e.toString().replaceFirst('Exception: ', '');
                          });
                        }
                      },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _purchaseDate = picked);
  }

  Future<void> _submit() async {
    final fields = _validatedFields;
    final errorCount = countFormErrors(fields);
    if (errorCount > 0) {
      setState(() => _errorCount = errorCount);
      await scrollToFirstError(fields);
      return;
    }
    setState(() {
      _errorCount = 0;
      _serverError = null;
      _isSubmitting = true;
    });

    try {
      final dto = WarrantyDto(
        id: widget.item?.id,
        vehicleId: _vehicle!.id,
        partName: _partName,
        vendorId: _vendor!.id,
        cost: double.parse(_costCtrl.text),
        purchaseDate: _isoFmt.format(_purchaseDate!),
        warrantyDuration: int.parse(_durationCtrl.text),
        warrantyDurationUnit: _unit,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        repairRecordId: widget.item?.repairRecordId,
      );
      await widget.onSubmit(dto);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _serverError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final vendorsAsync = ref.watch(vendorsProvider);
    final partOptionsAsync = ref.watch(partOptionsProvider);
    final expiry = _expiryPreview;

    return Material(
      color: isDark ? AppColors.darkCardBg : Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Text(
                  _isEdit ? 'Edit Warranty' : 'Add Warranty',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(icon: const Icon(AppIcons.x, size: 20), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_errorCount > 0) FormErrorBanner(count: _errorCount),
          if (_serverError != null) ServerErrorBanner(message: _serverError!),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Section(
                    key: _vehicleKey,
                    label: 'Vehicle *',
                    child: vehiclesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => Text('Error loading vehicles', style: TextStyle(color: AppColors.error)),
                      data: (vehicles) {
                        _seedFromExisting(vehicles, vendorsAsync.valueOrNull ?? const []);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _TapField(
                              value: _vehicle?.plateNumber ?? 'Select vehicle',
                              icon: AppIcons.truck,
                              muted: _vehicle == null,
                              disabled: _vehicleLocked,
                              onTap: () => _pickVehicle(vehicles),
                            ),
                            if (_vehicleLocked)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Locked — this part is linked to a repair record.',
                                  style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Section(
                    key: _partNameKey,
                    label: 'Part Name *',
                    child: partOptionsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => Text('Error loading parts', style: TextStyle(color: AppColors.error)),
                      data: (options) => _TapField(
                        value: _partName.isEmpty ? 'Select part' : _partName,
                        icon: AppIcons.wrench,
                        muted: _partName.isEmpty,
                        onTap: () => _pickPartName(options),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Section(
                    key: _vendorKey,
                    label: 'Vendor *',
                    child: vendorsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => Text('Error loading vendors', style: TextStyle(color: AppColors.error)),
                      data: (vendors) => _TapField(
                        value: _vendor?.name ?? 'Select vendor',
                        icon: Icons.storefront_outlined,
                        muted: _vendor == null,
                        onTap: () => _pickVendor(vendors),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _Section(
                          label: 'Cost (₹) *',
                          child: TextFormField(
                            key: _costFieldKey,
                            controller: _costCtrl,
                            focusNode: _costFocus,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _inputDecor(context, hint: 'e.g. 2500'),
                            onChanged: (_) => setState(() {}),
                            validator: (v) {
                              final n = double.tryParse(v ?? '');
                              if (n == null || n < 0) return 'Required';
                              return null;
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Section(
                          key: _dateKey,
                          label: 'Purchase Date *',
                          child: _TapField(
                            value: _purchaseDate != null ? _dateFmt.format(_purchaseDate!) : 'Select date',
                            icon: AppIcons.calendar,
                            muted: _purchaseDate == null,
                            onTap: _pickDate,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _Section(
                          label: 'Warranty Duration *',
                          child: TextFormField(
                            key: _durationFieldKey,
                            controller: _durationCtrl,
                            focusNode: _durationFocus,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecor(context, hint: 'e.g. 12'),
                            onChanged: (_) => setState(() {}),
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              if (n == null || n <= 0) return 'Required';
                              return null;
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _Section(
                          label: 'Unit',
                          child: Row(
                            children: [warrantyUnitMonths, warrantyUnitYears].map((u) {
                              final selected = _unit == u;
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(right: u == warrantyUnitMonths ? 8 : 0),
                                  child: InkWell(
                                    onTap: () => setState(() => _unit = u),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? AppColors.primary
                                            : (isDark ? AppColors.darkCardBg : Colors.white),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: selected
                                              ? AppColors.primary
                                              : (isDark ? AppColors.darkBorder : AppColors.border),
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          u == warrantyUnitMonths ? 'Months' : 'Years',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: selected
                                                ? Colors.white
                                                : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (expiry != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.event_available_outlined, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          'Expires ${_dateFmt.format(expiry)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  _Section(
                    label: 'Notes',
                    child: TextFormField(
                      controller: _notesCtrl,
                      maxLines: 2,
                      decoration: _inputDecor(context, hint: 'Additional notes...'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).viewInsets.bottom),
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : Text(_isEdit ? 'Save Changes' : 'Add Warranty'),
            ),
          ),
        ],
      ),
    );
  }
}

String _trimZeros(double value) => value == value.roundToDouble() ? value.toInt().toString() : '$value';

class _Section extends StatelessWidget {
  final String label;
  final Widget child;
  const _Section({super.key, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRequired = label.endsWith(' *');
    final baseLabel = isRequired ? label.substring(0, label.length - 2) : label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
            children: [
              TextSpan(text: baseLabel),
              if (isRequired) const TextSpan(text: ' *', style: TextStyle(color: AppColors.error)),
            ],
          ),
        ),
        const SizedBox(height: 5),
        child,
      ],
    );
  }
}

class _TapField extends StatelessWidget {
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final bool muted;
  final bool disabled;

  const _TapField({
    required this.value,
    required this.icon,
    required this.onTap,
    this.muted = false,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.textMuted;
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Opacity(
        opacity: disabled ? 0.6 : 1,
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
              if (disabled)
                Icon(AppIcons.lock, size: 14, color: mutedColor)
              else
                Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: mutedColor),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _inputDecor(BuildContext context, {String? hint}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
  return InputDecoration(
    hintText: hint,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    isDense: true,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
    enabledBorder:
        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
  );
}

class _VehiclePickerSheet extends StatefulWidget {
  final List<Vehicle> vehicles;
  final Vehicle? selected;

  const _VehiclePickerSheet({required this.vehicles, this.selected});

  @override
  State<_VehiclePickerSheet> createState() => _VehiclePickerSheetState();
}

class _VehiclePickerSheetState extends State<_VehiclePickerSheet> {
  String _query = '';

  List<Vehicle> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.vehicles;
    return widget.vehicles
        .where((v) => [v.plateNumber, v.make, v.model].whereType<String>().join(' ').toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filtered;
    return _PickerShell(
      title: 'Select vehicle',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: _searchDecor(context, 'Search vehicle number, make, model'),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 340),
            child: filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text('No vehicles found', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final v = filtered[i];
                      final selected = widget.selected?.id == v.id;
                      return ListTile(
                        title: Text(v.plateNumber, style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
                        subtitle: [v.make, v.model].whereType<String>().join(' ').isEmpty
                            ? null
                            : Text([v.make, v.model].whereType<String>().join(' ')),
                        trailing: selected ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                        onTap: () => Navigator.pop(context, v),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _VendorPickerSheet extends StatefulWidget {
  final List<Vendor> vendors;
  final Vendor? selected;
  final Future<Vendor?> Function() onAddNew;

  const _VendorPickerSheet({required this.vendors, this.selected, required this.onAddNew});

  @override
  State<_VendorPickerSheet> createState() => _VendorPickerSheetState();
}

class _VendorPickerSheetState extends State<_VendorPickerSheet> {
  String _query = '';

  List<Vendor> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.vendors;
    return widget.vendors
        .where((v) => [v.name, v.location].whereType<String>().join(' ').toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filtered;
    return _PickerShell(
      title: 'Select vendor',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: _searchDecor(context, 'Search vendor name, location'),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text('No vendors found', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final v = filtered[i];
                      final selected = widget.selected?.id == v.id;
                      return ListTile(
                        title: Text(v.name, style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
                        subtitle: v.location != null ? Text(v.location!) : null,
                        trailing: selected ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                        onTap: () => Navigator.pop(context, v),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final vendor = await widget.onAddNew();
                  if (vendor != null && context.mounted) Navigator.pop(context, vendor);
                },
                icon: const Icon(AppIcons.plus, size: 16),
                label: const Text('Add new vendor'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Searchable picker with an inline "Add" action for options that don't
/// exist yet (used for part names).
class _SearchAddSheet extends StatefulWidget {
  final String title;
  final List<String> options;
  final String? selected;
  final Future<String> Function(String name) onAddNew;

  const _SearchAddSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.onAddNew,
  });

  @override
  State<_SearchAddSheet> createState() => _SearchAddSheetState();
}

class _SearchAddSheetState extends State<_SearchAddSheet> {
  String _query = '';
  bool _adding = false;
  // Shown as a banner inside the sheet rather than a SnackBar — a SnackBar
  // anchors to the screen underneath and renders hidden behind this modal
  // bottom sheet, so the user never sees it even though it technically fired.
  String? _serverError;

  List<String> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.options;
    return widget.options.where((o) => o.toLowerCase().contains(q)).toList();
  }

  bool get _hasExactMatch => widget.options.any((o) => o.toLowerCase() == _query.trim().toLowerCase());

  Future<void> _addNew() async {
    setState(() {
      _adding = true;
      _serverError = null;
    });
    try {
      final name = await widget.onAddNew(_query.trim());
      if (mounted) Navigator.pop(context, name);
    } catch (e) {
      if (mounted) {
        setState(() {
          _adding = false;
          _serverError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filtered;
    return _PickerShell(
      title: widget.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_serverError != null) ServerErrorBanner(message: _serverError!),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: _searchDecor(context, 'Search or type a new name'),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text('No matches', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final o = filtered[i];
                      final selected = widget.selected == o;
                      return ListTile(
                        dense: true,
                        title: Text(o, style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w400)),
                        trailing: selected ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                        onTap: () => Navigator.pop(context, o),
                      );
                    },
                  ),
          ),
          if (_query.trim().isNotEmpty && !_hasExactMatch)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _adding ? null : _addNew,
                  icon: _adding
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(AppIcons.plus, size: 16),
                  label: Text('Add "${_query.trim()}"'),
                ),
              ),
            )
          else
            const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _PickerShell extends StatelessWidget {
  final String title;
  final Widget child;

  const _PickerShell({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(AppIcons.x, size: 20)),
                  ],
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _searchDecor(BuildContext context, String hint) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
  return InputDecoration(
    hintText: hint,
    prefixIcon: const Icon(Icons.search_rounded, size: 20),
    isDense: true,
    filled: true,
    fillColor: isDark ? AppColors.darkPageBg : AppColors.pageBg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
    enabledBorder:
        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
    ),
  );
}
