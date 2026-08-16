import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../shared/utils/money_format.dart';
import '../../../shared/widgets/lookup_select_field.dart';
import '../../../shared/widgets/server_error_banner.dart';
import '../../../shared/widgets/tap_field.dart';
import '../data/funding_models.dart';

/// Records money moving on a funding: more borrowed, principal returned,
/// interest paid, or a write-off. [prefillAmount] is set for "Pay Interest"
/// and "Repay Principal" quick actions, so the sheet opens with the figure
/// the user actually asked to settle.
class FundingEntrySheet extends StatefulWidget {
  final String entryType;
  final String direction;
  final num? prefillAmount;
  final Future<void> Function({
    required String entryType,
    required num amount,
    required String entryDate,
    String? paymentMethod,
    String? reference,
    String? description,
  }) onSubmit;

  const FundingEntrySheet({
    super.key,
    required this.entryType,
    required this.onSubmit,
    this.direction = 'BORROWED',
    this.prefillAmount,
  });

  @override
  State<FundingEntrySheet> createState() => _FundingEntrySheetState();
}

class _FundingEntrySheetState extends State<FundingEntrySheet> {
  late final TextEditingController _amountCtrl;
  final _referenceCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  String? _paymentMethod;
  DateTime _entryDate = DateTime.now();

  bool _submitting = false;
  String? _error;

  // Direction-aware: PRINCIPAL_TAKEN is an inflow when we're the borrower but
  // an outflow when we're lending (giving more), and PRINCIPAL_REPAID/
  // INTEREST_PAID flip the same way — matches fundingEntryTypeLabel's own
  // isLent branching just above, which this used to ignore.
  bool get _isMoneyIn {
    final isLent = widget.direction == 'LENT';
    switch (widget.entryType) {
      case 'PRINCIPAL_TAKEN':
        return !isLent;
      case 'PRINCIPAL_REPAID':
      case 'INTEREST_PAID':
        return isLent;
      default:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.prefillAmount != null && widget.prefillAmount! > 0
          ? '${widget.prefillAmount}'
          : '',
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _referenceCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _entryDate,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _entryDate = picked);
  }

  Future<void> _submit() async {
    final amount = num.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount greater than zero');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await widget.onSubmit(
        entryType: widget.entryType,
        amount: amount,
        entryDate: formatApiDate(_entryDate),
        paymentMethod: _paymentMethod,
        reference: _referenceCtrl.text.trim().isEmpty ? null : _referenceCtrl.text.trim(),
        description: _descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim(),
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                  fundingEntryTypeLabel(widget.entryType, direction: widget.direction),
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
                  label: _isMoneyIn ? 'Amount Received (₹) *' : 'Amount (₹) *',
                  child: TextField(controller: _amountCtrl, autofocus: true, keyboardType: TextInputType.numberWithOptions(decimal: true)),
                ),
                const SizedBox(height: 14),
                FormSection(
                  label: 'Date',
                  child: TapField(
                    value: formatDisplayDate(formatApiDate(_entryDate)),
                    icon: AppIcons.calendar,
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(height: 14),
                FormSection(
                  label: 'Payment Method',
                  child: LookupSelectField(
                    category: 'payment_method',
                    noun: 'payment method',
                    value: _paymentMethod,
                    placeholder: 'Select method (optional)',
                    clearable: true,
                    onChanged: (v) => setState(() => _paymentMethod = v),
                  ),
                ),
                const SizedBox(height: 14),
                FormSection(
                  label: 'Reference',
                  child: TextField(controller: _referenceCtrl),
                ),
                const SizedBox(height: 14),
                FormSection(
                  label: 'Description',
                  child: TextField(controller: _descriptionCtrl, maxLines: 2, maxLength: 300),
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
                      : const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
