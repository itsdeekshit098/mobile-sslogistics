import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../shared/data/bank_account_models.dart';
import '../../../shared/data/entity_models.dart';
import '../../../shared/data/entity_repository.dart';
import '../../../shared/widgets/lookup_select_field.dart';
import '../../../shared/widgets/option_picker_sheet.dart';
import '../../../shared/widgets/search_picker_sheet.dart';
import '../../../shared/widgets/server_error_banner.dart';
import '../../../shared/widgets/tap_field.dart';

final _ifscRegex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
final _accountNumberRegex = RegExp(r'^[0-9]{6,20}$');

/// Create-only sheet, mirroring the web's `bankAccountModal.tsx`. Edit is not
/// wired on mobile yet — the loan and client forms only ever create an
/// account inline (both reuse this same sheet via their own onAddNew).
class BankAccountFormSheet extends StatefulWidget {
  final BankAccount? account;
  final Future<BankAccount> Function({
    required int holderEntityId,
    required String bankName,
    required String accountNumber,
    required String accountType,
    String? ifsc,
    String? branch,
    String? nickname,
    String? notes,
  }) onSubmit;

  const BankAccountFormSheet({super.key, this.account, required this.onSubmit});

  @override
  State<BankAccountFormSheet> createState() => _BankAccountFormSheetState();
}

class _BankAccountFormSheetState extends State<BankAccountFormSheet> {
  final _accountNumberCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  Entity? _holder;
  String? _bankName;
  String _accountType = 'SAVINGS';

  bool _submitting = false;
  String? _serverError;
  final Map<String, String> _fieldErrors = {};

  bool get _isEdit => widget.account != null;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    if (a != null) {
      _accountNumberCtrl.text = a.accountNumber;
      _ifscCtrl.text = a.ifsc ?? '';
      _branchCtrl.text = a.branch ?? '';
      _nicknameCtrl.text = a.nickname ?? '';
      _notesCtrl.text = a.notes ?? '';
      _bankName = a.bankName;
      _accountType = a.accountType;
      if (a.holderName != null) {
        _holder = Entity(
          id: a.holderEntityId,
          name: a.holderName!,
          entityKind: 'PERSON',
          relationship: 'INTERNAL',
          isActive: true,
        );
      }
    }
  }

  @override
  void dispose() {
    _accountNumberCtrl.dispose();
    _ifscCtrl.dispose();
    _branchCtrl.dispose();
    _nicknameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickHolder() async {
    final entities = await EntityRepository().fetchAll();
    if (!mounted) return;
    final result = await showSearchPicker<Entity>(
      context,
      title: 'Held by',
      icon: AppIcons.badge,
      items: entities,
      selected: _holder,
      searchHint: 'Search firms and people...',
      labelBuilder: (e) => e.name,
      subtitleBuilder: (e) => e.entityKind == 'FIRM' ? 'Firm' : 'Person',
      matcher: (e, q) => e.name.toLowerCase().contains(q),
    );
    if (!mounted || result == null) return;
    setState(() {
      _holder = result as Entity;
      _fieldErrors.remove('holder');
    });
  }

  Future<void> _pickAccountType() async {
    final result = await showOptionPicker<String>(
      context,
      title: 'Account Type',
      options: kAccountTypes,
      selected: _accountType,
      labelBuilder: accountTypeLabel,
    );
    if (result != null) setState(() => _accountType = result);
  }

  Future<void> _submit() async {
    final errors = <String, String>{};
    if (_holder == null) errors['holder'] = 'Holder is required';
    if (_bankName == null || _bankName!.isEmpty) errors['bankName'] = 'Bank is required';
    if (!_accountNumberRegex.hasMatch(_accountNumberCtrl.text.trim())) {
      errors['accountNumber'] = 'Enter a valid account number (6-20 digits)';
    }
    final ifsc = _ifscCtrl.text.trim().toUpperCase();
    if (ifsc.isNotEmpty && !_ifscRegex.hasMatch(ifsc)) {
      errors['ifsc'] = 'Enter a valid IFSC code';
    }

    if (errors.isNotEmpty) {
      setState(() => _fieldErrors
        ..clear()
        ..addAll(errors));
      return;
    }

    setState(() {
      _submitting = true;
      _serverError = null;
      _fieldErrors.clear();
    });

    try {
      final created = await widget.onSubmit(
        holderEntityId: _holder!.id,
        bankName: _bankName!,
        accountNumber: _accountNumberCtrl.text.trim(),
        accountType: _accountType,
        ifsc: ifsc.isEmpty ? null : ifsc,
        branch: _branchCtrl.text.trim().isEmpty ? null : _branchCtrl.text.trim(),
        nickname: _nicknameCtrl.text.trim().isEmpty ? null : _nicknameCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context, created);
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _serverError = e.toString().replaceFirst('Exception: ', '');
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
                      _isEdit ? 'Edit Bank Account' : 'Add Bank Account',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(AppIcons.x)),
                ],
              ),
            ),
            const Divider(height: 1),
            if (_serverError != null) ServerErrorBanner(message: _serverError!),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FormSection(
                      label: 'Held By *',
                      child: TapField(
                        value: _holder?.name ?? 'Select firm or person',
                        icon: AppIcons.badge,
                        muted: _holder == null,
                        hasError: _fieldErrors.containsKey('holder'),
                        onTap: _pickHolder,
                      ),
                      errorText: _fieldErrors['holder'],
                    ),
                    const SizedBox(height: 14),
                    FormSection(
                      label: 'Bank *',
                      child: LookupSelectField(
                        category: 'bank_name',
                        noun: 'bank',
                        value: _bankName,
                        placeholder: 'Select bank',
                        hasError: _fieldErrors.containsKey('bankName'),
                        onChanged: (v) => setState(() {
                          _bankName = v;
                          _fieldErrors.remove('bankName');
                        }),
                      ),
                      errorText: _fieldErrors['bankName'],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: FormSection(
                            label: 'Account Number *',
                            child: TextField(
                              controller: _accountNumberCtrl,
                              keyboardType: TextInputType.number,
                            ),
                            errorText: _fieldErrors['accountNumber'],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FormSection(
                            label: 'Type',
                            child: TapField(
                              value: accountTypeLabel(_accountType),
                              icon: AppIcons.creditCard,
                              onTap: _pickAccountType,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: FormSection(
                            label: 'IFSC',
                            child: TextField(
                              controller: _ifscCtrl,
                              textCapitalization: TextCapitalization.characters,
                            ),
                            errorText: _fieldErrors['ifsc'],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FormSection(
                            label: 'Branch',
                            child: TextField(controller: _branchCtrl),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    FormSection(
                      label: 'Nickname',
                      child: TextField(
                        controller: _nicknameCtrl,
                        decoration: const InputDecoration(hintText: 'e.g. Salary account'),
                      ),
                    ),
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
