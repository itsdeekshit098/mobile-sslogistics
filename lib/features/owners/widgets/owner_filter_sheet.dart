import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/entity_models.dart';
import '../../../shared/widgets/selectable_chip.dart';
import '../providers/owners_provider.dart';

class OwnerFilterSheet extends StatefulWidget {
  final OwnerFilters initial;

  const OwnerFilterSheet({super.key, required this.initial});

  @override
  State<OwnerFilterSheet> createState() => _OwnerFilterSheetState();
}

class _OwnerFilterSheetState extends State<OwnerFilterSheet> {
  late String? _entityKind = widget.initial.entityKind;
  late String? _relationship = widget.initial.relationship;

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
                'Filter',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text('Type', style: labelStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SelectableChip(
                    label: 'All',
                    selected: _entityKind == null,
                    onTap: () => setState(() => _entityKind = null),
                  ),
                  for (final kind in kEntityKinds)
                    SelectableChip(
                      label: entityKindLabel(kind),
                      selected: _entityKind == kind,
                      onTap: () => setState(() => _entityKind = kind),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Relationship', style: labelStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SelectableChip(
                    label: 'All',
                    selected: _relationship == null,
                    onTap: () => setState(() => _relationship = null),
                  ),
                  for (final rel in kEntityRelationships)
                    SelectableChip(
                      label: entityRelationshipLabel(rel),
                      selected: _relationship == rel,
                      onTap: () => setState(() => _relationship = rel),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, const OwnerFilters()),
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(
                        context,
                        OwnerFilters(entityKind: _entityKind, relationship: _relationship),
                      ),
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
