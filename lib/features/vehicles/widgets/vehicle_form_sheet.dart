import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../data/vehicle_models.dart';

class VehicleFormSheet extends StatefulWidget {
  final FleetVehicle? vehicle;
  final Future<void> Function(VehiclePayload payload) onSubmit;

  const VehicleFormSheet({super.key, this.vehicle, required this.onSubmit});

  @override
  State<VehicleFormSheet> createState() => _VehicleFormSheetState();
}

class _VehicleFormSheetState extends State<VehicleFormSheet> {
  final _formKey = GlobalKey<FormState>();
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
  DateTime? _lastServiceDate;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final vehicle = widget.vehicle;
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
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(
                children: [
                  Text(
                    widget.vehicle == null ? 'Add Vehicle' : 'Edit Vehicle',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(AppIcons.x),
                    onPressed: () => Navigator.pop(context),
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
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 18,
                      color: Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
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
                          textCapitalization: TextCapitalization.characters,
                          decoration: _decor('AP39...'),
                          validator: _required,
                        ),
                      ),
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
                                // auto-reset sub-fields so stale data is never submitted
                                _truckType = null;
                                _containerLength = null;
                                _axleType = null;
                                _containerBodyType = null;
                                _seatingCapacityCtrl.clear();
                                _formKey.currentState?.reset();
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
                              onChanged: (v) => setState(() => _status = v),
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
                      if (seatingCapacityRequiredTypes.contains(_type)) ...
                        [
                          const SizedBox(height: 14),
                          _Field(
                            label: 'Seating Capacity *',
                            child: TextFormField(
                              controller: _seatingCapacityCtrl,
                              keyboardType: TextInputType.number,
                              decoration: _decor('5'),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Required'
                                      : (int.tryParse(v.trim()) == null
                                            ? 'Enter a valid number'
                                            : null),
                            ),
                          ),
                        ]
                      else if (_type == 'TRUCK') ...
                        [
                          const SizedBox(height: 14),
                          _Picker(
                            label: 'Truck Type *',
                            value: _truckType ?? '',
                            values: const ['', ...truckTypes],
                            onChanged: (v) =>
                                setState(() => _truckType = v.isEmpty ? null : v),
                            labelGetter: (v) =>
                                v.isEmpty ? 'Select truck type' : truckTypeLabel(v),
                            validator: (_) =>
                                _truckType == null ? 'Required' : null,
                          ),
                        ]
                      else if (_type == 'CONTAINER') ...
                        [
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _Picker(
                                  label: 'Container Length *',
                                  value: _containerLength ?? '',
                                  values: const ['', ...containerLengths],
                                  onChanged: (v) => setState(
                                    () => _containerLength =
                                        v.isEmpty ? null : v,
                                  ),
                                  labelGetter: (v) => v.isEmpty
                                      ? 'Select length'
                                      : containerLengthLabel(v),
                                  validator: (_) =>
                                      _containerLength == null ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _Picker(
                                  label: 'Axle Type *',
                                  value: _axleType ?? '',
                                  values: const ['', ...axleTypes],
                                  onChanged: (v) => setState(
                                    () =>
                                        _axleType = v.isEmpty ? null : v,
                                  ),
                                  labelGetter: (v) =>
                                      v.isEmpty ? 'Select axle' : axleTypeLabel(v),
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
                              () => _containerBodyType = v.isEmpty ? null : v,
                            ),
                            labelGetter: (v) =>
                                v.isEmpty ? 'Select body type' : containerBodyTypeLabel(v),
                            validator: (_) =>
                                _containerBodyType == null ? 'Required' : null,
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
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  AppIcons.calendar,
                                  size: 16,
                                  color: AppColors.textMuted,
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
                                        ? AppColors.textMuted
                                        : AppColors.textPrimary,
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
  String? _emptyToNull(String value) =>
      value.trim().isEmpty ? null : value.trim();
  InputDecoration _decor(String hint) => InputDecoration(
    hintText: hint,
    isDense: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
  );
}

class _Field extends StatelessWidget {
  final String label;
  final Widget child;
  const _Field({required this.label, required this.child});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 6),
      child,
    ],
  );
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
    final tapper = InkWell(
      onTap: () => _show(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _label(value),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textMuted,
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
                  color: state.hasError ? AppColors.error : AppColors.border,
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
                          color: state.hasError
                              ? AppColors.error
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textMuted,
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
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: values
                    .map(
                      (v) => ListTile(
                        title: Text(_label(v)),
                        trailing: v == value
                            ? const Icon(Icons.check, color: AppColors.primary)
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
    );
  }
}
