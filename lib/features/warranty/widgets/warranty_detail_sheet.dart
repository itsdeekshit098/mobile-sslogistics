import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../data/warranty_models.dart';
import 'warranty_status_chip.dart';

final _dateFmt = DateFormat('dd MMM yyyy');
final _moneyFmt = NumberFormat('#,##0.00', 'en_IN');

class WarrantyDetailSheet extends StatelessWidget {
  final WarrantyItem item;
  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const WarrantyDetailSheet({
    super.key,
    required this.item,
    required this.canEdit,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? AppColors.darkCardBg : Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.partName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(icon: const Icon(AppIcons.x, size: 20), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WarrantyStatusChip(status: item.warrantyStatus),
                    const SizedBox(height: 16),
                    if (item.vehicle != null)
                      _Row(
                        label: 'Vehicle',
                        value: [item.vehicle!.vehicleNumber, item.vehicle!.company, item.vehicle!.model]
                            .whereType<String>()
                            .where((s) => s.isNotEmpty)
                            .join(' · '),
                      ),
                    if (item.vendor != null)
                      _Row(
                        label: 'Vendor',
                        value: [item.vendor!.name, item.vendor!.phone, item.vendor!.location]
                            .whereType<String>()
                            .where((s) => s.isNotEmpty)
                            .join(' · '),
                      ),
                    _Row(label: 'Cost', value: '₹${_moneyFmt.format(item.cost)}'),
                    _Row(
                      label: 'Purchase Date',
                      value: _dateFmt.format(DateTime.tryParse(item.purchaseDate) ?? DateTime.now()),
                    ),
                    _Row(
                      label: 'Warranty',
                      value: '${item.warrantyDuration} ${item.warrantyDurationUnit}',
                    ),
                    _Row(
                      label: 'Expiry',
                      value: _dateFmt.format(DateTime.tryParse(item.warrantyExpiry) ?? DateTime.now()),
                    ),
                    if (item.isLinkedToRepair) _Row(label: 'Linked Repair', value: '#${item.repairRecordId}'),
                    if (item.notes != null && item.notes!.isNotEmpty) _Row(label: 'Notes', value: item.notes!),
                  ],
                ),
              ),
            ),
            if (canEdit) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(AppIcons.pencil, size: 16),
                        label: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onDelete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                        ),
                        icon: const Icon(AppIcons.trash2, size: 16),
                        label: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
