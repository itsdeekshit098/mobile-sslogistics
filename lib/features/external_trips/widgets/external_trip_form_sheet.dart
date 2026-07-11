import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobile_sslogistics/core/constants/app_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/models/vehicle_model.dart';
import '../../../shared/utils/validated_field.dart';
import '../../../shared/widgets/form_error_banner.dart';
import '../../diesel/providers/vehicle_provider.dart';
import '../data/external_trip_models.dart';
import '../providers/external_trip_provider.dart';
import 'cost_items_editor.dart';

final _phoneRegex = RegExp(r'^[6-9]\d{9}$');
final _apiDateFmt = DateFormat('yyyy-MM-dd');
final _displayDateFmt = DateFormat('dd MMM yyyy');
final _moneyFmt = NumberFormat('#,##0.00', 'en_IN');

/// Create/edit form for an external trip. When [trip] is null the sheet
/// creates a new trip; otherwise it edits (vehicle and trip type become
/// read-only, matching the API's PUT contract).
///
/// When [bookingId] is set (only valid alongside [trip] == null), the form
/// is pre-filled from [prefill] and, on submit, includes `booking_id` in the
/// POST payload so the server atomically completes that trip booking.
class ExternalTripFormSheet extends ConsumerStatefulWidget {
  final ExternalTrip? trip;
  final int? bookingId;
  final ExternalTripPrefill? prefill;

  const ExternalTripFormSheet({
    super.key,
    this.trip,
    this.bookingId,
    this.prefill,
  });

  @override
  ConsumerState<ExternalTripFormSheet> createState() =>
      _ExternalTripFormSheetState();
}

class _ExternalTripFormSheetState extends ConsumerState<ExternalTripFormSheet> {
  final _formKey = GlobalKey<FormState>();

  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  final _fromLocationCtrl = TextEditingController();
  final _toLocationCtrl = TextEditingController();
  final _amountReceivedCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Lets a failed submit scroll/focus back to the first invalid field,
  // since Form.validate() only paints errors — it never scrolls to them.
  final _vehicleSectionKey = GlobalKey();
  final _customerPhoneFieldKey = GlobalKey<FormFieldState>();
  final _customerPhoneFocus = FocusNode();
  final _amountReceivedFieldKey = GlobalKey<FormFieldState>();
  final _amountReceivedFocus = FocusNode();
  int _errorCount = 0;

  Vehicle? _selectedVehicle;
  String _tripType = tripTypeCompanyOncall;
  DateTime? _startDate;
  DateTime? _endDate;
  Driver? _selectedDriver;
  late List<CostItemEntry> _costEntries;
  bool _isSubmitting = false;

  bool get _isEdit => widget.trip != null;
  bool get _isCompletingBooking => widget.bookingId != null;

  double get _totalCost =>
      _costEntries.fold(0, (sum, e) => sum + e.amount);

  double get _amountReceived =>
      double.tryParse(_amountReceivedCtrl.text) ?? 0;

  @override
  void initState() {
    super.initState();
    final trip = widget.trip;
    final prefill = widget.prefill;
    _costEntries = buildCostItemEntries(trip?.costItems);
    if (trip != null) {
      _tripType = trip.tripType;
      _customerNameCtrl.text = trip.customerName ?? '';
      _customerPhoneCtrl.text = trip.customerPhone ?? '';
      _fromLocationCtrl.text = trip.fromLocation ?? '';
      _toLocationCtrl.text = trip.toLocation ?? '';
      _amountReceivedCtrl.text = trip.amountReceived == 0
          ? '0'
          : (trip.amountReceived == trip.amountReceived.roundToDouble()
              ? trip.amountReceived.toInt().toString()
              : trip.amountReceived.toString());
      _notesCtrl.text = trip.notes ?? '';
      _startDate =
          trip.startDate != null ? DateTime.tryParse(trip.startDate!) : null;
      _endDate = trip.endDate != null ? DateTime.tryParse(trip.endDate!) : null;
      if (trip.driverId != null) {
        _selectedDriver = Driver(
          id: trip.driverId!,
          name: trip.driverName ?? 'Driver #${trip.driverId}',
          phone: trip.driverPhone,
          isActive: true,
        );
      }
    } else if (prefill != null) {
      _customerNameCtrl.text = prefill.customerName ?? '';
      _customerPhoneCtrl.text = prefill.customerPhone ?? '';
      _fromLocationCtrl.text = prefill.fromLocation ?? '';
      _toLocationCtrl.text = prefill.toLocation ?? '';
      _startDate =
          prefill.startDate != null ? DateTime.tryParse(prefill.startDate!) : null;
      _endDate =
          prefill.endDate != null ? DateTime.tryParse(prefill.endDate!) : null;
      final advance = prefill.advanceAmount ?? 0;
      if (advance != 0) {
        _amountReceivedCtrl.text = advance == advance.roundToDouble()
            ? advance.toInt().toString()
            : advance.toString();
      }
      if (prefill.vehicleId != null) {
        _selectedVehicle = Vehicle(
          id: prefill.vehicleId!,
          plateNumber: prefill.vehicleNumber ?? 'Vehicle #${prefill.vehicleId}',
        );
      }
      if (prefill.driverId != null) {
        _selectedDriver = Driver(
          id: prefill.driverId!,
          name: prefill.driverName ?? 'Driver #${prefill.driverId}',
          phone: prefill.driverPhone,
          isActive: true,
        );
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _customerNameCtrl,
      _customerPhoneCtrl,
      _fromLocationCtrl,
      _toLocationCtrl,
      _amountReceivedCtrl,
      _notesCtrl,
    ]) {
      c.dispose();
    }
    for (final entry in _costEntries) {
      entry.dispose();
    }
    _customerPhoneFocus.dispose();
    _amountReceivedFocus.dispose();
    super.dispose();
  }

  Future<void> _pickVehicle(List<Vehicle> vehicles) async {
    final picked = await showModalBottomSheet<Vehicle>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SearchPickerSheet<Vehicle>(
        title: 'Select vehicle (${vehicles.length})',
        icon: AppIcons.truck,
        items: vehicles,
        selected: _selectedVehicle,
        searchHint: 'Search vehicle number, make, model',
        labelBuilder: (v) => v.plateNumber,
        subtitleBuilder: (v) =>
            [v.make, v.model].whereType<String>().join(' '),
        matcher: (v, q) => [v.plateNumber, v.make, v.model]
            .whereType<String>()
            .join(' ')
            .toLowerCase()
            .contains(q),
      ),
    );
    if (picked != null) setState(() => _selectedVehicle = picked);
  }

  Future<void> _pickDriver(List<Driver> drivers) async {
    final picked = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SearchPickerSheet<Driver>(
        title: 'Select driver (${drivers.length})',
        icon: AppIcons.user,
        items: drivers,
        selected: _selectedDriver,
        searchHint: 'Search driver name, phone',
        labelBuilder: (d) => d.name,
        subtitleBuilder: (d) => d.phone ?? '',
        matcher: (d, q) =>
            '${d.name} ${d.phone ?? ''}'.toLowerCase().contains(q),
        clearLabel: 'No driver',
      ),
    );
    if (picked == null) return;
    setState(() =>
        _selectedDriver = picked is Driver ? picked : null); // _ClearPick
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null) {
      setState(() => isStart ? _startDate = picked : _endDate = picked);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  /// Ordered top-to-bottom validated fields, used to find and jump to the
  /// first one currently showing an error.
  List<ValidatedField> get _validatedFields => [
        if (!_isEdit)
          ValidatedField(
            key: _vehicleSectionKey,
            hasError: () => _selectedVehicle == null,
          ),
        ValidatedField(
          key: _customerPhoneFieldKey,
          hasError: () => _customerPhoneFieldKey.currentState?.hasError ?? false,
          focusNode: _customerPhoneFocus,
        ),
        for (final entry in _costEntries) ...[
          if (!entry.isPreset)
            ValidatedField(
              key: entry.labelFieldKey,
              hasError: () => entry.labelFieldKey.currentState?.hasError ?? false,
              focusNode: entry.labelFocusNode,
            ),
          ValidatedField(
            key: entry.amountFieldKey,
            hasError: () => entry.amountFieldKey.currentState?.hasError ?? false,
            focusNode: entry.amountFocusNode,
          ),
        ],
        ValidatedField(
          key: _amountReceivedFieldKey,
          hasError: () => _amountReceivedFieldKey.currentState?.hasError ?? false,
          focusNode: _amountReceivedFocus,
        ),
      ];

  Future<void> _submit() async {
    final noVehicleSelected = !_isEdit && _selectedVehicle == null;
    final formValid = _formKey.currentState!.validate();

    if (!formValid || noVehicleSelected) {
      final fields = _validatedFields;
      setState(() => _errorCount = countFormErrors(fields));

      final scrolled = await scrollToFirstError(fields);
      if (noVehicleSelected && !scrolled) {
        _snack('Please select a vehicle');
      }
      return;
    }

    if (_startDate != null &&
        _endDate != null &&
        _endDate!.isBefore(_startDate!)) {
      _snack('End date cannot be before start date');
      return;
    }

    setState(() {
      _errorCount = 0;
      _isSubmitting = true;
    });

    final costItems = _costEntries.map((e) => e.toCostItem()).toList();
    final notifier = ref.read(externalTripListProvider.notifier);

    try {
      if (_isEdit) {
        await notifier.updateTrip(UpdateExternalTripDto(
          id: widget.trip!.id,
          customerName: _textOrNull(_customerNameCtrl),
          customerPhone: _textOrNull(_customerPhoneCtrl),
          fromLocation: _textOrNull(_fromLocationCtrl),
          toLocation: _textOrNull(_toLocationCtrl),
          startDate:
              _startDate != null ? _apiDateFmt.format(_startDate!) : null,
          endDate: _endDate != null ? _apiDateFmt.format(_endDate!) : null,
          driverId: _selectedDriver?.id,
          notes: _textOrNull(_notesCtrl),
          costItems: costItems,
          amountReceived: _amountReceived,
        ));
      } else {
        await notifier.createTrip(CreateExternalTripDto(
          vehicleId: _selectedVehicle!.id,
          tripType: _tripType,
          customerName: _textOrNull(_customerNameCtrl),
          customerPhone: _textOrNull(_customerPhoneCtrl),
          fromLocation: _textOrNull(_fromLocationCtrl),
          toLocation: _textOrNull(_toLocationCtrl),
          startDate:
              _startDate != null ? _apiDateFmt.format(_startDate!) : null,
          endDate: _endDate != null ? _apiDateFmt.format(_endDate!) : null,
          driverId: _selectedDriver?.id,
          notes: _textOrNull(_notesCtrl),
          costItems: costItems,
          amountReceived: _amountReceived,
          bookingId: widget.bookingId,
        ));
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit
                ? 'Trip updated'
                : (_isCompletingBooking ? 'Booking completed' : 'Trip created')),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _snack(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  String? _textOrNull(TextEditingController ctrl) {
    final text = ctrl.text.trim();
    return text.isEmpty ? null : text;
  }

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final driversAsync = ref.watch(driversProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profit = _amountReceived - _totalCost;
    final profitColor = profit >= 0 ? AppColors.success : AppColors.error;

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
                  _isEdit
                      ? 'Edit Trip'
                      : (_isCompletingBooking
                          ? 'Complete Booking'
                          : 'New External Trip'),
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
                    if (widget.prefill != null) ...[
                      _BookingReferenceBanner(prefill: widget.prefill!),
                      const SizedBox(height: 14),
                    ],
                    // ── Vehicle ──────────────────────────────────────────
                    _Section(
                      key: _vehicleSectionKey,
                      label: 'Vehicle *',
                      child: _isEdit
                          ? _ReadOnlyField(value: widget.trip!.vehicleNumber)
                          : vehiclesAsync.when(
                              loading: () => const LinearProgressIndicator(),
                              error: (e, _) => const Text(
                                'Error loading vehicles',
                                style: TextStyle(color: AppColors.error),
                              ),
                              data: (vehicles) => _TapField(
                                value: _selectedVehicle?.plateNumber ??
                                    'Select vehicle',
                                icon: AppIcons.truck,
                                muted: _selectedVehicle == null,
                                onTap: () => _pickVehicle(vehicles),
                              ),
                            ),
                    ),
                    const SizedBox(height: 14),

                    // ── Trip Type ────────────────────────────────────────
                    _Section(
                      label: 'Trip Type *',
                      child: _isEdit
                          ? _ReadOnlyField(value: widget.trip!.tripTypeLabel)
                          : Row(
                              children: [
                                tripTypeCompanyOncall,
                                tripTypeExternalUser,
                              ].map((type) {
                                final isSelected = _tripType == type;
                                return Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right:
                                          type == tripTypeCompanyOncall ? 8 : 0,
                                    ),
                                    child: InkWell(
                                      onTap: () =>
                                          setState(() => _tripType = type),
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
                                          borderRadius:
                                              BorderRadius.circular(8),
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
                                            tripTypeLabels[type]!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: isSelected
                                                  ? Colors.white
                                                  : (isDark
                                                      ? AppColors
                                                          .darkTextSecondary
                                                      : AppColors
                                                          .textSecondary),
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

                    // ── Customer ─────────────────────────────────────────
                    _Section(
                      label: 'Customer Name',
                      child: TextFormField(
                        controller: _customerNameCtrl,
                        decoration: _inputDecor(hint: 'Enter customer name'),
                        textCapitalization: TextCapitalization.words,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _Section(
                      label: 'Customer Phone',
                      child: TextFormField(
                        key: _customerPhoneFieldKey,
                        controller: _customerPhoneCtrl,
                        focusNode: _customerPhoneFocus,
                        keyboardType: TextInputType.phone,
                        decoration: _inputDecor(hint: '10-digit mobile number'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          if (!_phoneRegex.hasMatch(v.trim())) {
                            return 'Enter a valid 10-digit mobile number';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Route ────────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _Section(
                            label: 'From',
                            child: TextFormField(
                              controller: _fromLocationCtrl,
                              decoration: _inputDecor(hint: 'Origin'),
                              textCapitalization: TextCapitalization.words,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Section(
                            label: 'To',
                            child: TextFormField(
                              controller: _toLocationCtrl,
                              decoration: _inputDecor(hint: 'Destination'),
                              textCapitalization: TextCapitalization.words,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Dates ────────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _Section(
                            label: 'Start Date',
                            child: _TapField(
                              value: _startDate != null
                                  ? _displayDateFmt.format(_startDate!)
                                  : 'Select date',
                              icon: AppIcons.calendar,
                              muted: _startDate == null,
                              onTap: () => _pickDate(isStart: true),
                              onClear: _startDate != null
                                  ? () => setState(() => _startDate = null)
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Section(
                            label: 'End Date',
                            child: _TapField(
                              value: _endDate != null
                                  ? _displayDateFmt.format(_endDate!)
                                  : 'Select date',
                              icon: AppIcons.calendar,
                              muted: _endDate == null,
                              onTap: () => _pickDate(isStart: false),
                              onClear: _endDate != null
                                  ? () => setState(() => _endDate = null)
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Driver ───────────────────────────────────────────
                    _Section(
                      label: 'Driver',
                      child: driversAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => const Text(
                          'Error loading drivers',
                          style: TextStyle(color: AppColors.error),
                        ),
                        data: (drivers) => _TapField(
                          value: _selectedDriver?.name ?? 'Select driver',
                          icon: AppIcons.user,
                          muted: _selectedDriver == null,
                          onTap: () => _pickDriver(drivers),
                          onClear: _selectedDriver != null
                              ? () => setState(() => _selectedDriver = null)
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Cost items ───────────────────────────────────────
                    _Section(
                      label: 'Cost Breakdown *',
                      child: CostItemsEditor(
                        entries: _costEntries,
                        onAdd: () => setState(
                          () => _costEntries.add(CostItemEntry.custom()),
                        ),
                        onRemove: (entry) => setState(() {
                          _costEntries.remove(entry);
                          entry.dispose();
                        }),
                        onChanged: () => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Amount received & profit preview ─────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _Section(
                            label: 'Amount Received (₹) *',
                            child: TextFormField(
                              key: _amountReceivedFieldKey,
                              controller: _amountReceivedCtrl,
                              focusNode: _amountReceivedFocus,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: _inputDecor(hint: 'e.g. 12000'),
                              onChanged: (_) => setState(() {}),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                final n = double.tryParse(v);
                                if (n == null || n < 0) {
                                  return 'Must be 0 or more';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Section(
                            label: 'Profit (₹)',
                            child: Container(
                              height: 48,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
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
                                '${profit >= 0 ? '+' : '−'}₹${_moneyFmt.format(profit.abs())}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: profitColor,
                                ),
                              ),
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
                        maxLines: 3,
                        maxLength: notesMaxLength,
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
                  : Text(_isEdit ? 'Save Changes' : 'Create Trip'),
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

/// Read-only reminder of what was agreed when the trip booking was taken,
/// shown at the top of the form while completing it into a full trip.
class _BookingReferenceBanner extends StatelessWidget {
  final ExternalTripPrefill prefill;
  const _BookingReferenceBanner({required this.prefill});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (prefill.quotedAmount == null && (prefill.advanceAmount ?? 0) == 0) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Agreed at booking — Quoted: '
              '${prefill.quotedAmount != null ? '₹${_moneyFmt.format(prefill.quotedAmount)}' : '—'}'
              ' · Advance: ₹${_moneyFmt.format(prefill.advanceAmount ?? 0)}',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
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
    final labelStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
    );
    final isRequired = label.endsWith(' *');
    final baseLabel =
        isRequired ? label.substring(0, label.length - 2) : label;

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

class _ReadOnlyField extends StatelessWidget {
  final String value;
  const _ReadOnlyField({required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkPageBg : AppColors.pageBg,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
          ),
          Icon(
            AppIcons.lock,
            size: 14,
            color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}

class _TapField extends StatelessWidget {
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final bool muted;

  const _TapField({
    required this.value,
    required this.icon,
    required this.onTap,
    this.onClear,
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
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(AppIcons.x, size: 16, color: mutedColor),
              )
            else
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

/// Marker returned when the user taps the "clear" row in a picker.
class _ClearPick {
  const _ClearPick();
}

class _SearchPickerSheet<T> extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<T> items;
  final T? selected;
  final String searchHint;
  final String Function(T item) labelBuilder;
  final String Function(T item) subtitleBuilder;
  final bool Function(T item, String query) matcher;
  final String? clearLabel;

  const _SearchPickerSheet({
    super.key,
    required this.title,
    required this.icon,
    required this.items,
    required this.selected,
    required this.searchHint,
    required this.labelBuilder,
    required this.subtitleBuilder,
    required this.matcher,
    this.clearLabel,
  });

  @override
  State<_SearchPickerSheet<T>> createState() => _SearchPickerSheetState<T>();
}

class _SearchPickerSheetState<T> extends State<_SearchPickerSheet<T>> {
  String _query = '';

  List<T> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.items;
    return widget.items.where((item) => widget.matcher(item, q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final media = MediaQuery.of(context);
    final keyboardHeight = media.viewInsets.bottom;
    final maxListHeight = (media.size.height - keyboardHeight) * 0.42;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

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
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: TextField(
                  autofocus: true,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: widget.searchHint,
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
                    if (widget.clearLabel != null)
                      ListTile(
                        leading: Icon(AppIcons.x, color: secondaryColor),
                        title: Text(
                          widget.clearLabel!,
                          style: TextStyle(color: secondaryColor),
                        ),
                        onTap: () =>
                            Navigator.pop(context, const _ClearPick()),
                      ),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            'No results found',
                            style: TextStyle(color: secondaryColor),
                          ),
                        ),
                      )
                    else
                      ...filtered.map((item) {
                        final selected = widget.selected == item;
                        final subtitle = widget.subtitleBuilder(item);
                        return ListTile(
                          leading: Icon(widget.icon, color: secondaryColor),
                          title: Text(
                            widget.labelBuilder(item),
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
                              subtitle.isEmpty ? null : Text(subtitle),
                          trailing: selected
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: AppColors.primary,
                                )
                              : null,
                          onTap: () => Navigator.pop(context, item),
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
