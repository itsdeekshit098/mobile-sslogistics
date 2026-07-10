import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../shared/utils/validated_field.dart';
import '../../../shared/widgets/form_error_banner.dart';
import '../../../shared/widgets/selectable_chip.dart';
import '../data/technician_models.dart';
import '../providers/technicians_provider.dart';

/// Create + edit in one sheet (mirrors the web's single addTechnicianModal),
/// including the specialization multi-select chips with inline "add new".
class TechnicianFormSheet extends ConsumerStatefulWidget {
  final Technician? technician;
  final Future<void> Function(CreateTechnicianDto? create, UpdateTechnicianDto? update) onSubmit;

  const TechnicianFormSheet({super.key, this.technician, required this.onSubmit});

  @override
  ConsumerState<TechnicianFormSheet> createState() => _TechnicianFormSheetState();
}

class _TechnicianFormSheetState extends ConsumerState<TechnicianFormSheet> {
  late final _nameCtrl = TextEditingController(text: widget.technician?.name ?? '');
  late final _phoneCtrl = TextEditingController(text: widget.technician?.phone ?? '');
  late final _locationCtrl = TextEditingController(text: widget.technician?.location ?? '');
  final _newSpecCtrl = TextEditingController();

  late final List<String> _selectedSpecs = List.of(widget.technician?.specializations ?? const []);

  final _nameKey = GlobalKey<FormFieldState>();
  final _nameFocus = FocusNode();
  final _phoneKey = GlobalKey<FormFieldState>();
  final _phoneFocus = FocusNode();
  final _specsSectionKey = GlobalKey();

  bool _isSubmitting = false;
  bool _addingSpec = false;
  int _errorCount = 0;

  List<ValidatedField> get _validatedFields => [
        ValidatedField(key: _nameKey, hasError: () => _nameCtrl.text.trim().isEmpty, focusNode: _nameFocus),
        ValidatedField(
          key: _phoneKey,
          hasError: () {
            final phone = _phoneCtrl.text.trim();
            return phone.isNotEmpty && !isValidTechnicianPhone(phone);
          },
          focusNode: _phoneFocus,
        ),
        ValidatedField(key: _specsSectionKey, hasError: () => _selectedSpecs.isEmpty),
      ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _newSpecCtrl.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  Future<void> _addSpecialization() async {
    final name = _newSpecCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _addingSpec = true);
    try {
      final repo = ref.read(technicianRepositoryProvider);
      await repo.createSpecialization(name);
      ref.invalidate(specializationOptionsProvider);
      setState(() {
        if (!_selectedSpecs.contains(name)) _selectedSpecs.add(name);
        _newSpecCtrl.clear();
        _addingSpec = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _addingSpec = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
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
    setState(() => _errorCount = 0);

    setState(() => _isSubmitting = true);
    try {
      final name = _nameCtrl.text.trim();
      final phone = _phoneCtrl.text.trim();
      final location = _locationCtrl.text.trim();

      if (widget.technician == null) {
        await widget.onSubmit(
          CreateTechnicianDto(
            name: name,
            phone: phone.isEmpty ? null : phone,
            location: location.isEmpty ? null : location,
            specializations: _selectedSpecs,
          ),
          null,
        );
      } else {
        await widget.onSubmit(
          null,
          UpdateTechnicianDto(
            id: widget.technician!.id,
            name: name,
            phone: phone,
            location: location,
            specializations: _selectedSpecs,
          ),
        );
      }
      if (mounted) Navigator.pop(context);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEdit = widget.technician != null;
    final optionsAsync = ref.watch(specializationOptionsProvider);

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
                  isEdit ? 'Edit Technician' : 'Add Technician',
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
                    decoration: _inputDecor(context, hint: 'Technician full name'),
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
                      if (phone.isNotEmpty && !isValidTechnicianPhone(phone)) {
                        return 'Enter a valid 10-digit phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _Label('Location'),
                  TextFormField(controller: _locationCtrl, decoration: _inputDecor(context)),
                  const SizedBox(height: 14),
                  Container(key: _specsSectionKey, child: _Label('Specializations *')),
                  optionsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text(
                      'Failed to load specializations',
                      style: TextStyle(color: AppColors.error, fontSize: 12.5),
                    ),
                    data: (options) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: options.map((opt) {
                        final selected = _selectedSpecs.contains(opt.name);
                        return SelectableChip(
                          label: opt.name,
                          selected: selected,
                          onTap: () => setState(() {
                            if (selected) {
                              _selectedSpecs.remove(opt.name);
                            } else {
                              _selectedSpecs.add(opt.name);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newSpecCtrl,
                          decoration: _inputDecor(context, hint: 'Add new specialization'),
                          onSubmitted: (_) => _addSpecialization(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _addingSpec ? null : _addSpecialization,
                        icon: _addingSpec
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(AppIcons.plus),
                      ),
                    ],
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
                  : Text(isEdit ? 'Save Changes' : 'Add Technician'),
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
