import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../shared/utils/money_format.dart';
import '../../../shared/widgets/lookup_select_field.dart';
import '../../../shared/widgets/server_error_banner.dart';
import '../../../shared/widgets/tap_field.dart';

/// Adds a bill (debit) or records a payment (credit). Bills stay simple —
/// date, amount, optional invoice/period — there is no invoice-to-payment
/// matching, matching how the business actually settles accounts.
class LedgerEntrySheet extends StatefulWidget {
  final String kind; // 'BILL' | 'PAYMENT'
  final num outstanding;
  final Future<void> Function({
    required String entryType,
    required num amount,
    required String entryDate,
    String? invoiceNo,
    String? periodMonth,
    String? paymentMethod,
    String? reference,
    String? description,
  }) onSubmit;

  const LedgerEntrySheet({
    super.key,
    required this.kind,
    required this.onSubmit,
    this.outstanding = 0,
  });

  @override
  State<LedgerEntrySheet> createState() => _LedgerEntrySheetState();
}

class _LedgerEntrySheetState extends State<LedgerEntrySheet> {
  final _amountCtrl = TextEditingController();
  final _invoiceCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  String? _paymentMethod;
  DateTime? _periodMonth;
  DateTime _entryDate = DateTime.now();

  bool _submitting = false;
  String? _error;

  bool get _isBill => widget.kind == 'BILL';

  @override
  void dispose() {
    _amountCtrl.dispose();
    _invoiceCtrl.dispose();
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

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _periodMonth ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 366)),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) setState(() => _periodMonth = DateTime(picked.year, picked.month, 1));
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
        entryType: widget.kind,
        amount: amount,
        entryDate: formatApiDate(_entryDate),
        invoiceNo: _isBill && _invoiceCtrl.text.trim().isNotEmpty ? _invoiceCtrl.text.trim() : null,
        periodMonth: _isBill && _periodMonth != null ? formatApiDate(_periodMonth!) : null,
        paymentMethod: !_isBill ? _paymentMethod : null,
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
                  _isBill ? 'Add Bill' : 'Record Payment',
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
                  label: 'Amount (₹) *',
                  child: TextField(controller: _amountCtrl, autofocus: true, keyboardType: TextInputType.numberWithOptions(decimal: true)),
                ),
                if (!_isBill && widget.outstanding > 0) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => setState(() => _amountCtrl.text = '${widget.outstanding}'),
                    child: Text(
                      'Settle in full — ${formatRupees(widget.outstanding)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                FormSection(
                  label: 'Date',
                  child: TapField(
                    value: formatDisplayDate(formatApiDate(_entryDate)),
                    icon: AppIcons.calendar,
                    onTap: _pickDate,
                  ),
                ),
                if (_isBill) ...[
                  const SizedBox(height: 14),
                  FormSection(
                    label: 'Invoice No. (optional)',
                    child: TextField(controller: _invoiceCtrl),
                  ),
                  const SizedBox(height: 14),
                  FormSection(
                    label: 'Billing Month (optional)',
                    child: TapField(
                      value: _periodMonth != null ? formatMonthYear(formatApiDate(_periodMonth!)) : 'Select month',
                      icon: AppIcons.calendar,
                      muted: _periodMonth == null,
                      onTap: _pickMonth,
                      onClear: _periodMonth != null ? () => setState(() => _periodMonth = null) : null,
                    ),
                  ),
                ] else ...[
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
                ],
                const SizedBox(height: 14),
                FormSection(
                  label: 'Reference',
                  child: TextField(
                    controller: _referenceCtrl,
                    decoration: InputDecoration(hintText: _isBill ? 'PO / contract no.' : 'UTR / cheque no.'),
                  ),
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
                      : Text(_isBill ? 'Add Bill' : 'Record Payment'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
