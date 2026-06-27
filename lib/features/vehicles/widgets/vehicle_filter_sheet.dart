import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../data/vehicle_models.dart';

class VehicleFilterSheet extends StatefulWidget {
  final String type;
  final String status;

  const VehicleFilterSheet({
    super.key,
    required this.type,
    required this.status,
  });

  @override
  State<VehicleFilterSheet> createState() => _VehicleFilterSheetState();
}

class _VehicleFilterSheetState extends State<VehicleFilterSheet> {
  late String _type = widget.type;
  late String _status = widget.status;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Filter Vehicles',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              const Text('Type', style: _labelStyle),
              const SizedBox(height: 8),
              _ChoiceWrap(
                values: const ['all', ...vehicleTypes],
                selected: _type,
                label: (value) =>
                    value == 'all' ? 'All' : vehicleTypeLabel(value),
                onSelected: (value) => setState(() => _type = value),
              ),
              const SizedBox(height: 18),
              const Text('Status', style: _labelStyle),
              const SizedBox(height: 8),
              _ChoiceWrap(
                values: const ['', ...vehicleStatuses],
                selected: _status,
                label: (value) => value.isEmpty ? 'All' : value,
                onSelected: (value) => setState(() => _status = value),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, const {
                        'type': 'all',
                        'status': '',
                      }),
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, {
                        'type': _type,
                        'status': _status,
                      }),
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

const _labelStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w700,
  color: AppColors.textPrimary,
);

class _ChoiceWrap extends StatelessWidget {
  final List<String> values;
  final String selected;
  final String Function(String value) label;
  final ValueChanged<String> onSelected;

  const _ChoiceWrap({
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((value) {
        final active = selected == value;
        return ChoiceChip(
          label: Text(label(value)),
          selected: active,
          onSelected: (_) => onSelected(value),
          selectedColor: AppColors.primary.withValues(alpha: 0.12),
          labelStyle: TextStyle(
            color: active ? AppColors.primary : AppColors.textSecondary,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: active ? AppColors.primary : AppColors.border,
            ),
          ),
        );
      }).toList(),
    );
  }
}
