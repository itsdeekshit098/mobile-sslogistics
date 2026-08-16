import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/lookup_select_field.dart';
import '../../../shared/widgets/server_error_banner.dart';
import '../../../shared/widgets/tap_field.dart';
import '../data/client_models.dart';

final _phoneRegex = RegExp(r'^[6-9]\d{9}$');

class ContactFormSheet extends StatefulWidget {
  final ClientContact? contact;
  final Future<void> Function({
    int? id,
    required String name,
    String? role,
    String? designation,
    String? phone,
    String? altPhone,
    String? email,
    bool isPrimary,
  }) onSubmit;

  const ContactFormSheet({super.key, this.contact, required this.onSubmit});

  @override
  State<ContactFormSheet> createState() => _ContactFormSheetState();
}

class _ContactFormSheetState extends State<ContactFormSheet> {
  final _nameCtrl = TextEditingController();
  final _designationCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _altPhoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String? _role;
  bool _isPrimary = false;

  bool _submitting = false;
  String? _error;
  final Map<String, String> _fieldErrors = {};

  bool get _isEdit => widget.contact != null;

  @override
  void initState() {
    super.initState();
    final c = widget.contact;
    if (c != null) {
      _nameCtrl.text = c.name;
      _designationCtrl.text = c.designation ?? '';
      _phoneCtrl.text = c.phone ?? '';
      _altPhoneCtrl.text = c.altPhone ?? '';
      _emailCtrl.text = c.email ?? '';
      _role = c.role;
      _isPrimary = c.isPrimary;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _designationCtrl.dispose();
    _phoneCtrl.dispose();
    _altPhoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final errors = <String, String>{};
    if (_nameCtrl.text.trim().isEmpty) errors['name'] = 'Name is required';
    if (_phoneCtrl.text.trim().isNotEmpty && !_phoneRegex.hasMatch(_phoneCtrl.text.trim())) {
      errors['phone'] = 'Enter a valid 10-digit mobile number';
    }
    if (_altPhoneCtrl.text.trim().isNotEmpty && !_phoneRegex.hasMatch(_altPhoneCtrl.text.trim())) {
      errors['altPhone'] = 'Enter a valid 10-digit mobile number';
    }

    if (errors.isNotEmpty) {
      setState(() => _fieldErrors
        ..clear()
        ..addAll(errors));
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _fieldErrors.clear();
    });

    try {
      await widget.onSubmit(
        id: widget.contact?.id,
        name: _nameCtrl.text.trim(),
        role: _role,
        designation: _designationCtrl.text.trim().isEmpty ? null : _designationCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        altPhone: _altPhoneCtrl.text.trim().isEmpty ? null : _altPhoneCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        isPrimary: _isPrimary,
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

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Material(
        color: isDark ? AppColors.darkCardBg : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isEdit ? 'Edit Contact' : 'Add Contact',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  ServerErrorBanner(message: _error!),
                  const SizedBox(height: 12),
                ],
                FormSection(
                  label: 'Name *',
                  child: TextField(controller: _nameCtrl, autofocus: !_isEdit),
                  errorText: _fieldErrors['name'],
                ),
                const SizedBox(height: 14),
                FormSection(
                  label: 'Role',
                  child: LookupSelectField(
                    category: 'contact_role',
                    noun: 'contact role',
                    value: _role,
                    placeholder: 'Select role',
                    clearable: true,
                    onChanged: (v) => setState(() => _role = v),
                  ),
                ),
                const SizedBox(height: 14),
                FormSection(
                  label: 'Designation',
                  child: TextField(controller: _designationCtrl),
                ),
                const SizedBox(height: 14),
                FormSection(
                  label: 'Phone',
                  child: TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone),
                  errorText: _fieldErrors['phone'],
                ),
                const SizedBox(height: 14),
                FormSection(
                  label: 'Alternate Phone',
                  child: TextField(controller: _altPhoneCtrl, keyboardType: TextInputType.phone),
                  errorText: _fieldErrors['altPhone'],
                ),
                const SizedBox(height: 14),
                FormSection(
                  label: 'Email',
                  child: TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _isPrimary,
                  onChanged: (v) => setState(() => _isPrimary = v ?? false),
                  title: const Text('Primary contact', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Replaces whoever is currently marked primary'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text(_isEdit ? 'Update' : 'Add'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
