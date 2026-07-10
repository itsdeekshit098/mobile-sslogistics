import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/selectable_chip.dart';
import '../data/owner_models.dart';

/// Distinguishes "sheet dismissed without a choice" (null) from an explicit
/// Reset/Apply, since `ownerType: null` (All) is itself a valid result.
class OwnerFilterResult {
  final String? ownerType;

  const OwnerFilterResult(this.ownerType);
}

class OwnerFilterSheet extends StatefulWidget {
  final String? ownerType;

  const OwnerFilterSheet({super.key, this.ownerType});

  @override
  State<OwnerFilterSheet> createState() => _OwnerFilterSheetState();
}

class _OwnerFilterSheetState extends State<OwnerFilterSheet> {
  late String? _ownerType = widget.ownerType;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
    );
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                'Filter Owners',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text('Owner Type', style: labelStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SelectableChip(
                    label: 'All',
                    selected: _ownerType == null,
                    onTap: () => setState(() => _ownerType = null),
                  ),
                  SelectableChip(
                    label: 'Own',
                    selected: _ownerType == ownerTypeOwn,
                    onTap: () => setState(() => _ownerType = ownerTypeOwn),
                  ),
                  SelectableChip(
                    label: 'External',
                    selected: _ownerType == ownerTypeExternal,
                    onTap: () => setState(() => _ownerType = ownerTypeExternal),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, const OwnerFilterResult(null)),
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, OwnerFilterResult(_ownerType)),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
