import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_sslogistics/core/constants/app_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../data/repair_models.dart';

final _dateFmt = DateFormat('dd MMM yyyy');
final _moneyFmt = NumberFormat('#,##0.00', 'en_IN');

class RepairDetailSheet extends StatelessWidget {
  final RepairRecord record;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const RepairDetailSheet({
    super.key,
    required this.record,
    this.canEdit = false,
    this.canDelete = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final date = DateTime.tryParse(record.repairDate)?.toLocal();
    final dateStr = date != null ? _dateFmt.format(date) : record.repairDate;
    final isElectrical = record.category == repairCategoryElectrical;
    final accentColor = isElectrical ? AppColors.tileTechIcon : AppColors.tileRepairIcon;
    final isOpen = record.isOpen;
    final statusColor = isOpen ? AppColors.warning : AppColors.success;

    return Material(
      color: isDark ? AppColors.darkCardBg : Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Text(
                  'Repair Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(icon: const Icon(AppIcons.x, size: 20), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: accentColor.withValues(alpha: 0.28)),
                        ),
                        child: Text(
                          record.categoryLabel.toUpperCase(),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: accentColor),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: statusColor.withValues(alpha: 0.28)),
                        ),
                        child: Text(
                          isOpen ? 'OPEN' : 'CLOSED',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _DetailRow(icon: AppIcons.calendar, label: 'Date', value: dateStr),
                  _DetailRow(icon: AppIcons.truck, label: 'Vehicle', value: record.vehicleNumber),
                  if (record.vehicleCompany != null || record.vehicleModel != null)
                    _DetailRow(
                      icon: Icons.info_outline,
                      label: 'Vehicle Info',
                      value: [record.vehicleCompany, record.vehicleModel].whereType<String>().join(' · '),
                    ),
                  _DetailRow(
                    icon: AppIcons.indianRupee,
                    label: 'Cost',
                    value: '₹${_moneyFmt.format(record.cost)}',
                  ),
                  _DetailRow(
                    icon: AppIcons.userCog,
                    label: 'Technician',
                    value: record.technicianName ?? 'Unassigned',
                    subtitle: record.technicianPhone,
                  ),
                  if (record.issues.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const _SectionHeader(label: 'Issues'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: record.issues
                          .map(
                            (issue) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkPageBg : AppColors.pageBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                              ),
                              child: Text(
                                issue,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  if (record.description != null && record.description!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const _SectionHeader(label: 'Description'),
                    const SizedBox(height: 6),
                    Text(
                      record.description!,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (record.parts.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SectionHeader(label: 'Parts (${record.parts.length})'),
                    const SizedBox(height: 8),
                    ...record.parts.map((part) => _PartDetailCard(part: part)),
                  ],
                  if (canEdit || canDelete) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        if (canEdit)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onEdit,
                              icon: const Icon(AppIcons.pencil, size: 16),
                              label: const Text('Edit'),
                            ),
                          ),
                        if (canEdit && canDelete) const SizedBox(width: 12),
                        if (canDelete)
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
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;

  const _DetailRow({required this.icon, required this.label, required this.value, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PartDetailCard extends StatelessWidget {
  final RepairPart part;
  const _PartDetailCard({required this.part});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purchaseDate = DateTime.tryParse(part.purchaseDate);
    final expiry = part.warrantyExpiry != null ? DateTime.tryParse(part.warrantyExpiry!) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkPageBg : AppColors.pageBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  part.partName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '₹${_moneyFmt.format(part.cost)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          if (part.vendorName != null) ...[
            const SizedBox(height: 4),
            Text(
              'Vendor: ${part.vendorName}${part.vendorPhone != null ? ' · ${part.vendorPhone}' : ''}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (purchaseDate != null)
                Text('Purchased: ${_dateFmt.format(purchaseDate)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                    )),
              Text(
                'Warranty: ${part.warrantyDuration} ${part.warrantyDurationUnit}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                ),
              ),
              if (expiry != null)
                Text('Expires: ${_dateFmt.format(expiry)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                    )),
            ],
          ),
          if (part.notes != null && part.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              part.notes!,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
