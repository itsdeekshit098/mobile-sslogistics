import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../shared/models/vehicle_model.dart';
import '../../../shared/utils/money_format.dart';
import '../../../shared/widgets/option_picker_sheet.dart';
import '../../../shared/widgets/search_picker_sheet.dart';
import '../../../shared/widgets/server_error_banner.dart';
import '../../../shared/widgets/tap_field.dart';
import '../../diesel/providers/vehicle_provider.dart';
import '../data/client_models.dart';

enum _Mode { linked, declared }

/// Records a vehicle running for a client — either linked to a real fleet
/// vehicle (its spec is copied over server-side) or declared as a count of a
/// type not tracked individually, e.g. "4 × Bus, 43-seater".
class DeploymentFormSheet extends ConsumerStatefulWidget {
  final ClientDeployment? deployment;
  final Future<void> Function({
    int? id,
    int? vehicleId,
    required int quantity,
    String? vehicleType,
    int? seatingCapacity,
    String? truckType,
    String? containerLength,
    String? axleType,
    String? containerBodyType,
    num? monthlyRate,
    String? startDate,
    String? endDate,
  }) onSubmit;

  const DeploymentFormSheet({super.key, this.deployment, required this.onSubmit});

  @override
  ConsumerState<DeploymentFormSheet> createState() => _DeploymentFormSheetState();
}

class _DeploymentFormSheetState extends ConsumerState<DeploymentFormSheet> {
  late _Mode _mode;
  Vehicle? _vehicle;
  String? _vehicleType;
  String? _truckType;
  String? _containerLength;
  String? _axleType;
  String? _containerBodyType;

  final _quantityCtrl = TextEditingController(text: '1');
  final _seatingCtrl = TextEditingController();
  final _monthlyRateCtrl = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;

  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.deployment != null;
  bool get _needsSeating => kSeatingCapacityTypes.contains(_vehicleType);
  bool get _isTruck => _vehicleType == 'TRUCK';
  bool get _isContainer => _vehicleType == 'CONTAINER';

  @override
  void initState() {
    super.initState();
    final d = widget.deployment;
    _mode = d?.vehicleId != null ? _Mode.linked : _Mode.declared;
    if (d != null) {
      _quantityCtrl.text = '${d.quantity}';
      _vehicleType = d.vehicleType;
      _seatingCtrl.text = d.seatingCapacity?.toString() ?? '';
      _truckType = d.truckType;
      _containerLength = d.containerLength;
      _axleType = d.axleType;
      _containerBodyType = d.containerBodyType;
      _monthlyRateCtrl.text = d.monthlyRate?.toString() ?? '';
      _startDate = d.startDate != null ? DateTime.tryParse(d.startDate!) : null;
      _endDate = d.endDate != null ? DateTime.tryParse(d.endDate!) : null;
      if (d.vehicleId != null) _loadVehicle(d.vehicleId!);
    }
  }

  /// Editing a fleet-linked deployment never prefilled `_vehicle` — the
  /// Vehicle field showed the placeholder even though `_mode` was correctly
  /// `linked`, and saving without re-picking the same vehicle was blocked by
  /// the `_vehicle == null` check in `_submit`.
  Future<void> _loadVehicle(int vehicleId) async {
    final vehicles = await ref.read(vehiclesProvider.future);
    if (!mounted) return;
    final match = vehicles.where((v) => v.id == vehicleId);
    if (match.isNotEmpty) setState(() => _vehicle = match.first);
  }

  @override
  void dispose() {
    _quantityCtrl.dispose();
    _seatingCtrl.dispose();
    _monthlyRateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickVehicle() async {
    final vehicles = await ref.read(vehiclesProvider.future);
    if (!mounted) return;
    final result = await showSearchPicker<Vehicle>(
      context,
      title: 'Select vehicle',
      icon: AppIcons.truck,
      items: vehicles,
      selected: _vehicle,
      searchHint: 'Search vehicles...',
      labelBuilder: (v) => v.plateNumber,
      subtitleBuilder: (v) => v.model ?? '',
      matcher: (v, q) =>
          v.plateNumber.toLowerCase().contains(q) || (v.model?.toLowerCase().contains(q) ?? false),
    );
    if (!mounted || result == null || result is ClearPick) return;
    setState(() {
      _vehicle = result as Vehicle;
      _error = null;
    });
  }

  Future<void> _pickVehicleType() async {
    final result = await showOptionPicker<Map<String, String>>(
      context,
      title: 'Vehicle Type',
      options: kVehicleTypes,
      selected: findOption(kVehicleTypes, _vehicleType),
      labelBuilder: (o) => o['label']!,
    );
    if (result != null) setState(() => _vehicleType = result['value']);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? now,
      firstDate: DateTime(2015),
      lastDate: DateTime(now.year + 5, 12, 31),
    );
    if (picked != null) {
      setState(() => isStart ? _startDate = picked : _endDate = picked);
    }
  }

  Future<void> _submit() async {
    if (_mode == _Mode.linked && _vehicle == null) {
      setState(() => _error = 'Choose a vehicle');
      return;
    }
    if (_mode == _Mode.declared) {
      if (_vehicleType == null) {
        setState(() => _error = 'Choose a vehicle type');
        return;
      }
      if (_isTruck && _truckType == null) {
        setState(() => _error = 'Choose a truck type');
        return;
      }
      if (_isContainer && (_containerLength == null || _axleType == null || _containerBodyType == null)) {
        setState(() => _error = 'Container length, axle type and body type are all required');
        return;
      }
      final qty = int.tryParse(_quantityCtrl.text);
      if (qty == null || qty < 1) {
        setState(() => _error = 'Quantity must be at least 1');
        return;
      }
    }
    if (_monthlyRateCtrl.text.isNotEmpty) {
      final rate = num.tryParse(_monthlyRateCtrl.text);
      if (rate == null || rate < 0) {
        setState(() => _error = 'Monthly rate cannot be negative');
        return;
      }
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await widget.onSubmit(
        id: widget.deployment?.id,
        vehicleId: _mode == _Mode.linked ? _vehicle!.id : null,
        quantity: _mode == _Mode.linked ? 1 : (int.tryParse(_quantityCtrl.text) ?? 1),
        vehicleType: _mode == _Mode.declared ? _vehicleType : null,
        seatingCapacity: _mode == _Mode.declared && _needsSeating && _seatingCtrl.text.isNotEmpty
            ? int.tryParse(_seatingCtrl.text)
            : null,
        truckType: _mode == _Mode.declared && _isTruck ? _truckType : null,
        containerLength: _mode == _Mode.declared && _isContainer ? _containerLength : null,
        axleType: _mode == _Mode.declared && _isContainer ? _axleType : null,
        containerBodyType: _mode == _Mode.declared && _isContainer ? _containerBodyType : null,
        monthlyRate: num.tryParse(_monthlyRateCtrl.text),
        startDate: _startDate != null ? formatApiDate(_startDate!) : null,
        endDate: _endDate != null ? formatApiDate(_endDate!) : null,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? AppColors.darkCardBg : Colors.white,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEdit ? 'Edit Vehicle' : 'Add Vehicle',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(AppIcons.x)),
                ],
              ),
            ),
            const Divider(height: 1),
            if (_error != null) ServerErrorBanner(message: _error!),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _ModeButton(
                            label: 'Pick from fleet',
                            selected: _mode == _Mode.linked,
                            onTap: () => setState(() => _mode = _Mode.linked),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ModeButton(
                            label: 'Describe by type',
                            selected: _mode == _Mode.declared,
                            onTap: () => setState(() => _mode = _Mode.declared),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_mode == _Mode.linked)
                      FormSection(
                        label: 'Vehicle *',
                        child: TapField(
                          value: _vehicle?.plateNumber ?? 'Select vehicle',
                          icon: AppIcons.truck,
                          muted: _vehicle == null,
                          onTap: _pickVehicle,
                        ),
                      )
                    else ...[
                      FormSection(
                        label: 'Vehicle Type *',
                        child: TapField(
                          value: _vehicleType != null ? vehicleTypeLabel(_vehicleType!) : 'Select type',
                          icon: AppIcons.truck,
                          muted: _vehicleType == null,
                          onTap: _pickVehicleType,
                        ),
                      ),
                      const SizedBox(height: 14),
                      FormSection(
                        label: 'How Many *',
                        child: TextField(controller: _quantityCtrl, keyboardType: TextInputType.number),
                      ),
                      if (_needsSeating) ...[
                        const SizedBox(height: 14),
                        FormSection(
                          label: 'Seating Capacity',
                          child: TextField(
                            controller: _seatingCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(hintText: 'e.g. 43'),
                          ),
                        ),
                      ],
                      if (_isTruck) ...[
                        const SizedBox(height: 14),
                        FormSection(
                          label: 'Truck Type *',
                          child: TapField(
                            value: truckTypeLabel(_truckType).isEmpty ? 'Select truck type' : truckTypeLabel(_truckType),
                            icon: AppIcons.truck,
                            muted: _truckType == null,
                            onTap: () async {
                              final result = await showOptionPicker<Map<String, String>>(
                                context,
                                title: 'Truck Type',
                                options: kTruckTypes,
                                selected: findOption(kTruckTypes, _truckType),
                                labelBuilder: (o) => o['label']!,
                              );
                              if (result != null) setState(() => _truckType = result['value']);
                            },
                          ),
                        ),
                      ],
                      if (_isContainer) ...[
                        const SizedBox(height: 14),
                        FormSection(
                          label: 'Length *',
                          child: TapField(
                            value: containerLengthLabel(_containerLength).isEmpty
                                ? 'Select length'
                                : containerLengthLabel(_containerLength),
                            icon: AppIcons.truck,
                            muted: _containerLength == null,
                            onTap: () async {
                              final result = await showOptionPicker<Map<String, String>>(
                                context,
                                title: 'Container Length',
                                options: kContainerLengths,
                                selected:
                                    findOption(kContainerLengths, _containerLength),
                                labelBuilder: (o) => o['label']!,
                              );
                              if (result != null) setState(() => _containerLength = result['value']);
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        FormSection(
                          label: 'Body Type *',
                          child: TapField(
                            value: containerBodyTypeLabel(_containerBodyType).isEmpty
                                ? 'Select body type'
                                : containerBodyTypeLabel(_containerBodyType),
                            icon: AppIcons.truck,
                            muted: _containerBodyType == null,
                            onTap: () async {
                              final result = await showOptionPicker<Map<String, String>>(
                                context,
                                title: 'Body Type',
                                options: kContainerBodyTypes,
                                selected:
                                    findOption(kContainerBodyTypes, _containerBodyType),
                                labelBuilder: (o) => o['label']!,
                              );
                              if (result != null) setState(() => _containerBodyType = result['value']);
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        FormSection(
                          label: 'Axle Type *',
                          child: TapField(
                            value: axleTypeLabel(_axleType).isEmpty ? 'Select axle type' : axleTypeLabel(_axleType),
                            icon: AppIcons.truck,
                            muted: _axleType == null,
                            onTap: () async {
                              final result = await showOptionPicker<Map<String, String>>(
                                context,
                                title: 'Axle Type',
                                options: kAxleTypes,
                                selected: findOption(kAxleTypes, _axleType),
                                labelBuilder: (o) => o['label']!,
                              );
                              if (result != null) setState(() => _axleType = result['value']);
                            },
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 14),
                    FormSection(
                      label: 'Monthly Rate (₹)',
                      child: TextField(
                        controller: _monthlyRateCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: FormSection(
                            label: 'Deployed From',
                            child: TapField(
                              value: _startDate != null ? formatDisplayDate(formatApiDate(_startDate!)) : 'Select date',
                              icon: AppIcons.calendar,
                              muted: _startDate == null,
                              onTap: () => _pickDate(isStart: true),
                              onClear: _startDate != null ? () => setState(() => _startDate = null) : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FormSection(
                            label: 'Until',
                            child: TapField(
                              value: _endDate != null ? formatDisplayDate(formatApiDate(_endDate!)) : 'Select date',
                              icon: AppIcons.calendar,
                              muted: _endDate == null,
                              onTap: () => _pickDate(isStart: false),
                              onClear: _endDate != null ? () => setState(() => _endDate = null) : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).viewInsets.bottom),
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text(_isEdit ? 'Update' : 'Add'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.1) : null,
          border: Border.all(
              color: selected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.border)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.primary : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}
