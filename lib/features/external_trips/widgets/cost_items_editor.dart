import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_sslogistics/core/constants/app_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../data/external_trip_models.dart';

final _moneyFmt = NumberFormat('#,##0.00', 'en_IN');

/// One editable row of the cost breakdown. Preset rows ("Diesel", "Driver")
/// have a fixed label and are required by the API; custom rows are removable.
class CostItemEntry {
  final String? presetLabel;
  final TextEditingController labelCtrl;
  final TextEditingController amountCtrl;
  final GlobalKey<FormFieldState> labelFieldKey = GlobalKey<FormFieldState>();
  final GlobalKey<FormFieldState> amountFieldKey = GlobalKey<FormFieldState>();
  final FocusNode labelFocusNode = FocusNode();
  final FocusNode amountFocusNode = FocusNode();

  CostItemEntry.preset(this.presetLabel, {double? amount})
      : labelCtrl = TextEditingController(),
        amountCtrl = TextEditingController(
          text: amount != null ? _trimZeros(amount) : '',
        );

  CostItemEntry.custom({String label = '', double? amount})
      : presetLabel = null,
        labelCtrl = TextEditingController(text: label),
        amountCtrl = TextEditingController(
          text: amount != null ? _trimZeros(amount) : '',
        );

  bool get isPreset => presetLabel != null;
  String get label => presetLabel ?? labelCtrl.text.trim();
  double get amount => double.tryParse(amountCtrl.text) ?? 0;

  CostItem toCostItem() => CostItem(label: label, amount: amount);

  void dispose() {
    labelCtrl.dispose();
    amountCtrl.dispose();
    labelFocusNode.dispose();
    amountFocusNode.dispose();
  }

  static String _trimZeros(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';
}

/// Builds the initial entries for a form: the required presets (filled from
/// [existing] when editing) followed by any extra custom items.
List<CostItemEntry> buildCostItemEntries([List<CostItem>? existing]) {
  final entries = <CostItemEntry>[];
  for (final label in presetCostLabels) {
    CostItem? match;
    if (existing != null) {
      for (final item in existing) {
        if (item.label == label) {
          match = item;
          break;
        }
      }
    }
    entries.add(CostItemEntry.preset(label, amount: match?.amount));
  }
  if (existing != null) {
    for (final item in existing) {
      if (!presetCostLabels.contains(item.label)) {
        entries.add(CostItemEntry.custom(label: item.label, amount: item.amount));
      }
    }
  }
  return entries;
}

class CostItemsEditor extends StatelessWidget {
  final List<CostItemEntry> entries;
  final VoidCallback onAdd;
  final void Function(CostItemEntry entry) onRemove;
  final VoidCallback onChanged;

  const CostItemsEditor({
    super.key,
    required this.entries,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
  });

  double get _total => entries.fold(0, (sum, e) => sum + e.amount);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkPageBg : AppColors.pageBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CostItemRow(
                entry: entry,
                onRemove: entry.isPreset ? null : () => onRemove(entry),
                onChanged: onChanged,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onAdd,
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            icon: const Icon(AppIcons.plus, size: 16),
            label: const Text('Add cost item'),
          ),
          Divider(height: 16, color: borderColor),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total Cost',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                '₹${_moneyFmt.format(_total)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CostItemRow extends StatelessWidget {
  final CostItemEntry entry;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  const _CostItemRow({
    required this.entry,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    InputDecoration decor(String hint) => InputDecoration(
          hintText: hint,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          isDense: true,
          filled: true,
          fillColor: isDark ? AppColors.darkCardBg : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: entry.isPreset
              ? Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCardBg : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                  ),
                  child: Text(
                    '${entry.presetLabel} *',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                )
              : TextFormField(
                  key: entry.labelFieldKey,
                  controller: entry.labelCtrl,
                  focusNode: entry.labelFocusNode,
                  decoration: decor('Label'),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 4,
          child: TextFormField(
            key: entry.amountFieldKey,
            controller: entry.amountCtrl,
            focusNode: entry.amountFocusNode,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: decor('₹ 0'),
            onChanged: (_) => onChanged(),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              final n = double.tryParse(v);
              if (n == null || n < 0) return 'Invalid';
              return null;
            },
          ),
        ),
        if (onRemove != null) ...[
          const SizedBox(width: 4),
          IconButton(
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 42),
            icon: const Icon(AppIcons.x, size: 18, color: AppColors.error),
          ),
        ],
      ],
    );
  }
}
