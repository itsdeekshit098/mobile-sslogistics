import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/selectable_chip.dart';

/// Distinguishes "sheet dismissed without a choice" (null) from an explicit
/// Reset/Apply, since `includeInactive: false` is itself a valid result.
class DriverFilterResult {
  final bool includeInactive;

  const DriverFilterResult(this.includeInactive);
}

class DriverFilterSheet extends StatefulWidget {
  final bool includeInactive;

  const DriverFilterSheet({super.key, required this.includeInactive});

  @override
  State<DriverFilterSheet> createState() => _DriverFilterSheetState();
}

class _DriverFilterSheetState extends State<DriverFilterSheet> {
  late bool _includeInactive = widget.includeInactive;

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
                'Filter Drivers',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text('Status', style: labelStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SelectableChip(
                    label: 'Active only',
                    selected: !_includeInactive,
                    onTap: () => setState(() => _includeInactive = false),
                  ),
                  SelectableChip(
                    label: 'Include Inactive',
                    selected: _includeInactive,
                    onTap: () => setState(() => _includeInactive = true),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, const DriverFilterResult(false)),
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, DriverFilterResult(_includeInactive)),
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
