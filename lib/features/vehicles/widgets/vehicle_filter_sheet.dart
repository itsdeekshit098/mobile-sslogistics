import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../data/vehicle_models.dart';
import '../data/vehicle_repository.dart';

class VehicleFilterSheet extends StatefulWidget {
  final String type;
  final String status;
  final String ownerType;
  final String ownerName;
  final String fuelType;

  const VehicleFilterSheet({
    super.key,
    required this.type,
    required this.status,
    this.ownerType = '',
    this.ownerName = '',
    this.fuelType = '',
  });

  @override
  State<VehicleFilterSheet> createState() => _VehicleFilterSheetState();
}

class _VehicleFilterSheetState extends State<VehicleFilterSheet> {
  final _ownerRepo = VehicleRepository();
  late String _type = widget.type;
  late String _status = widget.status;
  late String _ownerType = widget.ownerType;
  late String _ownerName = widget.ownerName;
  late String _fuelType = widget.fuelType;

  List<VehicleOwner> _owners = [];
  bool _loadingOwners = true;
  bool _ownersFailed = false;

  @override
  void initState() {
    super.initState();
    _loadOwners();
  }

  Future<void> _loadOwners() async {
    setState(() {
      _loadingOwners = true;
      _ownersFailed = false;
    });
    try {
      final owners = await _ownerRepo.getOwners();
      if (mounted) setState(() => _owners = owners);
    } catch (_) {
      if (mounted) setState(() => _ownersFailed = true);
    } finally {
      if (mounted) setState(() => _loadingOwners = false);
    }
  }

  /// Owner names for the currently selected Owner Type, plus the
  /// already-applied filter value even if it's no longer in the fetched list
  /// (owner renamed/deleted) — otherwise re-opening the sheet with that
  /// filter active would show a value the picker can't represent.
  List<String> _ownerNameOptions() {
    final names = _owners
        .where((o) => o.ownerType == _ownerType)
        .map((o) => o.name)
        .toList();
    if (_ownerName.isNotEmpty &&
        widget.ownerType == _ownerType &&
        !names.contains(_ownerName)) {
      names.insert(0, _ownerName);
    }
    return names;
  }

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
          child: SingleChildScrollView(
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
                const SizedBox(height: 18),
                const Text('Fuel', style: _labelStyle),
                const SizedBox(height: 8),
                _ChoiceWrap(
                  values: const ['', ...fuelTypes],
                  selected: _fuelType,
                  label: (value) => value.isEmpty ? 'All' : fuelTypeLabel(value),
                  onSelected: (value) => setState(() => _fuelType = value),
                ),
                const SizedBox(height: 18),
                const Text('Owner Type', style: _labelStyle),
                const SizedBox(height: 8),
                _ChoiceWrap(
                  values: const ['', ...ownerTypes],
                  selected: _ownerType,
                  label: (value) => value.isEmpty ? 'All' : ownerTypeLabel(value),
                  onSelected: (value) => setState(() {
                    _ownerType = value;
                    _ownerName = '';
                  }),
                ),
                const SizedBox(height: 18),
                const Text('Owner Name', style: _labelStyle),
                const SizedBox(height: 8),
                _buildOwnerNameControl(),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, const {
                          'type': 'all',
                          'status': '',
                          'ownerType': '',
                          'ownerName': '',
                          'fuelType': '',
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
                          'ownerType': _ownerType,
                          'ownerName': _ownerName,
                          'fuelType': _fuelType,
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
      ),
    );
  }

  Widget _buildOwnerNameControl() {
    if (_ownerType.isEmpty) {
      return const Text(
        'Select an owner type first',
        style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
      );
    }
    if (_loadingOwners) {
      return const Text(
        'Loading owners...',
        style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
      );
    }
    if (_ownersFailed) {
      return Row(
        children: [
          const Icon(Icons.error_outline, size: 15, color: AppColors.error),
          const SizedBox(width: 5),
          const Expanded(
            child: Text(
              "Couldn't load owners.",
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: _loadOwners,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Retry',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );
    }
    return _ChoiceWrap(
      values: ['', ..._ownerNameOptions()],
      selected: _ownerName,
      label: (value) => value.isEmpty ? 'All' : value,
      onSelected: (value) => setState(() => _ownerName = value),
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
