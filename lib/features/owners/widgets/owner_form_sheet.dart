import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../shared/utils/validated_field.dart';
import '../../../shared/widgets/form_error_banner.dart';
import '../../../shared/widgets/server_error_banner.dart';
import '../data/owner_models.dart';

/// Create + edit in one sheet (mirrors the web's single addVehicleOwnerModal).
class OwnerFormSheet extends StatefulWidget {
  final VehicleOwner? owner;
  final Future<void> Function(CreateOwnerDto? create, UpdateOwnerDto? update) onSubmit;

  const OwnerFormSheet({super.key, this.owner, required this.onSubmit});

  @override
  State<OwnerFormSheet> createState() => _OwnerFormSheetState();
}

class _OwnerFormSheetState extends State<OwnerFormSheet> {
  late final _nameCtrl = TextEditingController(text: widget.owner?.name ?? '');
  late String _ownerType = widget.owner?.ownerType ?? ownerTypeOwn;

  final _nameKey = GlobalKey<FormFieldState>();
  final _nameFocus = FocusNode();

  bool _isSubmitting = false;
  int _errorCount = 0;
  // Shown as a banner inside the sheet rather than a SnackBar — a SnackBar
  // anchors to the screen underneath and renders hidden behind this modal
  // bottom sheet, so the user never sees it even though it technically fired.
  String? _serverError;

  List<ValidatedField> get _validatedFields => [
        ValidatedField(key: _nameKey, hasError: () => _nameCtrl.text.trim().isEmpty, focusNode: _nameFocus),
      ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    _nameKey.currentState?.validate();

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
      if (widget.owner == null) {
        await widget.onSubmit(CreateOwnerDto(name: name, ownerType: _ownerType), null);
      } else {
        await widget.onSubmit(
          null,
          UpdateOwnerDto(id: widget.owner!.id, name: name, ownerType: _ownerType),
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
    final isEdit = widget.owner != null;

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
                  isEdit ? 'Edit Owner' : 'Add Owner',
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
                  _Label('Owner Type *'),
                  Row(
                    children: [ownerTypeOwn, ownerTypeExternal].map((type) {
                      final isSelected = _ownerType == type;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: type == ownerTypeOwn ? 8 : 0),
                          child: InkWell(
                            onTap: () => setState(() => _ownerType = type),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : (isDark ? AppColors.darkCardBg : Colors.white),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : (isDark ? AppColors.darkBorder : AppColors.border),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  ownerTypeLabels[type]!,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
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
                  const SizedBox(height: 14),
                  _Label('Owner Name *'),
                  TextFormField(
                    key: _nameKey,
                    controller: _nameCtrl,
                    focusNode: _nameFocus,
                    decoration: _inputDecor(context, hint: 'Owner name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
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
                  : Text(isEdit ? 'Save Changes' : 'Add Owner'),
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
