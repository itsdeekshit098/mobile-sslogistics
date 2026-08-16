import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../shared/utils/money_format.dart';
import '../../../shared/widgets/lookup_select_field.dart';
import '../../../shared/widgets/server_error_banner.dart';
import '../../../shared/widgets/tap_field.dart';
import '../data/loan_models.dart';

/// Records an EMI settled, prepayment, foreclosure, or a bounce/late charge.
/// One sheet for all four — the `paymentType` decides which fields make
/// sense and what the amount defaults to.
class LoanPaymentSheet extends StatefulWidget {
  final String paymentType;
  final LoanInstallment? installment;
  final Future<void> Function({
    required String paymentType,
    required num amount,
    required String paidOn,
    int? installmentId,
    String? paymentMethod,
    String? reference,
    String? notes,
  }) onSubmit;

  const LoanPaymentSheet({
    super.key,
    required this.paymentType,
    required this.onSubmit,
    this.installment,
  });

  @override
  State<LoanPaymentSheet> createState() => _LoanPaymentSheetState();
}

class _LoanPaymentSheetState extends State<LoanPaymentSheet> {
  late final TextEditingController _amountCtrl;
  final _referenceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _paymentMethod;
  DateTime _paidOn = DateTime.now();

  bool _submitting = false;
  String? _error;

  String get _title => switch (widget.paymentType) {
        'EMI' => 'Mark Installment Paid',
        'PREPAYMENT' => 'Record Prepayment',
        'FORECLOSURE' => 'Record Foreclosure',
        'CHARGE' => 'Record Charge',
        _ => 'Record Payment',
      };

  @override
  void initState() {
    super.initState();
    final prefill = widget.installment?.amountRemaining;
    _amountCtrl = TextEditingController(text: prefill != null ? '$prefill' : '');
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _referenceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paidOn,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _paidOn = picked);
  }

  Future<void> _submit() async {
    final amount = num.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount greater than zero');
      return;
    }
    if (widget.paymentType == 'EMI' &&
        widget.installment != null &&
        amount > widget.installment!.amountRemaining) {
      setState(() => _error =
          'That is more than the ${formatRupees(widget.installment!.amountRemaining)} still due. Record the extra as a prepayment.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await widget.onSubmit(
        paymentType: widget.paymentType,
        amount: amount,
        paidOn: formatApiDate(_paidOn),
        installmentId: widget.paymentType == 'EMI' ? widget.installment?.id : null,
        paymentMethod: _paymentMethod,
        reference: _referenceCtrl.text.trim().isEmpty ? null : _referenceCtrl.text.trim(),
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
                  _title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                if (widget.installment != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Installment #${widget.installment!.installmentNo} · due ${formatDisplayDate(widget.installment!.dueDate)}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (_error != null) ...[
                  ServerErrorBanner(message: _error!),
                  const SizedBox(height: 12),
                ],
                FormSection(
                  label: 'Amount (₹) *',
                  child: TextField(
                    controller: _amountCtrl,
                    autofocus: widget.installment == null,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(height: 14),
                FormSection(
                  label: 'Date',
                  child: TapField(
                    value: formatDisplayDate(formatApiDate(_paidOn)),
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
                  child: TextField(
                    controller: _referenceCtrl,
                    decoration: const InputDecoration(hintText: 'UTR / cheque no.'),
                  ),
                ),
                const SizedBox(height: 14),
                FormSection(
                  label: 'Notes',
                  child: TextField(controller: _notesCtrl, maxLines: 2),
                ),
                const SizedBox(height: 18),
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
