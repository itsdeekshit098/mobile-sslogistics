import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../shared/data/bank_account_models.dart';
import '../../../shared/data/bank_account_repository.dart';
import '../../../shared/data/entity_models.dart';
import '../../../shared/data/entity_repository.dart';
import '../../../shared/utils/money_format.dart';
import '../../../shared/widgets/lookup_select_field.dart';
import '../../../shared/widgets/search_picker_sheet.dart';
import '../../../shared/widgets/selectable_chip.dart';
import '../../../shared/widgets/server_error_banner.dart';
import '../../../shared/widgets/tap_field.dart';
import '../../bank_accounts/widgets/bank_account_form_sheet.dart';
import '../data/client_models.dart';

class ClientFormSheet extends StatefulWidget {
  final Client? client;
  final Future<void> Function({
    String? name,
    required String clientType,
    required String partyKind,
    int? entityId,
    int? receivingAccountId,
    String? location,
    String? address,
    String? gstNumber,
    String? notes,
    num? openingBalance,
    String? openingDate,
  }) onSubmit;

  const ClientFormSheet({super.key, this.client, required this.onSubmit});

  @override
  State<ClientFormSheet> createState() => _ClientFormSheetState();
}

class _ClientFormSheetState extends State<ClientFormSheet> {
  bool get _isEdit => widget.client != null;

  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _openingBalanceCtrl = TextEditingController();
  String _clientType = 'VENDOR';
  String _partyKind = 'COMPANY';
  Entity? _entity;
  List<Entity> _entities = [];
  bool _entitiesLoading = false;
  BankAccount? _bankAccount;
  List<BankAccount> _bankAccounts = [];
  bool _bankAccountsLoading = false;
  DateTime _openingDate = DateTime.now();

  bool get _isIndividual => _partyKind == 'INDIVIDUAL';

  bool _submitting = false;
  String? _error;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    final c = widget.client;
    if (c != null) {
      _nameCtrl.text = c.name;
      _clientType = c.clientType;
      _partyKind = c.partyKind;
      _locationCtrl.text = c.location ?? '';
      _addressCtrl.text = c.address ?? '';
      _gstCtrl.text = c.gstNumber ?? '';
      _notesCtrl.text = c.notes ?? '';
      if (c.entity != null) {
        _entity = Entity(
          id: c.entity!.id,
          name: c.entity!.name,
          entityKind: c.entity!.entityKind,
          relationship: 'INTERNAL',
          isActive: true,
        );
      }
    }
    if (_isIndividual) _loadEntities();
    _loadBankAccounts();
  }

  Future<void> _loadEntities() async {
    setState(() => _entitiesLoading = true);
    try {
      final entities = await EntityRepository().fetchAll();
      if (mounted) setState(() => _entities = entities);
    } finally {
      if (mounted) setState(() => _entitiesLoading = false);
    }
  }

  Future<void> _loadBankAccounts() async {
    // Both party kinds can pay into one of our accounts, so this loads
    // unconditionally rather than gating on _isIndividual like the entity list.
    setState(() => _bankAccountsLoading = true);
    try {
      final accounts = await BankAccountRepository().fetchAll(activeOnly: true);
      if (!mounted) return;
      setState(() {
        _bankAccounts = accounts;
        final receivingId = widget.client?.receivingAccountId;
        if (receivingId != null) {
          final match = accounts.where((a) => a.id == receivingId);
          if (match.isNotEmpty) _bankAccount = match.first;
        }
      });
    } finally {
      if (mounted) setState(() => _bankAccountsLoading = false);
    }
  }

  Future<void> _pickBankAccount() async {
    final result = await showSearchPicker<BankAccount>(
      context,
      title: 'Pays into',
      icon: AppIcons.creditCard,
      items: _bankAccounts,
      selected: _bankAccount,
      searchHint: 'Search accounts...',
      labelBuilder: (a) => a.displayLabel,
      subtitleBuilder: (a) => [a.ifsc, a.branch].where((v) => v != null && v.isNotEmpty).join(' · '),
      matcher: (a, q) =>
          a.bankName.toLowerCase().contains(q) ||
          a.accountNumber.contains(q) ||
          (a.nickname?.toLowerCase().contains(q) ?? false),
      clearLabel: 'None',
      isLoading: _bankAccountsLoading,
      addNewLabel: 'Add new account',
      onAddNew: () async {
        final created = await showModalBottomSheet<BankAccount>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (_) => FractionallySizedBox(
            heightFactor: 0.9,
            child: BankAccountFormSheet(
              onSubmit: ({
                required holderEntityId,
                required bankName,
                required accountNumber,
                required accountType,
                ifsc,
                branch,
                nickname,
                notes,
              }) =>
                  BankAccountRepository().create(
                holderEntityId: holderEntityId,
                bankName: bankName,
                accountNumber: accountNumber,
                accountType: accountType,
                ifsc: ifsc,
                branch: branch,
                nickname: nickname,
                notes: notes,
              ),
            ),
          ),
        );
        if (created != null && mounted) {
          setState(() {
            _bankAccounts = [..._bankAccounts, created];
            _bankAccount = created;
          });
        }
      },
    );
    if (!mounted || result == null) return;
    setState(() => _bankAccount = result is ClearPick ? null : result as BankAccount);
  }

  Future<void> _pickEntity() async {
    final result = await showSearchPicker<Entity>(
      context,
      title: 'Select person',
      icon: AppIcons.badge,
      items: _entities,
      selected: _entity,
      searchHint: 'Search firms and people...',
      labelBuilder: (e) => e.name,
      subtitleBuilder: (e) => e.entityKind == 'FIRM' ? 'Firm' : 'Person',
      matcher: (e, q) => e.name.toLowerCase().contains(q),
      isLoading: _entitiesLoading,
    );
    if (!mounted || result == null) return;
    setState(() {
      _entity = result as Entity;
      _nameError = null;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _addressCtrl.dispose();
    _gstCtrl.dispose();
    _notesCtrl.dispose();
    _openingBalanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _openingDate,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _openingDate = picked);
  }

  Future<void> _submit() async {
    if (_isIndividual) {
      if (_entity == null) {
        setState(() => _nameError = 'Select who this is');
        return;
      }
    } else if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _nameError = 'Company name is required');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _nameError = null;
    });

    final opening = num.tryParse(_openingBalanceCtrl.text);

    try {
      await widget.onSubmit(
        name: _isIndividual ? null : _nameCtrl.text.trim(),
        clientType: _clientType,
        partyKind: _partyKind,
        entityId: _isIndividual ? _entity!.id : null,
        receivingAccountId: _bankAccount?.id,
        location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        gstNumber: _isIndividual || _gstCtrl.text.trim().isEmpty ? null : _gstCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        openingBalance: _isEdit ? null : (opening != null && opening > 0 ? opening : null),
        openingDate: _isEdit ? null : formatApiDate(_openingDate),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'Client updated' : 'Client created'),
            backgroundColor: AppColors.success,
          ),
        );
      }
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
                      _isEdit ? 'Edit Client' : 'New Client',
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
            if (_error != null) ServerErrorBanner(message: _error!),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_isEdit) ...[
                      Row(
                        children: [
                          SelectableChip(
                            label: 'Company',
                            selected: !_isIndividual,
                            onTap: () => setState(() => _partyKind = 'COMPANY'),
                          ),
                          const SizedBox(width: 8),
                          SelectableChip(
                            label: 'Individual',
                            selected: _isIndividual,
                            onTap: () {
                              setState(() => _partyKind = 'INDIVIDUAL');
                              if (_entities.isEmpty) _loadEntities();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (_isIndividual)
                      FormSection(
                        label: 'Person *',
                        child: TapField(
                          value: _entity?.name ?? 'Select person',
                          icon: AppIcons.badge,
                          muted: _entity == null,
                          hasError: _nameError != null,
                          onTap: _pickEntity,
                        ),
                        errorText: _nameError,
                      )
                    else
                      FormSection(
                        label: 'Company Name *',
                        child: TextField(controller: _nameCtrl, autofocus: !_isEdit),
                        errorText: _nameError,
                      ),
                    const SizedBox(height: 14),
                    FormSection(
                      label: 'Type',
                      child: LookupSelectField(
                        category: 'client_type',
                        noun: 'client type',
                        value: _clientType,
                        onChanged: (v) => setState(() => _clientType = v ?? 'VENDOR'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FormSection(label: 'Location', child: TextField(controller: _locationCtrl)),
                    const SizedBox(height: 14),
                    FormSection(label: 'Address', child: TextField(controller: _addressCtrl)),
                    if (!_isIndividual) ...[
                      const SizedBox(height: 14),
                      FormSection(
                        label: 'GST Number',
                        child: TextField(
                          controller: _gstCtrl,
                          textCapitalization: TextCapitalization.characters,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    FormSection(
                      label: 'Pays into',
                      child: TapField(
                        value: _bankAccount?.displayLabel ?? 'Which account do they pay into?',
                        icon: AppIcons.creditCard,
                        muted: _bankAccount == null,
                        onTap: _pickBankAccount,
                        onClear: _bankAccount != null ? () => setState(() => _bankAccount = null) : null,
                      ),
                    ),
                    if (!_isEdit) ...[
                      const SizedBox(height: 14),
                      FormSection(
                        label: 'Opening Balance (₹)',
                        child: TextField(
                          controller: _openingBalanceCtrl,
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(hintText: 'What they already owe'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      if (_openingBalanceCtrl.text.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        FormSection(
                          label: 'As Of',
                          child: TapField(
                            value: formatDisplayDate(formatApiDate(_openingDate)),
                            icon: AppIcons.calendar,
                            onTap: _pickDate,
                          ),
                        ),
                      ],
                    ],
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
                // Blocked while bank accounts are still loading: on edit, the
                // client's existing receivingAccountId is only resolved into
                // _bankAccount once _loadBankAccounts() finishes — saving
                // before that resolves would send null and silently clear it.
                onPressed: (_submitting || _bankAccountsLoading) ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text(_isEdit ? 'Save Changes' : 'Save Client'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
