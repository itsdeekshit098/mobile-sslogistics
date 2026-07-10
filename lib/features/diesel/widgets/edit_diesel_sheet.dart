import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_sslogistics/core/constants/app_icons.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/utils/validated_field.dart';
import '../../../shared/widgets/form_error_banner.dart';
import '../data/diesel_models.dart';
import '../providers/diesel_provider.dart';
import '../providers/active_drivers_provider.dart';
import '../../drivers/data/driver_models.dart';
import '../../drivers/data/driver_repository.dart';
import '../../drivers/widgets/driver_form_sheet.dart';
import 'driver_picker_sheet.dart';

class EditDieselSheet extends ConsumerStatefulWidget {
  final DieselRecord record;
  const EditDieselSheet({super.key, required this.record});

  @override
  ConsumerState<EditDieselSheet> createState() => _EditDieselSheetState();
}

class _EditDieselSheetState extends ConsumerState<EditDieselSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _fuelCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _stationCtrl;
  late final TextEditingController _receiptCtrl;
  late final TextEditingController _notesCtrl;

  // The record's original driver name is kept unless the user re-picks a
  // driver, so re-opening this sheet never forces a re-selection.
  late String _driverName;
  Driver? _selectedDriver;
  String? _paymentMethod;
  bool _isSubmitting = false;
  int _errorCount = 0;

  final _driverSectionKey = GlobalKey();
  final _fuelFieldKey = GlobalKey<FormFieldState>();
  final _fuelFocus = FocusNode();

  List<ValidatedField> get _validatedFields => [
        ValidatedField(
          key: _driverSectionKey,
          hasError: () => _driverName.trim().isEmpty,
        ),
        ValidatedField(
          key: _fuelFieldKey,
          hasError: () => _fuelFieldKey.currentState?.hasError ?? false,
          focusNode: _fuelFocus,
        ),
      ];

  static const _paymentMethods = ['Cash', 'Card', 'UPI', 'Fleet'];

  double get _amount {
    final fuel = double.tryParse(_fuelCtrl.text) ?? widget.record.fuelLitres;
    final price = double.tryParse(_priceCtrl.text) ?? widget.record.pricePerL;
    return fuel * price;
  }

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    _driverName = r.driverName;
    _fuelCtrl = TextEditingController(text: r.fuelLitres.toString());
    _priceCtrl = TextEditingController(text: r.pricePerL.toString());
    _stationCtrl = TextEditingController(text: r.station ?? '');
    _receiptCtrl = TextEditingController(text: r.receiptNumber ?? '');
    _notesCtrl = TextEditingController(text: r.notes ?? '');
    _paymentMethod = r.paymentMethod;
  }

  @override
  void dispose() {
    for (final c in [
      _fuelCtrl,
      _priceCtrl,
      _stationCtrl,
      _receiptCtrl,
      _notesCtrl,
    ]) {
      c.dispose();
    }
    _fuelFocus.dispose();
    super.dispose();
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
    if (picked != null) {
      setState(() {
        _selectedDriver = picked;
        _driverName = picked.name;
      });
    }
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
            setState(() {
              _selectedDriver = added.last;
              _driverName = added.last.name;
            });
          }
        },
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      final fields = _validatedFields;
      setState(() => _errorCount = countFormErrors(fields));
      await scrollToFirstError(fields);
      return;
    }
    setState(() {
      _errorCount = 0;
      _isSubmitting = true;
    });

    try {
      await ref
          .read(dieselListProvider.notifier)
          .updateRecord(
            UpdateDieselDto(
              id: widget.record.id,
              driverName: _driverName.trim(),
              fuelLitres: double.tryParse(_fuelCtrl.text),
              pricePerL: double.tryParse(_priceCtrl.text),
              station: _stationCtrl.text.trim(),
              paymentMethod: _paymentMethod,
              receiptNumber: _receiptCtrl.text.trim(),
              notes: _notesCtrl.text.trim(),
            ),
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Record updated'),
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

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final fillDate = DateTime.tryParse(r.fillDate)?.toLocal();
    final dateFmt = DateFormat('dd MMM yyyy  HH:mm');
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Text(
                  'Edit Diesel Record',
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

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Read-only info ─────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkPageBg : AppColors.pageBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.border,
                        ),
                      ),
                      child: Column(
                        children: [
                          _ReadOnlyRow(label: 'Vehicle', value: r.vehiclePlate),
                          _ReadOnlyRow(
                            label: 'Date',
                            value: fillDate != null
                                ? dateFmt.format(fillDate)
                                : r.fillDate,
                          ),
                          _ReadOnlyRow(
                            label: 'Fill Type',
                            value: r.fillType == 'full' ? 'Full' : 'Partial',
                          ),
                          _ReadOnlyRow(
                            label: 'Odometer',
                            value:
                                '${NumberFormat('#,##0', 'en_IN').format(r.currentOdo)} km',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Editable fields ────────────────────────────────
                    _Section(
                      key: _driverSectionKey,
                      label: 'Driver Name',
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
                              value: _driverName,
                              icon: AppIcons.user,
                              onTap: () => _pickDriver(drivers),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: _Section(
                            label: 'Fuel (L)',
                            child: TextFormField(
                              key: _fuelFieldKey,
                              controller: _fuelCtrl,
                              focusNode: _fuelFocus,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: _inputDecor(hint: 'Litres'),
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Section(
                            label: 'Price / L (₹)',
                            child: TextFormField(
                              controller: _priceCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: _inputDecor(hint: 'e.g. 95.50'),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Computed amount
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Amount: ₹ ${NumberFormat('#,##0.00', 'en_IN').format(_amount)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    _Section(
                      label: 'Station',
                      child: TextFormField(
                        controller: _stationCtrl,
                        decoration: _inputDecor(hint: 'Station name'),
                      ),
                    ),
                    const SizedBox(height: 14),

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
                  : const Text('Save Changes'),
            ),
          ),
        ],
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

class _ReadOnlyRow extends StatelessWidget {
  final String label;
  final String value;
  const _ReadOnlyRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
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
    return Material(
      color: isDark ? AppColors.darkCardBg : Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 14, 0, 12),
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
              ...options.map((option) {
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
                            : (isDark
                                  ? AppColors.darkPageBg
                                  : AppColors.pageBg),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : (isDark
                                    ? AppColors.darkBorder
                                    : AppColors.border),
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
              }),
            ],
          ),
        ),
      ),
    );
  }
}
