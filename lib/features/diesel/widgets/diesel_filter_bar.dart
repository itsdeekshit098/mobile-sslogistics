import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_sslogistics/core/constants/app_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../providers/vehicle_provider.dart';
import '../providers/diesel_provider.dart';
import '../../../shared/models/vehicle_model.dart';

class DieselFilterBar extends ConsumerWidget {
  const DieselFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final listState = ref.watch(dieselListProvider).valueOrNull;

    return Container(
      color: AppColors.pageBg,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: vehiclesAsync.when(
        loading: () => const _FilterSkeleton(),
        error: (e, _) => _FilterButton(
          icon: AppIcons.truck,
          label: 'Vehicles unavailable',
          onTap: null,
        ),
        data: (vehicles) => _VehicleFilterButton(
          vehicles: vehicles,
          selectedId: listState?.selectedVehicleId,
          onChanged: (id) =>
              ref.read(dieselListProvider.notifier).filterByVehicle(id),
        ),
      ),
    );
  }
}

// ── Reusable tappable filter button ──────────────────────────────────────────

class _FilterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  const _FilterButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = Colors.white;
    final borderColor = active ? AppColors.primary : AppColors.border;
    final textColor = active ? AppColors.primary : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: borderColor, width: active ? 1.6 : 1.0),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: textColor,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 24,
              color: AppColors.textPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Vehicle filter with bottom sheet picker ───────────────────────────────────

class _VehicleFilterButton extends StatelessWidget {
  final List<Vehicle> vehicles;
  final int? selectedId;
  final ValueChanged<int?> onChanged;

  const _VehicleFilterButton({
    required this.vehicles,
    required this.selectedId,
    required this.onChanged,
  });

  String get _label {
    if (selectedId == null) return 'Choose a vehicle';
    try {
      return vehicles.firstWhere((v) => v.id == selectedId).plateNumber;
    } catch (_) {
      return 'Choose a vehicle';
    }
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _VehiclePickerSheet(
        vehicles: vehicles,
        selectedId: selectedId,
        onSelected: (id) {
          Navigator.pop(context);
          onChanged(id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _FilterButton(
      icon: AppIcons.truck,
      label: _label,
      active: selectedId != null,
      onTap: () => _showPicker(context),
    );
  }
}

class _VehiclePickerSheet extends StatefulWidget {
  final List<Vehicle> vehicles;
  final int? selectedId;
  final ValueChanged<int?> onSelected;

  const _VehiclePickerSheet({
    required this.vehicles,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  State<_VehiclePickerSheet> createState() => _VehiclePickerSheetState();
}

class _VehiclePickerSheetState extends State<_VehiclePickerSheet> {
  String _query = '';

  List<Vehicle> get _filteredVehicles {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.vehicles;
    return widget.vehicles.where((vehicle) {
      final haystack = [
        vehicle.plateNumber,
        vehicle.make,
        vehicle.model,
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredVehicles;
    final media = MediaQuery.of(context);
    final keyboardHeight = media.viewInsets.bottom;
    final maxListHeight = (media.size.height - keyboardHeight) * 0.42;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    const Icon(
                      AppIcons.truck,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Select vehicle (${widget.vehicles.length})',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TextField(
                  autofocus: true,
                  onChanged: (value) => setState(() => _query = value),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search vehicle number, make, model',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.pageBg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: maxListHeight.clamp(160.0, 420.0),
                ),
                child: filtered.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            'No vehicles found',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: AppColors.border,
                        ),
                        itemBuilder: (_, i) {
                          final v = filtered[i];
                          return _PickerItem(
                            label: v.plateNumber,
                            subtitle: [
                              v.make,
                              v.model,
                            ].whereType<String>().join(' '),
                            isSelected: widget.selectedId == v.id,
                            onTap: () => widget.onSelected(v.id),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerItem extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _PickerItem({
    required this.label,
    this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: isSelected ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
      subtitle: subtitle != null && subtitle!.isNotEmpty
          ? Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            )
          : null,
      trailing: isSelected
          ? const Icon(Icons.check_rounded, size: 18, color: AppColors.primary)
          : null,
      onTap: onTap,
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _FilterSkeleton extends StatelessWidget {
  const _FilterSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
