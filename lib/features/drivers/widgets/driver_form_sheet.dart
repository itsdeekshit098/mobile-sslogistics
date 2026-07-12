import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../shared/utils/validated_field.dart';
import '../../../shared/widgets/form_error_banner.dart';
import '../../../shared/widgets/server_error_banner.dart';
import '../data/driver_models.dart';

/// Create + edit in one sheet (mirrors the web's single addDriverModal).
class DriverFormSheet extends StatefulWidget {
  final Driver? driver;
  final Future<void> Function(CreateDriverDto? create, UpdateDriverDto? update) onSubmit;

  const DriverFormSheet({super.key, this.driver, required this.onSubmit});

  @override
  State<DriverFormSheet> createState() => _DriverFormSheetState();
}

class _DriverFormSheetState extends State<DriverFormSheet> {
  late final _nameCtrl = TextEditingController(text: widget.driver?.name ?? '');
  late final _phoneCtrl = TextEditingController(text: widget.driver?.phone ?? '');
  late final _placeCtrl = TextEditingController(text: widget.driver?.place ?? '');
  late final _dlCtrl = TextEditingController(text: widget.driver?.dlNumber ?? '');
  late final _photoCtrl = TextEditingController(text: widget.driver?.photoUrl ?? '');

  final _nameKey = GlobalKey<FormFieldState>();
  final _nameFocus = FocusNode();
  final _phoneKey = GlobalKey<FormFieldState>();
  final _phoneFocus = FocusNode();

  bool _isSubmitting = false;
  int _errorCount = 0;
  // Shown as a banner inside the sheet rather than a SnackBar — a SnackBar
  // anchors to the screen underneath and renders hidden behind this modal
  // bottom sheet, so the user never sees it even though it technically fired.
  String? _serverError;

  List<ValidatedField> get _validatedFields => [
        ValidatedField(key: _nameKey, hasError: () => _nameCtrl.text.trim().isEmpty, focusNode: _nameFocus),
        ValidatedField(
          key: _phoneKey,
          hasError: () {
            final phone = _phoneCtrl.text.trim();
            return phone.isNotEmpty && !isValidDriverPhone(phone);
          },
          focusNode: _phoneFocus,
        ),
      ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _placeCtrl.dispose();
    _dlCtrl.dispose();
    _photoCtrl.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    _nameKey.currentState?.validate();
    _phoneKey.currentState?.validate();

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
    });

    setState(() => _isSubmitting = true);
    try {
      final name = _nameCtrl.text.trim();
      final phone = _phoneCtrl.text.trim();
      final place = _placeCtrl.text.trim();
      final dl = _dlCtrl.text.trim();
      final photo = _photoCtrl.text.trim();

      if (widget.driver == null) {
        await widget.onSubmit(
          CreateDriverDto(
            name: name,
            phone: phone.isEmpty ? null : phone,
            place: place.isEmpty ? null : place,
            dlNumber: dl.isEmpty ? null : dl,
            photoUrl: photo.isEmpty ? null : photo,
          ),
          null,
        );
      } else {
        await widget.onSubmit(
          null,
          UpdateDriverDto(
            id: widget.driver!.id,
            name: name,
            phone: phone,
            place: place,
            dlNumber: dl,
            photoUrl: photo,
          ),
        );
      }
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
    final isEdit = widget.driver != null;

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
                  isEdit ? 'Edit Driver' : 'Add Driver',
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
                  _Label('Name *'),
                  TextFormField(
                    key: _nameKey,
                    controller: _nameCtrl,
                    focusNode: _nameFocus,
                    decoration: _inputDecor(context, hint: 'Driver full name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 14),
                  _Label('Phone'),
                  TextFormField(
                    key: _phoneKey,
                    controller: _phoneCtrl,
                    focusNode: _phoneFocus,
                    keyboardType: TextInputType.phone,
                    decoration: _inputDecor(context, hint: 'e.g. 9876543210'),
                    validator: (v) {
                      final phone = (v ?? '').trim();
                      if (phone.isNotEmpty && !isValidDriverPhone(phone)) {
                        return 'Enter a valid 10-digit phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _Label('Place / Address'),
                  TextFormField(controller: _placeCtrl, decoration: _inputDecor(context)),
                  const SizedBox(height: 14),
                  _Label('DL Number'),
                  TextFormField(controller: _dlCtrl, decoration: _inputDecor(context)),
                  const SizedBox(height: 14),
                  _Label('Photo URL'),
                  TextFormField(
                    controller: _photoCtrl,
                    keyboardType: TextInputType.url,
                    decoration: _inputDecor(context, hint: 'https://...'),
                  ),
                  const SizedBox(height: 8),
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
                  : Text(isEdit ? 'Save Changes' : 'Add Driver'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRequired = text.endsWith(' *');
    final base = isRequired ? text.substring(0, text.length - 2) : text;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text.rich(
        TextSpan(
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
          children: [
            TextSpan(text: base),
            if (isRequired) const TextSpan(text: ' *', style: TextStyle(color: AppColors.error)),
          ],
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
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
    enabledBorder:
        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.error),
    ),
  );
}
