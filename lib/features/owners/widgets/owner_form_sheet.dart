import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../shared/data/entity_models.dart';
import '../../../shared/data/entity_repository.dart';
import '../../../shared/widgets/option_picker_sheet.dart';
import '../../../shared/widgets/search_picker_sheet.dart';
import '../../../shared/widgets/server_error_banner.dart';
import '../../../shared/widgets/tap_field.dart';

final _phoneRegex = RegExp(r'^[6-9]\d{9}$');
final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Create + edit in one sheet, mirroring the web's `entityModal.tsx`. A firm
/// can point at its proprietor (a person); a person never carries one — the
/// server enforces this too, but the field is hidden here to avoid asking a
/// question that has no answer.
class OwnerFormSheet extends StatefulWidget {
  final Entity? entity;
  final Future<void> Function({
    required String name,
    required String entityKind,
    required String relationship,
    int? proprietorEntityId,
    required bool clearProprietor,
    String? phone,
    String? email,
    String? pan,
    String? gstNumber,
    String? address,
    String? notes,
  }) onSubmit;

  const OwnerFormSheet({super.key, this.entity, required this.onSubmit});

  @override
  State<OwnerFormSheet> createState() => _OwnerFormSheetState();
}

class _OwnerFormSheetState extends State<OwnerFormSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _entityKind = 'FIRM';
  String _relationship = 'INTERNAL';
  Entity? _proprietor;

  List<Entity> _people = [];
  bool _peopleLoading = false;

  bool _submitting = false;
  String? _error;
  final Map<String, String> _fieldErrors = {};

  bool get _isEdit => widget.entity != null;
  bool get _isFirm => _entityKind == 'FIRM';

  @override
  void initState() {
    super.initState();
    final e = widget.entity;
    if (e != null) {
      _nameCtrl.text = e.name;
      _entityKind = e.entityKind;
      _relationship = e.relationship;
      _phoneCtrl.text = e.phone ?? '';
      _emailCtrl.text = e.email ?? '';
      _panCtrl.text = e.pan ?? '';
      _gstCtrl.text = e.gstNumber ?? '';
      _addressCtrl.text = e.address ?? '';
      _notesCtrl.text = e.notes ?? '';
      if (e.proprietorEntityId != null) {
        _proprietor = Entity(
          id: e.proprietorEntityId!,
          name: e.proprietorName ?? '',
          entityKind: 'PERSON',
          relationship: 'INTERNAL',
          isActive: true,
        );
      }
    }
    if (_isFirm) _loadPeople();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _panCtrl.dispose();
    _gstCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPeople() async {
    if (_peopleLoading || _people.isNotEmpty) return;
    setState(() => _peopleLoading = true);
    try {
      final people = await EntityRepository().fetchAll(entityKind: 'PERSON');
      if (mounted) setState(() => _people = people);
    } finally {
      if (mounted) setState(() => _peopleLoading = false);
    }
  }

  Future<void> _pickKind() async {
    final result = await showOptionPicker<String>(
      context,
      title: 'Firm or Person',
      options: kEntityKinds,
      selected: _entityKind,
      labelBuilder: entityKindLabel,
    );
    if (result != null) {
      setState(() {
        _entityKind = result;
        if (result == 'PERSON') _proprietor = null;
      });
      if (result == 'FIRM') _loadPeople();
    }
  }

  Future<void> _pickProprietor() async {
    final result = await showSearchPicker<Entity>(
      context,
      title: 'Proprietor',
      icon: AppIcons.badge,
      items: _people,
      selected: _proprietor,
      searchHint: 'Search people...',
      labelBuilder: (e) => e.name,
      subtitleBuilder: (_) => '',
      matcher: (e, q) => e.name.toLowerCase().contains(q),
      clearLabel: 'None',
      isLoading: _peopleLoading,
    );
    if (!mounted || result == null) return;
    setState(() => _proprietor = result is ClearPick ? null : result as Entity);
  }

  Future<void> _submit() async {
    final errors = <String, String>{};
    if (_nameCtrl.text.trim().isEmpty) errors['name'] = 'Name is required';
    if (_phoneCtrl.text.trim().isNotEmpty && !_phoneRegex.hasMatch(_phoneCtrl.text.trim())) {
      errors['phone'] = 'Enter a valid 10-digit mobile number';
    }
    if (_emailCtrl.text.trim().isNotEmpty && !_emailRegex.hasMatch(_emailCtrl.text.trim())) {
      errors['email'] = 'Enter a valid email address';
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
        name: _nameCtrl.text.trim(),
        entityKind: _entityKind,
        relationship: _relationship,
        proprietorEntityId: _isFirm ? _proprietor?.id : null,
        clearProprietor: !_isFirm || _proprietor == null,
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        pan: _panCtrl.text.trim().isEmpty ? null : _panCtrl.text.trim(),
        gstNumber: _gstCtrl.text.trim().isEmpty ? null : _gstCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
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
                      _isEdit ? 'Edit Entity' : 'New Firm or Person',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    // Disabled mid-submit: closing here doesn't cancel the
                    // in-flight create/update — it's already running against
                    // a captured `ref.read(...)` — it would just hide the
                    // sheet while the request completes behind it with no
                    // feedback, making a save look cancelled when it wasn't.
                    onPressed: _submitting ? null : () => Navigator.pop(context),
                    icon: const Icon(AppIcons.x),
                  ),
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
                    FormSection(
                      label: 'Name *',
                      child: TextField(
                        controller: _nameCtrl,
                        autofocus: !_isEdit,
                        decoration: const InputDecoration(hintText: 'e.g. SS LOGISTICS - DEEKSHITH'),
                      ),
                      errorText: _fieldErrors['name'],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: FormSection(
                            label: 'Type *',
                            child: TapField(
                              value: entityKindLabel(_entityKind),
                              icon: AppIcons.badge,
                              onTap: _pickKind,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FormSection(
                            label: 'Relationship',
                            child: TapField(
                              value: entityRelationshipLabel(_relationship),
                              icon: AppIcons.building2,
                              onTap: () => setState(() =>
                                  _relationship = _relationship == 'INTERNAL' ? 'EXTERNAL' : 'INTERNAL'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_isFirm) ...[
                      const SizedBox(height: 14),
                      FormSection(
                        label: 'Proprietor',
                        child: TapField(
                          value: _proprietor?.name ?? 'Select proprietor (optional)',
                          icon: AppIcons.badge,
                          muted: _proprietor == null,
                          onTap: _pickProprietor,
                          onClear: _proprietor != null ? () => setState(() => _proprietor = null) : null,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: FormSection(
                            label: 'Phone',
                            child: TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone),
                            errorText: _fieldErrors['phone'],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FormSection(
                            label: 'Email',
                            child: TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress),
                            errorText: _fieldErrors['email'],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FormSection(
                            label: 'PAN',
                            child: TextField(
                              controller: _panCtrl,
                              textCapitalization: TextCapitalization.characters,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FormSection(
                            label: 'GST Number',
                            child: TextField(
                              controller: _gstCtrl,
                              textCapitalization: TextCapitalization.characters,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    FormSection(label: 'Address', child: TextField(controller: _addressCtrl)),
                    const SizedBox(height: 14),
                    FormSection(
                      label: 'Notes',
                      child: TextField(controller: _notesCtrl, maxLength: 500, maxLines: 3),
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
                    : Text(_isEdit ? 'Save Changes' : 'Add'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
