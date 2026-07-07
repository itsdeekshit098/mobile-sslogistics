import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../data/vehicle_models.dart';
import '../data/vehicle_repository.dart';

class VehicleFormSheet extends StatefulWidget {
  final FleetVehicle? vehicle;
  final Future<void> Function(VehiclePayload payload) onSubmit;

  const VehicleFormSheet({super.key, this.vehicle, required this.onSubmit});

  @override
  State<VehicleFormSheet> createState() => _VehicleFormSheetState();
}

class _VehicleFormSheetState extends State<VehicleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _ownerRepo = VehicleRepository();
  late final TextEditingController _numberCtrl;
  late final TextEditingController _seatingCapacityCtrl;
  late final TextEditingController _companyCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _expectedKmlCtrl;
  late final TextEditingController _tankCtrl;
  String _type = vehicleTypes.first;
  String _status = vehicleStatuses.first;
  String _fuelType = fuelTypes.first;
  String? _truckType;
  String? _containerLength;
  String? _axleType;
  String? _containerBodyType;
  String? _ownerType;
  String? _ownerName;
  List<VehicleOwner> _owners = [];
  bool _loadingOwners = true;
  bool _ownersFailed = false;
  DateTime? _lastServiceDate;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final vehicle = widget.vehicle;
    _ownerType = vehicle?.ownerType;
    _ownerName = vehicle?.ownerName;
    _loadOwners();
    _numberCtrl = TextEditingController(text: vehicle?.vehicleNumber ?? '');
    _seatingCapacityCtrl = TextEditingController(
      text: vehicle?.seatingCapacity?.toString() ?? '',
    );
    _companyCtrl = TextEditingController(text: vehicle?.company ?? '');
    _modelCtrl = TextEditingController(text: vehicle?.model ?? '');
    _expectedKmlCtrl = TextEditingController(
      text: vehicle?.expectedKml?.toString() ?? '',
    );
    _tankCtrl = TextEditingController(
      text: vehicle?.tankCapacity?.toString() ?? '',
    );
    _type = vehicleTypes.contains(vehicle?.vehicleType)
        ? vehicle!.vehicleType
        : vehicleTypes.first;
    _status = vehicleStatuses.contains(vehicle?.status)
        ? vehicle!.status
        : vehicleStatuses.first;
    _fuelType = fuelTypes.contains(vehicle?.fuelType)
        ? vehicle!.fuelType!
        : fuelTypes.first;
    _truckType = vehicle?.truckType;
    _containerLength = vehicle?.containerLength;
    _axleType = vehicle?.axleType;
    _containerBodyType = vehicle?.containerBodyType;
    _lastServiceDate = vehicle?.lastServiceDate == null
        ? null
        : DateTime.tryParse(vehicle!.lastServiceDate!);
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _seatingCapacityCtrl.dispose();
    _companyCtrl.dispose();
    _modelCtrl.dispose();
    _expectedKmlCtrl.dispose();
    _tankCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOwners() async {
    setState(() {
      _loadingOwners = true;
      _ownersFailed = false;
    });
    try {
      final owners = await _ownerRepo.getOwners();
      if (mounted) setState(() => _owners = owners);
    } catch (_) {
      // Owner Name is required, so the form is unusable without this list —
      // surface the failure and offer a retry instead of a silently empty picker.
      if (mounted) setState(() => _ownersFailed = true);
    } finally {
      if (mounted) setState(() => _loadingOwners = false);
    }
  }

  /// Options for the Owner Name picker: owners of the selected type, plus the
  /// vehicle's current owner in edit mode even if it no longer exists in
  /// `vehicle_owners` (deleted/renamed on web) — otherwise the user could
  /// never re-select the original value after opening the picker.
  List<String> _ownerNameOptions() {
    final names = _owners
        .where((o) => o.ownerType == _ownerType)
        .map((o) => o.name)
        .toList();
    final current = widget.vehicle?.ownerName;
    if (current != null &&
        widget.vehicle?.ownerType == _ownerType &&
        !names.contains(current)) {
      names.insert(0, current);
    }
    return names;
  }

  Future<void> _addOwner() async {
    final created = await showModalBottomSheet<VehicleOwner>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _AddOwnerSheet(repo: _ownerRepo, defaultOwnerType: _ownerType),
    );
    if (created != null && mounted) {
      setState(() {
        // The backend may return an owner that already exists — don't
        // append a duplicate entry to the picker.
        if (!_owners.any(
          (o) => o.name == created.name && o.ownerType == created.ownerType,
        )) {
          _owners = [..._owners, created];
        }
        _ownerType = created.ownerType;
        _ownerName = created.name;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        VehiclePayload(
          id: widget.vehicle?.id,
          vehicleNumber: _numberCtrl.text,
          vehicleType: _type,
          seatingCapacity: int.tryParse(_seatingCapacityCtrl.text.trim()),
          company: _emptyToNull(_companyCtrl.text),
          model: _emptyToNull(_modelCtrl.text),
          status: _status,
          lastServiceDate: _lastServiceDate?.toIso8601String().split('T').first,
          expectedKml: double.tryParse(_expectedKmlCtrl.text),
          tankCapacity: double.tryParse(_tankCtrl.text),
          fuelType: _fuelType,
          truckType: _truckType,
          containerLength: _containerLength,
          axleType: _axleType,
          containerBodyType: _containerBodyType,
          ownerType: _ownerType!,
          ownerName: _ownerName!,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      // Blocks back button / barrier tap while the save request is in
      // flight, so the result (error banner or auto-close) isn't lost.
      canPop: !_saving,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCardBg : Colors.white,
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
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                child: Row(
                  children: [
                    Text(
                      widget.vehicle == null ? 'Add Vehicle' : 'Edit Vehicle',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(AppIcons.x),
                      onPressed: _saving ? null : () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (_error != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkErrorBg : AppColors.errorBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? AppColors.error.withOpacity(0.5)
                          : const Color(0xFFFCA5A5),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 18,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                // Locks every field while a save is in flight — matches the
                // already-blocked submit/close buttons, so nothing changes
                // underneath a request that already captured its payload.
                child: IgnorePointer(
                  ignoring: _saving,
                  child: Opacity(
                    opacity: _saving ? 0.5 : 1,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _Field(
                              label: 'Vehicle Number *',
                              child: TextFormField(
                                controller: _numberCtrl,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: _decor('AP39...'),
                                validator: _required,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _Picker(
                                    label: 'Owner Type *',
                                    value: _ownerType ?? '',
                                    values: const ['', ...ownerTypes],
                                    onChanged: (v) => setState(() {
                                      _ownerType = v.isEmpty ? null : v;
                                      _ownerName = null;
                                    }),
                                    labelGetter: (v) => v.isEmpty
                                        ? 'Select owner type'
                                        : ownerTypeLabel(v),
                                    validator: (_) =>
                                        _ownerType == null ? 'Required' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: IgnorePointer(
                                    ignoring:
                                        _ownerType == null ||
                                        _loadingOwners ||
                                        _ownersFailed,
                                    child: Opacity(
                                      opacity: _ownerType == null ? 0.5 : 1,
                                      child: _Picker(
                                        label: 'Owner Name *',
                                        value: _ownerName ?? '',
                                        values: ['', ..._ownerNameOptions()],
                                        onChanged: (v) => setState(
                                          () =>
                                              _ownerName = v.isEmpty ? null : v,
                                        ),
                                        labelGetter: (v) => v.isEmpty
                                            ? (_loadingOwners
                                                  ? 'Loading owners...'
                                                  : (_ownersFailed
                                                        ? 'Owners unavailable'
                                                        : (_ownerType == null
                                                              ? 'Select owner type first'
                                                              : 'Select owner')))
                                            : v,
                                        validator: (_) => _ownerName == null
                                            ? 'Required'
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_ownersFailed) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    size: 15,
                                    color: AppColors.error,
                                  ),
                                  const SizedBox(width: 5),
                                  const Expanded(
                                    child: Text(
                                      "Couldn't load owners.",
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.error,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _loadOwners,
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(0, 0),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Retry',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (_ownerType != null &&
                                !_loadingOwners) ...[
                              // Hidden while owners are loading/failed: without the
                              // list the user can't tell an owner already exists and
                              // would quick-add a duplicate.
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: _addOwner,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    '+ Add New Owner',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _Picker(
                                    label: 'Type *',
                                    value: _type,
                                    values: vehicleTypes,
                                    onChanged: (v) => setState(() {
                                      _type = v;
                                      // auto-reset sub-fields so stale data is never
                                      // submitted. No Form.reset() here: it would
                                      // restore every TextFormField to its (null)
                                      // initialValue, wiping text the user typed.
                                      // Stale validation errors on sub-fields vanish
                                      // anyway because those widgets leave the tree.
                                      _truckType = null;
                                      _containerLength = null;
                                      _axleType = null;
                                      _containerBodyType = null;
                                      _seatingCapacityCtrl.clear();
                                    }),
                                    labelGetter: vehicleTypeLabel,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _Picker(
                                    label: 'Status',
                                    value: _status,
                                    values: vehicleStatuses,
                                    onChanged: (v) =>
                                        setState(() => _status = v),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _Field(
                                    label: 'Company',
                                    child: TextFormField(
                                      controller: _companyCtrl,
                                      decoration: _decor('Tata'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _Field(
                                    label: 'Model',
                                    child: TextFormField(
                                      controller: _modelCtrl,
                                      decoration: _decor('407'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _Picker(
                              label: 'Fuel',
                              value: _fuelType,
                              values: fuelTypes,
                              onChanged: (v) => setState(() => _fuelType = v),
                              labelGetter: fuelTypeLabel,
                            ),
                            // Type-specific fields
                            if (seatingCapacityRequiredTypes.contains(
                              _type,
                            )) ...[
                              const SizedBox(height: 14),
                              _Field(
                                label: 'Seating Capacity *',
                                child: TextFormField(
                                  controller: _seatingCapacityCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: _decor('5'),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Required';
                                    }
                                    final parsed = int.tryParse(v.trim());
                                    if (parsed == null || parsed <= 0) {
                                      return 'Enter a valid number';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ] else if (_type == 'TRUCK') ...[
                              const SizedBox(height: 14),
                              _Picker(
                                label: 'Truck Type *',
                                value: _truckType ?? '',
                                values: const ['', ...truckTypes],
                                onChanged: (v) => setState(
                                  () => _truckType = v.isEmpty ? null : v,
                                ),
                                labelGetter: (v) => v.isEmpty
                                    ? 'Select truck type'
                                    : truckTypeLabel(v),
                                validator: (_) =>
                                    _truckType == null ? 'Required' : null,
                              ),
                            ] else if (_type == 'CONTAINER') ...[
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: _Picker(
                                      label: 'Container Length *',
                                      value: _containerLength ?? '',
                                      values: const ['', ...containerLengths],
                                      onChanged: (v) => setState(
                                        () => _containerLength = v.isEmpty
                                            ? null
                                            : v,
                                      ),
                                      labelGetter: (v) => v.isEmpty
                                          ? 'Select length'
                                          : containerLengthLabel(v),
                                      validator: (_) => _containerLength == null
                                          ? 'Required'
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _Picker(
                                      label: 'Axle Type *',
                                      value: _axleType ?? '',
                                      values: const ['', ...axleTypes],
                                      onChanged: (v) => setState(
                                        () => _axleType = v.isEmpty ? null : v,
                                      ),
                                      labelGetter: (v) => v.isEmpty
                                          ? 'Select axle'
                                          : axleTypeLabel(v),
                                      validator: (_) =>
                                          _axleType == null ? 'Required' : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _Picker(
                                label: 'Body Type *',
                                value: _containerBodyType ?? '',
                                values: const ['', ...containerBodyTypes],
                                onChanged: (v) => setState(
                                  () =>
                                      _containerBodyType = v.isEmpty ? null : v,
                                ),
                                labelGetter: (v) => v.isEmpty
                                    ? 'Select body type'
                                    : containerBodyTypeLabel(v),
                                validator: (_) => _containerBodyType == null
                                    ? 'Required'
                                    : null,
                              ),
                            ],
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _Field(
                                    label: 'Expected KML',
                                    child: TextFormField(
                                      controller: _expectedKmlCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: _decor('8.5'),
                                      validator: _optionalPositiveNumber,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _Field(
                                    label: 'Tank (L)',
                                    child: TextFormField(
                                      controller: _tankCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: _decor('120'),
                                      validator: _optionalPositiveNumber,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _Field(
                              label: 'Last Service Date',
                              child: InkWell(
                                onTap: _pickDate,
                                child: Container(
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isDark
                                          ? AppColors.darkBorder
                                          : AppColors.border,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        AppIcons.calendar,
                                        size: 16,
                                        color: isDark
                                            ? AppColors.darkTextMuted
                                            : AppColors.textMuted,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _lastServiceDate == null
                                            ? 'Select date'
                                            : _lastServiceDate!
                                                  .toIso8601String()
                                                  .split('T')
                                                  .first,
                                        style: TextStyle(
                                          color: _lastServiceDate == null
                                              ? (isDark
                                                    ? AppColors.darkTextMuted
                                                    : AppColors.textMuted)
                                              : (isDark
                                                    ? AppColors.darkTextPrimary
                                                    : AppColors.textPrimary),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  12 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            widget.vehicle == null
                                ? 'Add Vehicle'
                                : 'Save Changes',
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastServiceDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _lastServiceDate = picked);
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  /// Optional field, but anything typed must be a positive number —
  /// otherwise `double.tryParse` in `_submit` would silently drop it.
  String? _optionalPositiveNumber(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = double.tryParse(value.trim());
    if (parsed == null || parsed <= 0) return 'Enter a valid number';
    return null;
  }

  String? _emptyToNull(String value) =>
      value.trim().isEmpty ? null : value.trim();
  InputDecoration _decor(String hint) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    return InputDecoration(
      hintText: hint,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final Widget child;
  const _Field({required this.label, required this.child});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
    );
    final isRequired = label.endsWith(' *');
    final baseLabel = isRequired ? label.substring(0, label.length - 2) : label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: labelStyle,
            children: [
              TextSpan(text: baseLabel),
              if (isRequired)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: AppColors.error),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _Picker extends StatelessWidget {
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;
  final String Function(String)? labelGetter;
  final String? Function(String?)? validator;

  const _Picker({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
    this.labelGetter,
    this.validator,
  });

  String _label(String v) => labelGetter != null ? labelGetter!(v) : v;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.textMuted;
    final tapper = InkWell(
      onTap: () => _show(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _label(value),
                style: TextStyle(fontWeight: FontWeight.w700, color: textColor),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: mutedColor,
            ),
          ],
        ),
      ),
    );

    if (validator == null) {
      return _Field(label: label, child: tapper);
    }

    return _Field(
      label: label,
      child: FormField<String>(
        initialValue: value,
        validator: validator,
        builder: (state) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: state.hasError ? AppColors.error : borderColor,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: InkWell(
                onTap: () => _show(context),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _label(value),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: state.hasError ? AppColors.error : textColor,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: mutedColor,
                    ),
                  ],
                ),
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 12),
                child: Text(
                  state.errorText!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _show(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCardBg : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: values
                      .map(
                        (v) => ListTile(
                          title: Text(
                            _label(v),
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.textPrimary,
                            ),
                          ),
                          trailing: v == value
                              ? const Icon(
                                  Icons.check,
                                  color: AppColors.primary,
                                )
                              : null,
                          onTap: () {
                            Navigator.pop(context);
                            onChanged(v);
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Quick-add bottom sheet for creating a new [VehicleOwner] from within the
/// vehicle form — mirrors the "+ Add New Owner" flow on the web admin app.
class _AddOwnerSheet extends StatefulWidget {
  final VehicleRepository repo;
  final String? defaultOwnerType;

  const _AddOwnerSheet({required this.repo, this.defaultOwnerType});

  @override
  State<_AddOwnerSheet> createState() => _AddOwnerSheetState();
}

class _AddOwnerSheetState extends State<_AddOwnerSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  String? _ownerType;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _ownerType = widget.defaultOwnerType;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final owner = await widget.repo.createOwner(
        name: _nameCtrl.text,
        ownerType: _ownerType!,
      );
      if (mounted) Navigator.pop(context, owner);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCardBg : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBorder : AppColors.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  Text(
                    'Add New Owner',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  IgnorePointer(
                    ignoring: _saving,
                    child: Opacity(
                      opacity: _saving ? 0.5 : 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Picker(
                            label: 'Owner Type *',
                            value: _ownerType ?? '',
                            values: const ['', ...ownerTypes],
                            onChanged: (v) => setState(
                              () => _ownerType = v.isEmpty ? null : v,
                            ),
                            labelGetter: (v) => v.isEmpty
                                ? 'Select owner type'
                                : ownerTypeLabel(v),
                            validator: (_) =>
                                _ownerType == null ? 'Required' : null,
                          ),
                          const SizedBox(height: 14),
                          _Field(
                            label: 'Owner Name *',
                            child: TextFormField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(
                                hintText:
                                    'e.g. My Proprietorship / ABC Logistics',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save Owner'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
