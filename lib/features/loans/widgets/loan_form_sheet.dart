import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../shared/data/bank_account_models.dart';
import '../../../shared/data/bank_account_repository.dart';
import '../../bank_accounts/widgets/bank_account_form_sheet.dart';
import '../../../shared/data/entity_models.dart';
import '../../../shared/data/entity_repository.dart';
import '../../../shared/data/lender_models.dart';
import '../../../shared/data/lender_repository.dart';
import '../../../shared/models/vehicle_model.dart';
import '../../../shared/widgets/lookup_select_field.dart';
import '../../../shared/widgets/option_picker_sheet.dart';
import '../../../shared/widgets/search_picker_sheet.dart';
import '../../../shared/widgets/server_error_banner.dart';
import '../../../shared/widgets/tap_field.dart';
import '../../../shared/utils/money_format.dart';
import '../../diesel/providers/vehicle_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/loan_models.dart';

/// Full create/edit form — 15 fields, matching the web `loanModal.tsx` exactly
/// so a loan looks and validates the same whether it was entered from a
/// desk or from the yard. Money is never computed here: EMI schedule
/// generation happens server-side on submit.
class LoanFormSheet extends ConsumerStatefulWidget {
  final Loan? loan;
  final Future<void> Function(LoanDto dto) onSubmit;

  const LoanFormSheet({super.key, this.loan, required this.onSubmit});

  @override
  ConsumerState<LoanFormSheet> createState() => _LoanFormSheetState();
}

class _LoanFormSheetState extends ConsumerState<LoanFormSheet> {
  bool get _isEdit => widget.loan != null;

  String? _loanType;
  Entity? _borrower;
  Lender? _lender;
  Vehicle? _vehicle;
  BankAccount? _debitAccount;
  String? _mandateType;

  final _loanNumberCtrl = TextEditingController();
  final _collateralCtrl = TextEditingController();
  final _principalCtrl = TextEditingController();
  final _disbursedCtrl = TextEditingController();
  final _interestRateCtrl = TextEditingController();
  final _processingFeeCtrl = TextEditingController();
  final _emiAmountCtrl = TextEditingController();
  final _emiDayCtrl = TextEditingController();
  final _totalInstallmentsCtrl = TextEditingController();
  final _outstandingOverrideCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime? _startDate;
  DateTime? _firstEmiDate;

  List<Entity> _entities = [];
  List<Lender> _lenders = [];
  List<BankAccount> _bankAccounts = [];
  bool _optionsLoading = true;

  bool _submitting = false;
  String? _serverError;
  final Map<String, String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    final loan = widget.loan;
    _loanType = loan?.loanType;
    _loanNumberCtrl.text = loan?.loanNumber ?? '';
    _mandateType = loan?.mandateType;
    _collateralCtrl.text = loan?.collateralDescription ?? '';
    _principalCtrl.text = loan != null ? loan.principalAmount.toString() : '';
    _disbursedCtrl.text = loan?.disbursedAmount?.toString() ?? '';
    _interestRateCtrl.text = loan?.interestRate?.toString() ?? '';
    _processingFeeCtrl.text = loan?.processingFee?.toString() ?? '';
    _emiAmountCtrl.text = loan != null ? loan.emiAmount.toString() : '';
    _emiDayCtrl.text = loan != null ? loan.emiDayOfMonth.toString() : '';
    _totalInstallmentsCtrl.text = loan != null ? loan.totalInstallments.toString() : '';
    _outstandingOverrideCtrl.text = loan?.outstandingOverride?.toString() ?? '';
    _notesCtrl.text = loan?.notes ?? '';
    _startDate = loan != null ? DateTime.tryParse(loan.startDate) : null;
    _firstEmiDate = loan != null ? DateTime.tryParse(loan.firstEmiDate) : null;
    _loadOptions();
  }

  @override
  void dispose() {
    _loanNumberCtrl.dispose();
    _collateralCtrl.dispose();
    _principalCtrl.dispose();
    _disbursedCtrl.dispose();
    _interestRateCtrl.dispose();
    _processingFeeCtrl.dispose();
    _emiAmountCtrl.dispose();
    _emiDayCtrl.dispose();
    _totalInstallmentsCtrl.dispose();
    _outstandingOverrideCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final entities = await EntityRepository().fetchAll();
      final lenders = await LenderRepository().fetchAll(lenderKind: 'INSTITUTION');
      // On edit, the loan's own debit account must appear even if it's since
      // been deactivated — otherwise the lookup below silently misses it and
      // an unrelated save clears the mandate. New loans still only offer
      // active accounts.
      final bankAccounts =
          await BankAccountRepository().fetchAll(activeOnly: widget.loan == null);
      final vehicles = await ref.read(vehiclesProvider.future);
      if (!mounted) return;
      setState(() {
        _entities = entities;
        _lenders = lenders;
        _bankAccounts = bankAccounts;
        if (widget.loan != null) {
          final b = entities.where((e) => e.id == widget.loan!.borrowerEntityId);
          if (b.isNotEmpty) _borrower = b.first;
          if (widget.loan!.lenderId != null) {
            final l = lenders.where((e) => e.id == widget.loan!.lenderId);
            if (l.isNotEmpty) _lender = l.first;
          }
          if (widget.loan!.debitAccountId != null) {
            final a = bankAccounts.where((e) => e.id == widget.loan!.debitAccountId);
            if (a.isNotEmpty) _debitAccount = a.first;
          }
          if (widget.loan!.vehicleId != null) {
            final v = vehicles.where((e) => e.id == widget.loan!.vehicleId);
            if (v.isNotEmpty) _vehicle = v.first;
          }
        }
        _optionsLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _optionsLoading = false;
          _serverError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _pickBorrower() async {
    final result = await showSearchPicker<Entity>(
      context,
      title: 'Select borrower',
      icon: AppIcons.building2,
      items: _entities,
      selected: _borrower,
      searchHint: 'Search firms and people...',
      labelBuilder: (e) => e.name,
      subtitleBuilder: (e) => e.entityKind == 'FIRM' ? 'Firm' : 'Person',
      matcher: (e, q) => e.name.toLowerCase().contains(q),
      isLoading: _optionsLoading,
    );
    if (!mounted || result == null) return;
    setState(() {
      _borrower = result as Entity;
      _fieldErrors.remove('borrower');
    });
  }

  Future<void> _pickLender() async {
    final result = await showSearchPicker<Lender>(
      context,
      title: 'Select lender',
      icon: AppIcons.landmark,
      items: _lenders,
      selected: _lender,
      searchHint: 'Search lenders...',
      labelBuilder: (l) => l.name,
      subtitleBuilder: (l) => l.phone ?? '',
      matcher: (l, q) => l.name.toLowerCase().contains(q),
      clearLabel: 'No lender',
      isLoading: _optionsLoading,
    );
    if (!mounted || result == null) return;
    setState(() => _lender = result is ClearPick ? null : result as Lender);
  }

  Future<void> _pickVehicle() async {
    final vehicles = await ref.read(vehiclesProvider.future);
    if (!mounted) return;
    final result = await showSearchPicker<Vehicle>(
      context,
      title: 'Select vehicle (collateral)',
      icon: AppIcons.truck,
      items: vehicles,
      selected: _vehicle,
      searchHint: 'Search vehicles...',
      labelBuilder: (v) => v.plateNumber,
      subtitleBuilder: (v) => v.model ?? '',
      matcher: (v, q) =>
          v.plateNumber.toLowerCase().contains(q) ||
          (v.model?.toLowerCase().contains(q) ?? false),
      clearLabel: 'No vehicle',
    );
    if (!mounted || result == null) return;
    setState(() => _vehicle = result is ClearPick ? null : result as Vehicle);
  }

  Future<void> _pickDebitAccount() async {
    final result = await showSearchPicker<BankAccount>(
      context,
      title: 'Auto-debit from',
      icon: AppIcons.creditCard,
      items: _bankAccounts,
      selected: _debitAccount,
      searchHint: 'Search accounts...',
      labelBuilder: (a) => a.displayLabel,
      subtitleBuilder: (a) => [a.ifsc, a.branch].where((v) => v != null && v.isNotEmpty).join(' · '),
      matcher: (a, q) =>
          a.bankName.toLowerCase().contains(q) ||
          a.accountNumber.contains(q) ||
          (a.nickname?.toLowerCase().contains(q) ?? false),
      clearLabel: 'None',
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
            _debitAccount = created;
          });
        }
      },
    );
    if (!mounted || result == null) return;
    setState(() => _debitAccount = result is ClearPick ? null : result as BankAccount);
  }

  Future<void> _pickMandate() async {
    final result = await showOptionPicker<String>(
      context,
      title: 'Mandate',
      options: kMandateTypes,
      selected: _mandateType,
      labelBuilder: mandateTypeLabel,
    );
    if (!mounted || result == null) return;
    setState(() => _mandateType = result);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _firstEmiDate) ?? now,
      firstDate: DateTime(2015),
      lastDate: DateTime(now.year + 10, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        _fieldErrors.remove('startDate');
        // The first EMI is almost always a month after disbursal, and the EMI
        // day follows from it — prefilled but always overridable, matching the
        // web modal's behaviour.
        if (_firstEmiDate == null) {
          final suggested = DateTime(picked.year, picked.month + 1, picked.day);
          _firstEmiDate = suggested;
          if (_emiDayCtrl.text.isEmpty) _emiDayCtrl.text = '${picked.day}';
        }
      } else {
        _firstEmiDate = picked;
        _fieldErrors.remove('firstEmiDate');
        if (_emiDayCtrl.text.isEmpty) _emiDayCtrl.text = '${picked.day}';
      }
    });
  }

  Future<void> _submit() async {
    final errors = <String, String>{};

    if (_loanType == null || _loanType!.isEmpty) errors['loanType'] = 'Loan type is required';
    if (_borrower == null) errors['borrower'] = 'Borrower is required';
    final principal = num.tryParse(_principalCtrl.text);
    if (principal == null || principal <= 0) errors['principal'] = 'Enter the principal amount';
    if (_startDate == null) errors['startDate'] = 'Start date is required';
    if (_firstEmiDate == null) errors['firstEmiDate'] = 'First EMI date is required';
    if (_startDate != null && _firstEmiDate != null && _firstEmiDate!.isBefore(_startDate!)) {
      errors['firstEmiDate'] = 'First EMI cannot be before the start date';
    }
    final emiAmount = num.tryParse(_emiAmountCtrl.text);
    if (emiAmount == null || emiAmount <= 0) errors['emiAmount'] = 'Enter the EMI amount';
    final emiDay = int.tryParse(_emiDayCtrl.text);
    if (emiDay == null || emiDay < 1 || emiDay > 31) {
      errors['emiDay'] = 'EMI day must be between 1 and 31';
    }
    final totalInstallments = int.tryParse(_totalInstallmentsCtrl.text);
    if (totalInstallments == null || totalInstallments < 1) {
      errors['totalInstallments'] = 'Enter the number of installments';
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

    final dto = LoanDto(
      loanType: _loanType!,
      borrowerEntityId: _borrower!.id,
      lenderId: _lender?.id,
      loanNumber: _loanNumberCtrl.text.trim().isEmpty ? null : _loanNumberCtrl.text.trim(),
      vehicleId: _vehicle?.id,
      collateralDescription:
          _collateralCtrl.text.trim().isEmpty ? null : _collateralCtrl.text.trim(),
      principalAmount: principal!,
      disbursedAmount: num.tryParse(_disbursedCtrl.text),
      interestRate: num.tryParse(_interestRateCtrl.text),
      processingFee: num.tryParse(_processingFeeCtrl.text),
      startDate: formatApiDate(_startDate!),
      firstEmiDate: formatApiDate(_firstEmiDate!),
      emiAmount: emiAmount!,
      emiDayOfMonth: emiDay!,
      totalInstallments: totalInstallments!,
      outstandingOverride: num.tryParse(_outstandingOverrideCtrl.text),
      debitAccountId: _debitAccount?.id,
      mandateType: _mandateType,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    try {
      await widget.onSubmit(dto);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'Loan updated' : 'Loan created'),
            backgroundColor: AppColors.success,
          ),
        );
      }
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
                      _isEdit ? 'Edit Loan' : 'New Loan',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(AppIcons.x),
                  ),
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
                      label: 'Loan Type *',
                      child: LookupSelectField(
                        category: 'loan_type',
                        noun: 'loan type',
                        value: _loanType,
                        placeholder: 'Select loan type',
                        hasError: _fieldErrors.containsKey('loanType'),
                        onChanged: (v) => setState(() {
                          _loanType = v;
                          _fieldErrors.remove('loanType');
                        }),
                      ),
                      errorText: _fieldErrors['loanType'],
                    ),
                    const SizedBox(height: 14),
                    FormSection(
                      label: 'Borrower *',
                      child: TapField(
                        value: _borrower?.name ?? 'Select borrower',
                        icon: AppIcons.building2,
                        muted: _borrower == null,
                        hasError: _fieldErrors.containsKey('borrower'),
                        enabled: !_optionsLoading,
                        onTap: _pickBorrower,
                      ),
                      errorText: _fieldErrors['borrower'],
                    ),
                    const SizedBox(height: 14),
                    FormSection(
                      label: 'Lender',
                      child: TapField(
                        value: _lender?.name ?? 'Select lender (optional)',
                        icon: AppIcons.landmark,
                        muted: _lender == null,
                        enabled: !_optionsLoading,
                        onTap: _pickLender,
                        onClear: _lender != null ? () => setState(() => _lender = null) : null,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FormSection(
                      label: 'Loan Number',
                      child: TextField(controller: _loanNumberCtrl),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "As printed on the lender's statement (LAN).",
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    FormSection(
                      label: 'Vehicle (collateral)',
                      child: TapField(
                        value: _vehicle?.plateNumber ?? 'Select vehicle (optional)',
                        icon: AppIcons.truck,
                        muted: _vehicle == null,
                        onTap: _pickVehicle,
                        onClear: _vehicle != null ? () => setState(() => _vehicle = null) : null,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FormSection(
                      label: 'Collateral Description',
                      child: TextField(
                        controller: _collateralCtrl,
                        decoration: const InputDecoration(hintText: 'e.g. Land survey no., gold weight'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FormSection(
                      label: 'Auto-debit from',
                      child: TapField(
                        value: _debitAccount?.displayLabel ?? 'Select account (optional)',
                        icon: AppIcons.creditCard,
                        muted: _debitAccount == null,
                        onTap: _pickDebitAccount,
                        onClear:
                            _debitAccount != null ? () => setState(() => _debitAccount = null) : null,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FormSection(
                      label: 'Mandate',
                      child: TapField(
                        value: _mandateType != null ? mandateTypeLabel(_mandateType) : 'None',
                        icon: AppIcons.badge,
                        muted: _mandateType == null,
                        onTap: _pickMandate,
                        onClear: _mandateType != null ? () => setState(() => _mandateType = null) : null,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: FormSection(
                            label: 'Principal Amount (₹) *',
                            child: TextField(
                              controller: _principalCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                errorText: null,
                                enabledBorder: _fieldErrors.containsKey('principal')
                                    ? OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: AppColors.error),
                                      )
                                    : null,
                              ),
                            ),
                            errorText: _fieldErrors['principal'],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FormSection(
                            label: 'Interest Rate (% p.a.)',
                            child: TextField(
                              controller: _interestRateCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                            label: 'Processing Fee (₹)',
                            child: TextField(
                              controller: _processingFeeCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FormSection(
                            label: 'Disbursed Amount (₹)',
                            child: TextField(
                              controller: _disbursedCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(hintText: 'If different from principal'),
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
                            label: 'Start Date *',
                            child: TapField(
                              value: _startDate != null
                                  ? formatDisplayDate(formatApiDate(_startDate!))
                                  : 'Select date',
                              icon: AppIcons.calendar,
                              muted: _startDate == null,
                              hasError: _fieldErrors.containsKey('startDate'),
                              onTap: () => _pickDate(isStart: true),
                            ),
                            errorText: _fieldErrors['startDate'],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FormSection(
                            label: 'First EMI Date *',
                            child: TapField(
                              value: _firstEmiDate != null
                                  ? formatDisplayDate(formatApiDate(_firstEmiDate!))
                                  : 'Select date',
                              icon: AppIcons.calendar,
                              muted: _firstEmiDate == null,
                              hasError: _fieldErrors.containsKey('firstEmiDate'),
                              onTap: () => _pickDate(isStart: false),
                            ),
                            errorText: _fieldErrors['firstEmiDate'],
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
                            label: 'EMI Day of Month *',
                            child: TextField(
                              controller: _emiDayCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(hintText: '1-31'),
                            ),
                            errorText: _fieldErrors['emiDay'],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FormSection(
                            label: 'EMI Amount (₹) *',
                            child: TextField(
                              controller: _emiAmountCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                            errorText: _fieldErrors['emiAmount'],
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
                            label: 'Total Installments *',
                            child: TextField(
                              controller: _totalInstallmentsCtrl,
                              keyboardType: TextInputType.number,
                            ),
                            errorText: _fieldErrors['totalInstallments'],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FormSection(
                            label: 'Outstanding Override (₹)',
                            child: TextField(
                              controller: _outstandingOverrideCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(hintText: 'Leave blank to auto-calc'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    FormSection(
                      label: 'Notes',
                      child: TextField(
                        controller: _notesCtrl,
                        maxLength: 500,
                        maxLines: 3,
                        decoration: const InputDecoration(hintText: 'Any additional details...'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
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
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text(_isEdit ? 'Save Changes' : 'Create Loan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
