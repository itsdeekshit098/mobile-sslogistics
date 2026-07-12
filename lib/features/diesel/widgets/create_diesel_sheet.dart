import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_sslogistics/core/constants/app_icons.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../data/diesel_models.dart';
import '../providers/diesel_provider.dart';
import '../providers/vehicle_provider.dart';
import '../providers/active_drivers_provider.dart';
import '../../../shared/models/vehicle_model.dart';
import '../../../shared/utils/validated_field.dart';
import '../../../shared/widgets/form_error_banner.dart';
import '../../../shared/widgets/server_error_banner.dart';
import '../../drivers/data/driver_models.dart';
import '../../drivers/data/driver_repository.dart';
import '../../drivers/widgets/driver_form_sheet.dart';
import 'driver_picker_sheet.dart';

class CreateDieselSheet extends ConsumerStatefulWidget {
  const CreateDieselSheet({super.key});

  @override
  ConsumerState<CreateDieselSheet> createState() => _CreateDieselSheetState();
}

class _CreateDieselSheetState extends ConsumerState<CreateDieselSheet> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _odoCtrl = TextEditingController();
  final _fuelCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _stationCtrl = TextEditingController();
  final _receiptCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  Vehicle? _selectedVehicle;
  Driver? _selectedDriver;
  String _fillType = 'full'; // 'full' | 'partial'
  String? _paymentMethod;
  bool _isSubmitting = false;
  int _errorCount = 0;
  // Server-side rejection (e.g. date-before-last-entry). Shown as a banner
  // inside the sheet rather than a SnackBar — a SnackBar anchors to the
  // screen underneath and renders hidden behind this modal bottom sheet,
  // so the user never sees it even though it technically fired.
  String? _serverError;

  final _vehicleSectionKey = GlobalKey();
  final _driverSectionKey = GlobalKey();
  final _odoFieldKey = GlobalKey<FormFieldState>();
  final _odoFocus = FocusNode();
  final _fuelFieldKey = GlobalKey<FormFieldState>();
  final _fuelFocus = FocusNode();
  final _priceFieldKey = GlobalKey<FormFieldState>();
  final _priceFocus = FocusNode();

  List<ValidatedField> get _validatedFields => [
        ValidatedField(
          key: _vehicleSectionKey,
          hasError: () => _selectedVehicle == null,
        ),
        ValidatedField(
          key: _driverSectionKey,
          hasError: () => _selectedDriver == null,
        ),
        ValidatedField(
          key: _odoFieldKey,
          hasError: () => _odoFieldKey.currentState?.hasError ?? false,
          focusNode: _odoFocus,
        ),
        ValidatedField(
          key: _fuelFieldKey,
          hasError: () => _fuelFieldKey.currentState?.hasError ?? false,
          focusNode: _fuelFocus,
        ),
        ValidatedField(
          key: _priceFieldKey,
          hasError: () => _priceFieldKey.currentState?.hasError ?? false,
          focusNode: _priceFocus,
        ),
      ];

  static const _paymentMethods = ['Cash', 'Card', 'UPI', 'Fleet'];

  // Computed amount
  double get _amount {
    final fuel = double.tryParse(_fuelCtrl.text) ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    return fuel * price;
  }

  // Client-side warnings — mirrors web's live warning computation
  // (createDieselModal.tsx) so users see the same tank-capacity checks
  // before submitting.
  List<String> get _warnings {
    final w = <String>[];
    final tank = _selectedVehicle?.tankCapacity;
    final litres = double.tryParse(_fuelCtrl.text) ?? 0;
    if (tank != null && tank > 0 && litres > tank) {
      w.add(
        'Fuel (${litres.toStringAsFixed(1)}L) exceeds tank capacity (${tank}L)',
      );
    }
    if (_fillType == 'full' &&
        tank != null &&
        tank > 0 &&
        litres > 0 &&
        litres < tank * 0.3) {
      w.add(
        'Only ${litres.toStringAsFixed(1)}L for a full fill? Tank capacity is ${tank}L. Are you sure?',
      );
    }
    return w;
  }

  @override
  void dispose() {
    for (final c in [
      _odoCtrl,
      _fuelCtrl,
      _priceCtrl,
      _stationCtrl,
      _receiptCtrl,
      _notesCtrl,
    ]) {
      c.dispose();
    }
    _odoFocus.dispose();
    _fuelFocus.dispose();
    _priceFocus.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _pickVehicle(List<Vehicle> vehicles) async {
    final picked = await showModalBottomSheet<Vehicle>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VehiclePickerSheet(
        vehicles: vehicles,
        selectedVehicle: _selectedVehicle,
      ),
    );
    if (picked != null) setState(() => _selectedVehicle = picked);
  }

  Future<void> _pickDriver(List<Driver> drivers) async {
    final picked = await showModalBottomSheet<Driver>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DriverPickerSheet(
        drivers: drivers,
        selectedDriver: _selectedDriver,
        onAddNewDriver: _addNewDriver,
      ),
    );
    if (picked != null) setState(() => _selectedDriver = picked);
  }

  Future<void> _addNewDriver() async {
    Navigator.pop(context); // close the driver picker sheet first
    final repo = DriverRepository();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DriverFormSheet(
        onSubmit: (create, _) async {
          if (create == null) return;
          await repo.createDriver(create);
          ref.invalidate(activeDriversProvider);
          final drivers = await ref.read(activeDriversProvider.future);
          final added = drivers.where((d) => d.name == create.name).toList();
          if (added.isNotEmpty && mounted) {
            setState(() => _selectedDriver = added.last);
          }
        },
      ),
    );
  }

  Future<void> _pickPaymentMethod() async {
    final picked = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _OptionPickerSheet<String?>(
        title: 'Payment Method',
        selectedValue: _paymentMethod,
        options: const [null, ..._paymentMethods],
        labelBuilder: (value) => value ?? 'No payment method',
      ),
    );
    if (!mounted) return;
    setState(() => _paymentMethod = picked);
  }

  Future<void> _submit() async {
    final formValid = _formKey.currentState!.validate();
    if (!formValid || _selectedVehicle == null || _selectedDriver == null) {
      final fields = _validatedFields;
      setState(() => _errorCount = countFormErrors(fields));
      await scrollToFirstError(fields);
      return;
    }

    setState(() {
      _errorCount = 0;
      _serverError = null;
      _isSubmitting = true;
    });

    try {
      final dt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final dto = CreateDieselDto(
        vehicleId: _selectedVehicle!.id,
        driverName: _selectedDriver!.name,
        fillDate: dt.toUtc().toIso8601String(),
        fillType: _fillType,
        fuelLitres: double.parse(_fuelCtrl.text),
        pricePerL: double.tryParse(_priceCtrl.text) ?? 0,
        currentOdo: double.parse(_odoCtrl.text),
        station: _stationCtrl.text.trim().isEmpty
            ? null
            : _stationCtrl.text.trim(),
        paymentMethod: _paymentMethod,
        receiptNumber: _receiptCtrl.text.trim().isEmpty
            ? null
            : _receiptCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      final serverWarnings =
          await ref.read(dieselListProvider.notifier).createRecord(dto);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              serverWarnings.isEmpty
                  ? 'Diesel entry added'
                  : 'Diesel entry added — ${serverWarnings.join('; ')}',
            ),
            backgroundColor: serverWarnings.isEmpty
                ? AppColors.success
                : AppColors.warning,
          ),
        );
      }
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
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final dateFmt = DateFormat('dd MMM yyyy');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      // While a submit is in flight, block swipe-to-dismiss / back so the
      // sheet (and any error SnackBar it shows on failure) can't be torn
      // down before the request resolves — otherwise the `mounted` check in
      // the catch block silently drops the error.
      canPop: !_isSubmitting,
      child: Material(
      color: isDark ? AppColors.darkCardBg : Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
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

          // Title bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Text(
                  'Add Diesel Entry',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(AppIcons.x, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_errorCount > 0) FormErrorBanner(count: _errorCount),
          if (_serverError != null) ServerErrorBanner(message: _serverError!),

          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Date & Time ──────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _Section(
                            label: 'Date *',
                            child: _TapField(
                              value: dateFmt.format(_selectedDate),
                              icon: AppIcons.calendar,
                              onTap: _pickDate,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Section(
                            label: 'Time *',
                            child: _TapField(
                              value: _selectedTime.format(context),
                              icon: AppIcons.clock,
                              onTap: _pickTime,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Vehicle ──────────────────────────────────────────
                    _Section(
                      key: _vehicleSectionKey,
                      label: 'Vehicle *',
                      child: vehiclesAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text(
                          'Error loading vehicles',
                          style: TextStyle(color: AppColors.error),
                        ),
                        data: (vehicles) => _TapField(
                          value:
                              _selectedVehicle?.plateNumber ?? 'Select vehicle',
                          icon: AppIcons.truck,
                          muted: _selectedVehicle == null,
                          onTap: () => _pickVehicle(vehicles),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Vehicle info hint
                    if (_selectedVehicle != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.tileVehiclesBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            if (_selectedVehicle!.expectedKml != null)
                              _HintChip(
                                label: 'Exp. KML',
                                value: '${_selectedVehicle!.expectedKml} km/L',
                              ),
                            if (_selectedVehicle!.tankCapacity != null) ...[
                              const SizedBox(width: 16),
                              _HintChip(
                                label: 'Tank',
                                value: '${_selectedVehicle!.tankCapacity} L',
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // ── Driver Name ──────────────────────────────────────
                    _Section(
                      key: _driverSectionKey,
                      label: 'Driver Name *',
                      child: Consumer(
                        builder: (context, ref, _) {
                          final driversAsync = ref.watch(activeDriversProvider);
                          return driversAsync.when(
                            loading: () => const LinearProgressIndicator(),
                            error: (e, _) => Text(
                              'Error loading drivers',
                              style: TextStyle(color: AppColors.error),
                            ),
                            data: (drivers) => _TapField(
                              value: _selectedDriver?.name ?? 'Select driver',
                              icon: AppIcons.user,
                              muted: _selectedDriver == null,
                              onTap: () => _pickDriver(drivers),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Fill Type ────────────────────────────────────────
                    _Section(
                      label: 'Fill Type *',
                      child: Row(
                        children: ['full', 'partial'].map((type) {
                          final isSelected = _fillType == type;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: type == 'full' ? 8 : 0,
                              ),
                              child: InkWell(
                                onTap: () => setState(() => _fillType = type),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary
                                        : (isDark
                                              ? AppColors.darkCardBg
                                              : Colors.white),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : (isDark
                                                ? AppColors.darkBorder
                                                : AppColors.border),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      type == 'full' ? 'Full' : 'Partial',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : (isDark
                                                  ? AppColors.darkTextSecondary
                                                  : AppColors.textSecondary),
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
                    const SizedBox(height: 14),

                    // ── Odometer & Fuel ──────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _Section(
                            label: 'Current Odometer (km) *',
                            child: TextFormField(
                              key: _odoFieldKey,
                              controller: _odoCtrl,
                              focusNode: _odoFocus,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: _inputDecor(hint: 'e.g. 50000'),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                if (double.tryParse(v) == null) {
                                  return 'Invalid';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Section(
                            label: 'Fuel Added (L) *',
                            child: TextFormField(
                              key: _fuelFieldKey,
                              controller: _fuelCtrl,
                              focusNode: _fuelFocus,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: _inputDecor(hint: 'e.g. 45.5'),
                              onChanged: (_) => setState(() {}),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                final n = double.tryParse(v);
                                if (n == null || n <= 0) return 'Must be > 0';
                                return null;
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Price & Amount ───────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _Section(
                            label: 'Price per Litre (₹)',
                            child: TextFormField(
                              key: _priceFieldKey,
                              controller: _priceCtrl,
                              focusNode: _priceFocus,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: _inputDecor(hint: 'e.g. 95.50'),
                              onChanged: (_) => setState(() {}),
                              validator: (v) {
                                if (v != null &&
                                    v.isNotEmpty &&
                                    double.tryParse(v) == null) {
                                  return 'Invalid';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Section(
                            label: 'Amount (₹)',
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkPageBg
                                    : AppColors.pageBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.darkBorder
                                      : AppColors.border,
                                ),
                              ),
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _amount > 0
                                    ? '₹ ${NumberFormat('#,##0.00', 'en_IN').format(_amount)}'
                                    : '—',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Warnings ─────────────────────────────────────────
                    if (_warnings.isNotEmpty) ...[
                      _CreateWarningBox(warnings: _warnings),
                      const SizedBox(height: 14),
                    ],

                    // ── Station ──────────────────────────────────────────
                    _Section(
                      label: 'Station',
                      child: TextFormField(
                        controller: _stationCtrl,
                        decoration: _inputDecor(hint: 'e.g. Shell, Mumbai'),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Payment Method & Receipt ─────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _Section(
                            label: 'Payment Method',
                            child: _TapField(
                              value: _paymentMethod ?? 'Select',
                              icon: Icons.payments_outlined,
                              muted: _paymentMethod == null,
                              onTap: _pickPaymentMethod,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Section(
                            label: 'Receipt Number',
                            child: TextFormField(
                              controller: _receiptCtrl,
                              decoration: _inputDecor(hint: 'REC123'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Notes ────────────────────────────────────────────
                    _Section(
                      label: 'Notes',
                      child: TextFormField(
                        controller: _notesCtrl,
                        maxLines: 2,
                        decoration: _inputDecor(hint: 'Additional notes...'),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),

          // Submit bar
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              12 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Add Diesel Entry'),
            ),
          ),
        ],
      ),
      ),
    );
  }

  InputDecoration _inputDecor({String? hint}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    return InputDecoration(
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

class _CreateWarningBox extends StatelessWidget {
  final List<String> warnings;
  const _CreateWarningBox({required this.warnings});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkWarningBg : AppColors.warningBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: warnings
            .map(
              (warning) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      AppIcons.alertTriangle,
                      size: 16,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        warning,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  final Widget child;
  const _Section({super.key, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
    );
    final isRequired = label.endsWith(' *');
    final baseLabel = isRequired
        ? label.substring(0, label.length - 2)
        : label;

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

  const _TapField({
    required this.value,
    required this.icon,
    required this.onTap,
    this.muted = false,
  });

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
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
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
                  color: muted
                      ? mutedColor
                      : (isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary),
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: mutedColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _VehiclePickerSheet extends StatefulWidget {
  final List<Vehicle> vehicles;
  final Vehicle? selectedVehicle;

  const _VehiclePickerSheet({required this.vehicles, this.selectedVehicle});

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    return _PickerShell(
      title: 'Select vehicle (${widget.vehicles.length})',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              decoration: _searchDecor(
                context,
                'Search vehicle number, make, model',
              ),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: maxListHeight.clamp(160.0, 420.0),
            ),
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'No vehicles found',
                        style: TextStyle(color: secondaryColor),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                    ),
                    itemBuilder: (_, index) {
                      final vehicle = filtered[index];
                      final selected = widget.selectedVehicle?.id == vehicle.id;
                      return ListTile(
                        leading: Icon(
                          AppIcons.truck,
                          color: secondaryColor,
                        ),
                        title: Text(
                          vehicle.plateNumber,
                          style: TextStyle(
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: selected
                                ? AppColors.primary
                                : (isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.textPrimary),
                          ),
                        ),
                        subtitle:
                            [
                              vehicle.make,
                              vehicle.model,
                            ].whereType<String>().join(' ').isEmpty
                            ? null
                            : Text(
                                [
                                  vehicle.make,
                                  vehicle.model,
                                ].whereType<String>().join(' '),
                              ),
                        trailing: selected
                            ? const Icon(
                                Icons.check_rounded,
                                color: AppColors.primary,
                              )
                            : null,
                        onTap: () => Navigator.pop(context, vehicle),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _OptionPickerSheet<T> extends StatelessWidget {
  final String title;
  final T selectedValue;
  final List<T> options;
  final String Function(T value) labelBuilder;

  const _OptionPickerSheet({
    required this.title,
    required this.selectedValue,
    required this.options,
    required this.labelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _PickerShell(
      title: title,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((option) {
            final selected = option == selectedValue;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => Navigator.pop(context, option),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.tileVehiclesBg
                        : (isDark ? AppColors.darkPageBg : AppColors.pageBg),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : (isDark ? AppColors.darkBorder : AppColors.border),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          labelBuilder(option),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? AppColors.primary
                                : (isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.textPrimary),
                          ),
                        ),
                      ),
                      if (selected)
                        const Icon(
                          Icons.check_rounded,
                          color: AppColors.primary,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
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
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(AppIcons.x, size: 20),
                    ),
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
      borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
    ),
  );
}

class _HintChip extends StatelessWidget {
  final String label;
  final String value;
  const _HintChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.tileVehiclesIcon,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
