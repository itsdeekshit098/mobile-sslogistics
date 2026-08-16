import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../shared/data/entity_models.dart';
import '../../../shared/data/entity_repository.dart';
import '../../../shared/data/lender_models.dart';
import '../../../shared/data/lender_repository.dart';
import '../../../shared/utils/money_format.dart';
import '../../../shared/widgets/search_picker_sheet.dart';
import '../../../shared/widgets/server_error_banner.dart';
import '../../../shared/widgets/tap_field.dart';
import '../data/funding_models.dart';

/// Opens a new funding — money borrowed from a private funder, or money lent
/// to an entity, depending on [direction]. The opening rate + opening
/// principal are captured together, matching the server, which refuses to
/// create a funding with neither.
class FundingFormSheet extends StatefulWidget {
  final String direction;
  final Future<void> Function(FundingDto dto) onSubmit;

  const FundingFormSheet({super.key, this.direction = 'BORROWED', required this.onSubmit});

  @override
  State<FundingFormSheet> createState() => _FundingFormSheetState();
}

class _FundingFormSheetState extends State<FundingFormSheet> {
  bool get _isLent => widget.direction == 'LENT';

  Lender? _funder;
  Entity? _counterpartyEntity;
  Entity? _borrower;
  String _interestMode = 'PERCENT';
  String _roiBasis = 'MONTHLY';
  DateTime _startDate = DateTime.now();

  final _amountCtrl = TextEditingController();
  final _roiCtrl = TextEditingController();
  final _fixedAmountCtrl = TextEditingController();
  final _interestDueDayCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  List<Lender> _funders = [];
  List<Entity> _entities = [];
  bool _optionsLoading = true;

  bool _submitting = false;
  String? _error;
  final Map<String, String> _fieldErrors = {};

  bool get _isPercent => _interestMode == 'PERCENT';

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _roiCtrl.dispose();
    _fixedAmountCtrl.dispose();
    _interestDueDayCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      // Private funders only — a bank doesn't lend at a hand-agreed monthly
      // rate, and mixing them in is how duplicate "HDFC" rows get created.
      final funders = await LenderRepository().fetchAll(lenderKind: 'PRIVATE');
      final entities = await EntityRepository().fetchAll();
      if (!mounted) return;
      setState(() {
        _funders = funders;
        _entities = entities;
        _optionsLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _optionsLoading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  /// What the agreed rate actually costs per month, before the user commits
  /// to it — the number they'll be reconciling against every month.
  num? get _monthlyPreview {
    final principal = num.tryParse(_amountCtrl.text);
    if (principal == null || principal <= 0) return null;
    if (_isPercent) {
      final rate = num.tryParse(_roiCtrl.text);
      if (rate == null) return null;
      final monthly = _roiBasis == 'ANNUAL' ? rate / 12 : rate;
      return principal * monthly / 100;
    }
    return num.tryParse(_fixedAmountCtrl.text);
  }

  Future<void> _pickFunder() async {
    final result = await showSearchPicker<Lender>(
      context,
      title: 'Select funder',
      icon: AppIcons.landmark,
      items: _funders,
      selected: _funder,
      searchHint: 'Search funders...',
      labelBuilder: (l) => l.name,
      subtitleBuilder: (l) => l.phone ?? '',
      matcher: (l, q) => l.name.toLowerCase().contains(q),
      isLoading: _optionsLoading,
    );
    if (!mounted || result == null) return;
    setState(() {
      _funder = result as Lender;
      _fieldErrors.remove('funder');
    });
  }

  Future<void> _pickCounterpartyEntity() async {
    final result = await showSearchPicker<Entity>(
      context,
      title: 'Select borrower',
      icon: AppIcons.building2,
      items: _entities,
      selected: _counterpartyEntity,
      searchHint: 'Search firms and people...',
      labelBuilder: (e) => e.name,
      subtitleBuilder: (e) => e.entityKind == 'FIRM' ? 'Firm' : 'Person',
      matcher: (e, q) => e.name.toLowerCase().contains(q),
      isLoading: _optionsLoading,
    );
    if (!mounted || result == null) return;
    setState(() {
      _counterpartyEntity = result as Entity;
      _fieldErrors.remove('counterparty');
    });
  }

  Future<void> _pickBorrower() async {
    final result = await showSearchPicker<Entity>(
      context,
      title: 'In whose name',
      icon: AppIcons.building2,
      items: _entities,
      selected: _borrower,
      searchHint: 'Search firms and people...',
      labelBuilder: (e) => e.name,
      subtitleBuilder: (e) => e.entityKind == 'FIRM' ? 'Firm' : 'Person',
      matcher: (e, q) => e.name.toLowerCase().contains(q),
      clearLabel: 'None',
      isLoading: _optionsLoading,
    );
    if (!mounted || result == null) return;
    setState(() => _borrower = result is ClearPick ? null : result as Entity);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _submit() async {
    final errors = <String, String>{};

    if (_isLent) {
      if (_counterpartyEntity == null) errors['counterparty'] = 'Borrower is required';
    } else {
      if (_funder == null) errors['funder'] = 'Funder is required';
    }
    final amount = num.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      errors['amount'] = _isLent ? 'Enter the amount lent' : 'Enter the amount borrowed';
    }
    if (_isPercent) {
      final roi = num.tryParse(_roiCtrl.text);
      if (roi == null || roi < 0) errors['roi'] = 'Enter the rate';
    } else {
      final fixed = num.tryParse(_fixedAmountCtrl.text);
      if (fixed == null || fixed < 0) errors['fixedAmount'] = 'Enter the monthly interest amount';
    }
    if (_interestDueDayCtrl.text.isNotEmpty) {
      final day = int.tryParse(_interestDueDayCtrl.text);
      if (day == null || day < 1 || day > 31) {
        errors['interestDueDay'] = 'Day must be between 1 and 31';
      }
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

    final dto = FundingDto(
      direction: widget.direction,
      funderId: _isLent ? null : _funder!.id,
      counterpartyEntityId: _isLent ? _counterpartyEntity!.id : null,
      borrowerEntityId: _borrower?.id,
      interestMode: _interestMode,
      amount: amount!,
      roi: _isPercent ? num.tryParse(_roiCtrl.text) : null,
      roiBasis: _isPercent ? _roiBasis : null,
      fixedInterestAmount: _isPercent ? null : num.tryParse(_fixedAmountCtrl.text),
      interestDueDay: _interestDueDayCtrl.text.isEmpty ? null : int.tryParse(_interestDueDayCtrl.text),
      startDate: formatApiDate(_startDate),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    try {
      await widget.onSubmit(dto);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isLent ? 'Money lent recorded' : 'Funding created'),
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
    final preview = _monthlyPreview;

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
                      _isLent ? 'New Money Lent' : 'New Private Funding',
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
                    Text(
                      _isLent
                          ? 'Money lent to an individual at an agreed rate. Interest is simple and never compounds.'
                          : 'Money borrowed from an individual at an agreed rate. Interest is simple and never compounds.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isLent)
                      FormSection(
                        label: 'Borrower *',
                        child: TapField(
                          value: _counterpartyEntity?.name ?? 'Select borrower',
                          icon: AppIcons.building2,
                          muted: _counterpartyEntity == null,
                          hasError: _fieldErrors.containsKey('counterparty'),
                          enabled: !_optionsLoading,
                          onTap: _pickCounterpartyEntity,
                        ),
                        errorText: _fieldErrors['counterparty'],
                      )
                    else
                      FormSection(
                        label: 'Funder *',
                        child: TapField(
                          value: _funder?.name ?? 'Select funder',
                          icon: AppIcons.landmark,
                          muted: _funder == null,
                          hasError: _fieldErrors.containsKey('funder'),
                          enabled: !_optionsLoading,
                          onTap: _pickFunder,
                        ),
                        errorText: _fieldErrors['funder'],
                      ),
                    const SizedBox(height: 14),
                    FormSection(
                      label: 'In Whose Name',
                      child: TapField(
                        value: _borrower?.name ?? 'Select entity (optional)',
                        icon: AppIcons.building2,
                        muted: _borrower == null,
                        enabled: !_optionsLoading,
                        onTap: _pickBorrower,
                        onClear: _borrower != null ? () => setState(() => _borrower = null) : null,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FormSection(
                      label: _isLent ? 'Amount Lent (₹) *' : 'Amount Borrowed (₹) *',
                      child: TextField(
                        controller: _amountCtrl,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                      ),
                      errorText: _fieldErrors['amount'],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _ModeChip(
                            label: 'Percent',
                            selected: _isPercent,
                            onTap: () => setState(() => _interestMode = 'PERCENT'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ModeChip(
                            label: 'Fixed ₹/month',
                            selected: !_isPercent,
                            onTap: () => setState(() => _interestMode = 'FIXED'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (_isPercent) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: FormSection(
                              label: 'Rate *',
                              child: TextField(
                                controller: _roiCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (_) => setState(() {}),
                              ),
                              errorText: _fieldErrors['roi'],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FormSection(
                              label: 'Basis',
                              child: TapField(
                                value: _roiBasis == 'MONTHLY' ? 'Monthly' : 'Annual',
                                icon: AppIcons.calendar,
                                onTap: () => setState(
                                    () => _roiBasis = _roiBasis == 'MONTHLY' ? 'ANNUAL' : 'MONTHLY'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else
                      FormSection(
                        label: 'Fixed Interest (₹/month) *',
                        child: TextField(
                          controller: _fixedAmountCtrl,
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                        ),
                        errorText: _fieldErrors['fixedAmount'],
                      ),
                    if (preview != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'A full month costs ${formatRupees(preview)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    FormSection(
                      label: 'Interest Due Day',
                      child: TextField(
                        controller: _interestDueDayCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: '1-31, optional'),
                      ),
                      errorText: _fieldErrors['interestDueDay'],
                    ),
                    const SizedBox(height: 14),
                    FormSection(
                      label: 'Start Date',
                      child: TapField(
                        value: formatDisplayDate(formatApiDate(_startDate)),
                        icon: AppIcons.calendar,
                        onTap: _pickDate,
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
                    : Text(_isLent ? 'Lend Money' : 'Create Funding'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.1) : null,
          border: Border.all(color: selected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.border)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.primary : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}
