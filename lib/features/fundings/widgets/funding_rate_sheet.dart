import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../shared/utils/money_format.dart';
import '../../../shared/widgets/server_error_banner.dart';
import '../../../shared/widgets/tap_field.dart';

/// Records a renegotiated rate, effective from a chosen date. Past days keep
/// whatever rate was actually in force — this never edits history.
class FundingRateSheet extends StatefulWidget {
  final String interestMode;
  final Future<void> Function({
    required String effectiveFrom,
    num? roi,
    String? roiBasis,
    num? fixedInterestAmount,
    String? note,
  }) onSubmit;

  const FundingRateSheet({super.key, required this.interestMode, required this.onSubmit});

  @override
  State<FundingRateSheet> createState() => _FundingRateSheetState();
}

class _FundingRateSheetState extends State<FundingRateSheet> {
  final _roiCtrl = TextEditingController();
  final _fixedAmountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _roiBasis = 'MONTHLY';
  DateTime _effectiveFrom = DateTime.now();

  bool _submitting = false;
  String? _error;

  bool get _isPercent => widget.interestMode == 'PERCENT';

  @override
  void dispose() {
    _roiCtrl.dispose();
    _fixedAmountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveFrom,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _effectiveFrom = picked);
  }

  Future<void> _submit() async {
    num? roi;
    num? fixed;
    if (_isPercent) {
      roi = num.tryParse(_roiCtrl.text);
      if (roi == null || roi < 0) {
        setState(() => _error = 'Enter the new rate');
        return;
      }
    } else {
      fixed = num.tryParse(_fixedAmountCtrl.text);
      if (fixed == null || fixed < 0) {
        setState(() => _error = 'Enter the new monthly amount');
        return;
      }
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await widget.onSubmit(
        effectiveFrom: formatApiDate(_effectiveFrom),
        roi: roi,
        roiBasis: _isPercent ? _roiBasis : null,
        fixedInterestAmount: fixed,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
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
                  'Change Rate',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Days before this date keep the rate that was actually in force.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                if (_error != null) ...[
                  ServerErrorBanner(message: _error!),
                  const SizedBox(height: 12),
                ],
                if (_isPercent)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: FormSection(
                          label: 'New Rate *',
                          child: TextField(
                            controller: _roiCtrl,
                            autofocus: true,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
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
                  )
                else
                  FormSection(
                    label: 'New Fixed Interest (₹/month) *',
                    child: TextField(controller: _fixedAmountCtrl, autofocus: true, keyboardType: TextInputType.numberWithOptions(decimal: true)),
                  ),
                const SizedBox(height: 14),
                FormSection(
                  label: 'Effective From',
                  child: TapField(
                    value: formatDisplayDate(formatApiDate(_effectiveFrom)),
                    icon: AppIcons.calendar,
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(height: 14),
                FormSection(
                  label: 'Note',
                  child: TextField(controller: _noteCtrl, maxLines: 2),
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
