import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobile_sslogistics/core/constants/app_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/models/vehicle_model.dart';
import '../../../shared/utils/validated_field.dart';
import '../../../shared/widgets/form_error_banner.dart';
import '../../../shared/widgets/server_error_banner.dart';
import '../../../shared/widgets/location_autocomplete_field.dart';
import '../../diesel/providers/vehicle_provider.dart';
import '../../external_trips/data/external_trip_models.dart' show Driver;
import '../../external_trips/providers/external_trip_provider.dart'
    show driversProvider;
import '../data/trip_booking_models.dart';
import '../providers/trip_booking_provider.dart';

final _phoneRegex = RegExp(r'^[6-9]\d{9}$');
final _apiDateFmt = DateFormat('yyyy-MM-dd');
final _displayDateFmt = DateFormat('dd MMM yyyy');

/// Create/edit form for a trip booking. When [booking] is null the sheet
/// creates a new booking; otherwise it edits it (only 'confirmed' bookings
/// are editable — enforced by the API's PUT contract).
class TripBookingFormSheet extends ConsumerStatefulWidget {
  final TripBooking? booking;

  const TripBookingFormSheet({super.key, this.booking});

  @override
  ConsumerState<TripBookingFormSheet> createState() => _TripBookingFormSheetState();
}

class _TripBookingFormSheetState extends ConsumerState<TripBookingFormSheet> {
  final _formKey = GlobalKey<FormState>();

  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  final _fromLocationCtrl = TextEditingController();
  final _toLocationCtrl = TextEditingController();
  final _seatingCapacityCtrl = TextEditingController();
  final _quotedAmountCtrl = TextEditingController();
  final _advanceAmountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Lets a failed submit scroll/focus back to the first invalid field.
  final _customerNameFieldKey = GlobalKey<FormFieldState>();
  final _customerNameFocus = FocusNode();
  final _customerPhoneFieldKey = GlobalKey<FormFieldState>();
  final _customerPhoneFocus = FocusNode();
  final _fromLocationFieldKey = GlobalKey<FormFieldState>();
  final _fromLocationFocus = FocusNode();
  final _toLocationFieldKey = GlobalKey<FormFieldState>();
  final _toLocationFocus = FocusNode();
  final _startDateSectionKey = GlobalKey();
  final _seatingCapacityFieldKey = GlobalKey<FormFieldState>();
  final _seatingCapacityFocus = FocusNode();
  int _errorCount = 0;
  // Shown as a banner inside the sheet rather than a SnackBar — a SnackBar
  // anchors to the screen underneath and renders hidden behind this modal
  // bottom sheet, so the user never sees it even though it technically fired.
  String? _serverError;

  String _vehicleType = vehicleTypeCar;
  DateTime? _startDate;
  DateTime? _endDate;
  Vehicle? _selectedVehicle;
  Driver? _selectedDriver;
  bool _isSubmitting = false;

  bool get _isEdit => widget.booking != null;
  bool get _showsSeatingCapacity => seatingCapacityVehicleTypes.contains(_vehicleType);

  @override
  void initState() {
    super.initState();
    final booking = widget.booking;
    if (booking != null) {
      _customerNameCtrl.text = booking.customerName;
      _customerPhoneCtrl.text = booking.customerPhone ?? '';
      _fromLocationCtrl.text = booking.fromLocation;
      _toLocationCtrl.text = booking.toLocation;
      _vehicleType = booking.vehicleType;
      _seatingCapacityCtrl.text = booking.seatingCapacity?.toString() ?? '';
      _quotedAmountCtrl.text = booking.quotedAmount != null ? _trimZeros(booking.quotedAmount!) : '';
      _advanceAmountCtrl.text = booking.advanceAmount == 0 ? '' : _trimZeros(booking.advanceAmount);
      _notesCtrl.text = booking.notes ?? '';
      _startDate = DateTime.tryParse(booking.startDate);
      _endDate = booking.endDate != null ? DateTime.tryParse(booking.endDate!) : null;
      if (booking.vehicleId != null) {
        _selectedVehicle = Vehicle(
          id: booking.vehicleId!,
          plateNumber: booking.vehicleNumber ?? 'Vehicle #${booking.vehicleId}',
        );
      }
      if (booking.driverId != null) {
        _selectedDriver = Driver(
          id: booking.driverId!,
          name: booking.driverName ?? 'Driver #${booking.driverId}',
          phone: booking.driverPhone,
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
      _seatingCapacityCtrl,
      _quotedAmountCtrl,
      _advanceAmountCtrl,
      _notesCtrl,
    ]) {
      c.dispose();
    }
    _customerNameFocus.dispose();
    _customerPhoneFocus.dispose();
    _fromLocationFocus.dispose();
    _toLocationFocus.dispose();
    _seatingCapacityFocus.dispose();
    super.dispose();
  }

  static String _trimZeros(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  Future<void> _pickVehicle(List<Vehicle> vehicles) async {
    final picked = await showModalBottomSheet<Object>(
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
        subtitleBuilder: (v) => [v.make, v.model].whereType<String>().join(' '),
        matcher: (v, q) =>
            [v.plateNumber, v.make, v.model].whereType<String>().join(' ').toLowerCase().contains(q),
        clearLabel: 'No vehicle',
      ),
    );
    if (picked == null) return;
    setState(() => _selectedVehicle = picked is Vehicle ? picked : null);
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
        matcher: (d, q) => '${d.name} ${d.phone ?? ''}'.toLowerCase().contains(q),
        clearLabel: 'No driver',
      ),
    );
    if (picked == null) return;
    setState(() => _selectedDriver = picked is Driver ? picked : null);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (picked != null) {
      setState(() => isStart ? _startDate = picked : _endDate = picked);
    }
  }

  void _swapLocations() {
    final from = _fromLocationCtrl.text;
    final to = _toLocationCtrl.text;
    setState(() {
      _fromLocationCtrl.text = to;
      _toLocationCtrl.text = from;
    });
  }

  void _snack(String message) {
    setState(() => _serverError = message);
  }

  List<ValidatedField> get _validatedFields => [
        ValidatedField(
          key: _customerNameFieldKey,
          hasError: () => _customerNameFieldKey.currentState?.hasError ?? false,
          focusNode: _customerNameFocus,
        ),
        ValidatedField(
          key: _customerPhoneFieldKey,
          hasError: () => _customerPhoneFieldKey.currentState?.hasError ?? false,
          focusNode: _customerPhoneFocus,
        ),
        ValidatedField(
          key: _fromLocationFieldKey,
          hasError: () => _fromLocationFieldKey.currentState?.hasError ?? false,
          focusNode: _fromLocationFocus,
        ),
        ValidatedField(
          key: _toLocationFieldKey,
          hasError: () => _toLocationFieldKey.currentState?.hasError ?? false,
          focusNode: _toLocationFocus,
        ),
        ValidatedField(
          key: _startDateSectionKey,
          hasError: () => _startDate == null,
        ),
        if (_showsSeatingCapacity)
          ValidatedField(
            key: _seatingCapacityFieldKey,
            hasError: () => _seatingCapacityFieldKey.currentState?.hasError ?? false,
            focusNode: _seatingCapacityFocus,
          ),
      ];

  Future<void> _submit() async {
    final formValid = _formKey.currentState!.validate();
    final noStartDate = _startDate == null;

    if (!formValid || noStartDate) {
      final fields = _validatedFields;
      setState(() => _errorCount = countFormErrors(fields));

      final scrolled = await scrollToFirstError(fields);
      if (noStartDate && !scrolled) {
        _snack('Please select a start date');
      }
      return;
    }

    if (_endDate != null && _startDate != null && _endDate!.isBefore(_startDate!)) {
      _snack('End date cannot be before start date');
      return;
    }

    setState(() {
      _errorCount = 0;
      _serverError = null;
      _isSubmitting = true;
    });

    final notifier = ref.read(tripBookingListProvider.notifier);
    final seatingCapacity =
        _showsSeatingCapacity ? int.tryParse(_seatingCapacityCtrl.text) : null;
    final quotedAmount = double.tryParse(_quotedAmountCtrl.text);
    final advanceAmount = double.tryParse(_advanceAmountCtrl.text) ?? 0;

    try {
      if (_isEdit) {
        await notifier.updateBooking(UpdateTripBookingDto(
          id: widget.booking!.id,
          customerName: _customerNameCtrl.text.trim(),
          customerPhone: _textOrNull(_customerPhoneCtrl),
          fromLocation: _fromLocationCtrl.text.trim(),
          toLocation: _toLocationCtrl.text.trim(),
          startDate: _apiDateFmt.format(_startDate!),
          endDate: _endDate != null ? _apiDateFmt.format(_endDate!) : null,
          vehicleType: _vehicleType,
          seatingCapacity: seatingCapacity,
          vehicleId: _selectedVehicle?.id,
          driverId: _selectedDriver?.id,
          quotedAmount: quotedAmount,
          advanceAmount: advanceAmount,
          notes: _textOrNull(_notesCtrl),
        ));
      } else {
        await notifier.createBooking(CreateTripBookingDto(
          customerName: _customerNameCtrl.text.trim(),
          customerPhone: _textOrNull(_customerPhoneCtrl),
          fromLocation: _fromLocationCtrl.text.trim(),
          toLocation: _toLocationCtrl.text.trim(),
          startDate: _apiDateFmt.format(_startDate!),
          endDate: _endDate != null ? _apiDateFmt.format(_endDate!) : null,
          vehicleType: _vehicleType,
          seatingCapacity: seatingCapacity,
          vehicleId: _selectedVehicle?.id,
          driverId: _selectedDriver?.id,
          quotedAmount: quotedAmount,
          advanceAmount: advanceAmount,
          notes: _textOrNull(_notesCtrl),
        ));
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'Booking updated' : 'Booking created'),
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
                  _isEdit ? 'Edit Booking' : 'New Trip Booking',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Customer ─────────────────────────────────────────
                    _Section(
                      label: 'Customer Name *',
                      child: TextFormField(
                        key: _customerNameFieldKey,
                        controller: _customerNameCtrl,
                        focusNode: _customerNameFocus,
                        decoration: _inputDecor(hint: 'Enter customer name'),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                    _Section(
                      label: 'From *',
                      child: LocationAutocompleteField(
                        fieldKey: _fromLocationFieldKey,
                        controller: _fromLocationCtrl,
                        focusNode: _fromLocationFocus,
                        decoration: _inputDecor(hint: 'Origin'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                    _RouteSwapButton(onTap: _swapLocations),
                    _Section(
                      label: 'To *',
                      child: LocationAutocompleteField(
                        fieldKey: _toLocationFieldKey,
                        controller: _toLocationCtrl,
                        focusNode: _toLocationFocus,
                        decoration: _inputDecor(hint: 'Destination'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Dates ────────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _Section(
                            key: _startDateSectionKey,
                            label: 'Start Date *',
                            child: _TapField(
                              value: _startDate != null
                                  ? _displayDateFmt.format(_startDate!)
                                  : 'Select date',
                              icon: AppIcons.calendar,
                              muted: _startDate == null,
                              onTap: () => _pickDate(isStart: true),
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

                    // ── Vehicle type & seating ───────────────────────────
                    _Section(
                      label: 'Vehicle Type *',
                      child: DropdownButtonFormField<String>(
                        initialValue: _vehicleType,
                        decoration: _inputDecor(),
                        items: vehicleTypeOptions
                            .map((o) => DropdownMenuItem(value: o.value, child: Text(o.label)))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _vehicleType = v;
                            if (!_showsSeatingCapacity) _seatingCapacityCtrl.clear();
                          });
                        },
                      ),
                    ),
                    if (_showsSeatingCapacity) ...[
                      const SizedBox(height: 14),
                      _Section(
                        label: 'Seating Capacity',
                        child: TextFormField(
                          key: _seatingCapacityFieldKey,
                          controller: _seatingCapacityCtrl,
                          focusNode: _seatingCapacityFocus,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecor(hint: 'e.g. 12'),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final n = int.tryParse(v.trim());
                            if (n == null || n <= 0) return 'Must be a positive number';
                            return null;
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),

                    // ── Vehicle & Driver (optional pre-assignment) ───────
                    _Section(
                      label: 'Vehicle',
                      child: vehiclesAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => const Text(
                          'Error loading vehicles',
                          style: TextStyle(color: AppColors.error),
                        ),
                        data: (vehicles) => _TapField(
                          value: _selectedVehicle?.plateNumber ?? 'Not assigned yet',
                          icon: AppIcons.truck,
                          muted: _selectedVehicle == null,
                          onTap: () => _pickVehicle(vehicles),
                          onClear: _selectedVehicle != null
                              ? () => setState(() => _selectedVehicle = null)
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _Section(
                      label: 'Driver',
                      child: driversAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => const Text(
                          'Error loading drivers',
                          style: TextStyle(color: AppColors.error),
                        ),
                        data: (drivers) => _TapField(
                          value: _selectedDriver?.name ?? 'Not assigned yet',
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

                    // ── Amounts ───────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _Section(
                            label: 'Quoted Amount (₹)',
                            child: TextFormField(
                              controller: _quotedAmountCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: _inputDecor(hint: 'e.g. 12000'),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return null;
                                final n = double.tryParse(v);
                                if (n == null || n < 0) return 'Must be 0 or more';
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Section(
                            label: 'Advance Amount (₹)',
                            child: TextFormField(
                              controller: _advanceAmountCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: _inputDecor(hint: 'e.g. 2000'),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return null;
                                final n = double.tryParse(v);
                                if (n == null || n < 0) return 'Must be 0 or more';
                                return null;
                              },
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
            padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).viewInsets.bottom),
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : Text(_isEdit ? 'Save Changes' : 'Create Booking'),
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

/// Small centered affordance between the From/To fields to swap their
/// values — sits in place of the side-by-side layout so each location
/// field gets the sheet's full width for its suggestion dropdown.
class _RouteSwapButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RouteSwapButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Center(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? AppColors.darkCardBg : Colors.white,
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
            ),
            child: Icon(
              Icons.swap_vert_rounded,
              size: 16,
              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
            ),
          ),
        ),
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
                const TextSpan(text: ' *', style: TextStyle(color: AppColors.error)),
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
                  color: muted
                      ? mutedColor
                      : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                ),
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(AppIcons.x, size: 16, color: mutedColor),
              )
            else
              Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: mutedColor),
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
    final secondaryColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
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
                decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2)),
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
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
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
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxListHeight.clamp(160.0, 420.0)),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (widget.clearLabel != null)
                      ListTile(
                        leading: Icon(AppIcons.x, color: secondaryColor),
                        title: Text(widget.clearLabel!, style: TextStyle(color: secondaryColor)),
                        onTap: () => Navigator.pop(context, const _ClearPick()),
                      ),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text('No results found', style: TextStyle(color: secondaryColor)),
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
                              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                              color: selected
                                  ? AppColors.primary
                                  : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                            ),
                          ),
                          subtitle: subtitle.isEmpty ? null : Text(subtitle),
                          trailing:
                              selected ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
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
