import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../data/warranty_models.dart';

class WarrantyStatusChip extends StatelessWidget {
  final String status;
  const WarrantyStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      warrantyStatusExpired => (AppColors.error, 'Expired'),
      warrantyStatusExpiringSoon => (AppColors.warning, 'Expiring Soon'),
      _ => (AppColors.success, 'Active'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
