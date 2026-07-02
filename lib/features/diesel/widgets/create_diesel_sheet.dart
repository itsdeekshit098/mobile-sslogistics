import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_sslogistics/core/constants/app_icons.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../data/diesel_models.dart';
import '../providers/diesel_provider.dart';
import '../providers/vehicle_provider.dart';
import '../../../shared/models/vehicle_model.dart';

class CreateDieselSheet extends ConsumerStatefulWidget {
  const CreateDieselSheet({super.key});

  @override
  ConsumerState<CreateDieselSheet> createState() => _CreateDieselSheetState();
}

class _CreateDieselSheetState extends ConsumerState<CreateDieselSheet> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _driverCtrl = TextEditingController();
  final _odoCtrl = TextEditingController();
  final _fuelCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _stationCtrl = TextEditingController();
  final _receiptCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  Vehicle? _selectedVehicle;
  String _fillType = 'full'; // 'full' | 'partial'
  String? _paymentMethod;
  bool _isSubmitting = false;

  static const _paymentMethods = ['Cash', 'Card', 'UPI', 'Fleet'];

  // Computed amount
  double get _amount {
    final fuel = double.tryParse(_fuelCtrl.text) ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    return fuel * price;
  }

  @override
  void dispose() {
    for (final c in [
      _driverCtrl,
      _odoCtrl,
      _fuelCtrl,
      _priceCtrl,
      _stationCtrl,
      _receiptCtrl,
      _notesCtrl,
    ]) {
      c.dispose();
    }
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
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVehicle == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a vehicle')));
      return;
    }

    setState(() => _isSubmitting = true);

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
        driverName: _driverCtrl.text.trim(),
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

      await ref.read(dieselListProvider.notifier).createRecord(dto);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Diesel entry added'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final dateFmt = DateFormat('dd MMM yyyy');

    return Material(
      color: Colors.white,
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
                color: AppColors.border,
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
                const Text(
                  'Add Diesel Entry',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
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
                      label: 'Driver Name *',
                      child: TextFormField(
                        controller: _driverCtrl,
                        decoration: _inputDecor(hint: 'Enter driver name'),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.border,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      type == 'full' ? 'Full' : 'Partial',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.textSecondary,
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
                              controller: _odoCtrl,
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
                              controller: _fuelCtrl,
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
                              controller: _priceCtrl,
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
                                color: AppColors.pageBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _amount > 0
                                    ? '₹ ${NumberFormat('#,##0.00', 'en_IN').format(_amount)}'
                                    : '—',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

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
    );
  }

  InputDecoration _inputDecor({String? hint}) => InputDecoration(
    hintText: hint,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

class _Section extends StatelessWidget {
  final String label;
  final Widget child;
  const _Section({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    const labelStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: muted ? AppColors.textMuted : AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: AppColors.textMuted,
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
              decoration: _searchDecor('Search vehicle number, make, model'),
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
                    itemBuilder: (_, index) {
                      final vehicle = filtered[index];
                      final selected = widget.selectedVehicle?.id == vehicle.id;
                      return ListTile(
                        leading: const Icon(
                          AppIcons.truck,
                          color: AppColors.textSecondary,
                        ),
                        title: Text(
                          vehicle.plateNumber,
                          style: TextStyle(
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: selected
                                ? AppColors.primary
                                : AppColors.textPrimary,
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
                        : AppColors.pageBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
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
                                : AppColors.textPrimary,
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
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
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

InputDecoration _searchDecor(String hint) => InputDecoration(
  hintText: hint,
  prefixIcon: const Icon(Icons.search_rounded, size: 20),
  isDense: true,
  filled: true,
  fillColor: AppColors.pageBg,
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
    borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
  ),
);

class _HintChip extends StatelessWidget {
  final String label;
  final String value;
  const _HintChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
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
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
