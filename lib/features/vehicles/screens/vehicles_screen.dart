import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_spinner.dart';
import '../data/vehicle_models.dart';
import '../providers/vehicles_provider.dart';
import '../widgets/delete_confirmation_dialog.dart';
import '../widgets/vehicle_card.dart';
import '../widgets/vehicle_documents_sheet.dart';
import '../widgets/vehicle_filter_sheet.dart';
import '../widgets/vehicle_form_sheet.dart';
import '../widgets/vehicle_pagination_bar.dart';

class VehiclesScreen extends ConsumerStatefulWidget {
  const VehiclesScreen({super.key});

  @override
  ConsumerState<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends ConsumerState<VehiclesScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(vehiclesListProvider);
    final user = ref.watch(authProvider).valueOrNull;
    final canWrite = user?.isAdmin == true || user?.isStaff == true;
    final canDelete = user?.isAdmin == true;

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(AppIcons.menu, color: AppColors.textPrimary),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text(
          'Vehicles',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      drawer: const AppDrawer(currentPath: '/vehicles'),
      body: async.when(
        loading: () => const LoadingSpinner(message: 'Loading vehicles...'),
        error: (e, _) => ErrorState(
          message: e.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(vehiclesListProvider),
        ),
        data: (state) => Column(
          children: [
            _Toolbar(
              state: state,
              controller: _searchCtrl,
              onSearch: _onSearch,
              onFilter: () => _showFilters(state),
            ),
            _StatsRow(stats: state.stats),
            Expanded(
              child: state.vehicles.isEmpty
                  ? const Center(
                      child: Text(
                        'No vehicles found',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.read(vehiclesListProvider.notifier).refresh(),
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 6, bottom: 90),
                        itemCount: state.vehicles.length,
                        itemBuilder: (context, index) {
                          final vehicle = state.vehicles[index];
                          return VehicleCard(
                            vehicle: vehicle,
                            canWrite: canWrite,
                            canDelete: canDelete,
                            onTap: () =>
                                _showDetails(vehicle, canWrite, canDelete),
                            onEdit: canWrite ? () => _showForm(vehicle) : null,
                            onDelete: canDelete ? () => _delete(vehicle) : null,
                            onDocuments: () =>
                                _showDocuments(vehicle, canWrite),
                          );
                        },
                      ),
                    ),
            ),
            VehiclePaginationBar(
              page: state.page,
              totalPages: state.totalPages,
              total: state.total,
              pageSize: state.pageSize,
              onPageChange: ref.read(vehiclesListProvider.notifier).changePage,
              onPageSizeChange: ref
                  .read(vehiclesListProvider.notifier)
                  .changePageSize,
            ),
          ],
        ),
      ),
      floatingActionButton: canWrite
          ? Transform.translate(
              offset: const Offset(0, 22),
              child: FloatingActionButton(
                onPressed: () => _showForm(null),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                child: const Icon(AppIcons.plus),
              ),
            )
          : null,
    );
  }

  void _onSearch(String value) {
    final query = value.trim();
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 900),
      () {
        final current = ref.read(vehiclesListProvider).valueOrNull;
        if (current?.search == query) return;
        ref.read(vehiclesListProvider.notifier).search(query);
      },
    );
  }

  Future<void> _showFilters(VehiclesState state) async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          VehicleFilterSheet(type: state.type, status: state.status),
    );
    if (result != null) {
      ref
          .read(vehiclesListProvider.notifier)
          .applyFilters(type: result['type'], status: result['status']);
    }
  }

  void _showForm(FleetVehicle? vehicle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: VehicleFormSheet(
          vehicle: vehicle,
          onSubmit: (payload) async {
            final notifier = ref.read(vehiclesListProvider.notifier);
            if (vehicle == null) {
              await notifier.createVehicle(payload);
            } else {
              await notifier.updateVehicle(payload);
            }
          },
        ),
      ),
    );
  }

  void _showDocuments(FleetVehicle vehicle, bool canManage) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.88,
        child: VehicleDocumentsSheet(
          vehicle: vehicle,
          canManage: canManage,
          repository: ref.read(vehicleRepositoryProvider),
          onChanged: () => ref
              .read(vehiclesListProvider.notifier)
              .refresh(showLoading: false),
        ),
      ),
    );
  }

  void _showDetails(FleetVehicle vehicle, bool canWrite, bool canDelete) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: _VehicleDetails(
          vehicle: vehicle,
          canWrite: canWrite,
          canDelete: canDelete,
          onEdit: () {
            Navigator.pop(context);
            _showForm(vehicle);
          },
          onDelete: () {
            Navigator.pop(context);
            _delete(vehicle);
          },
          onDocuments: () {
            Navigator.pop(context);
            _showDocuments(vehicle, canWrite);
          },
        ),
      ),
    );
  }

  Future<void> _delete(FleetVehicle vehicle) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteConfirmationDialog(
        title: 'Delete Vehicle',
        targetName: vehicle.vehicleNumber.toUpperCase(),
        warningText: 'This action cannot be undone.',
        warningSubtext: 'All vehicle data will be permanently removed.',
      ),
    );
    if (ok == true) {
      try {
        await ref
            .read(vehiclesListProvider.notifier)
            .deleteVehicle(vehicle.id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e.toString().replaceFirst('Exception: ', ''),
              ),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }
}

class _Toolbar extends StatelessWidget {
  final VehiclesState state;
  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  final VoidCallback onFilter;
  const _Toolbar({
    required this.state,
    required this.controller,
    required this.onSearch,
    required this.onFilter,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText: 'Search vehicle number',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 56,
          height: 56,
          child: Material(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onFilter,
              borderRadius: BorderRadius.circular(12),
              child: Center(
                child: Badge(
                  isLabelVisible: state.hasFilters,
                  child: const Icon(Icons.tune, color: AppColors.textPrimary),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _StatsRow extends StatelessWidget {
  final VehicleStats stats;
  const _StatsRow({required this.stats});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 94,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _Stat('Total fleet', stats.total, AppColors.primary),
        _Stat('Active now', stats.active, AppColors.success),
        _Stat('In service', stats.maintenance, AppColors.warning),
        _Stat('Idle', stats.idle, AppColors.textSecondary),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _Stat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Container(
    width: 136,
    margin: const EdgeInsets.only(right: 10, top: 6, bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 25,
            height: 1,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            height: 1.1,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _VehicleDetails extends StatelessWidget {
  final FleetVehicle vehicle;
  final bool canWrite;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDocuments;
  const _VehicleDetails({
    required this.vehicle,
    required this.canWrite,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
    required this.onDocuments,
  });
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: AppColors.pageBg,
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    child: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              vehicle.vehicleNumber,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 24,
                height: 1.05,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _DetailSection(
            children: [
              _Detail(
                icon: Icons.inventory_2_outlined,
                label: 'Type',
                value: vehicleTypeLabel(vehicle.vehicleType),
              ),
              _Detail.status(
                icon: AppIcons.checkCircle,
                label: 'Status',
                value: vehicle.status,
                color: _vehicleStatusColor(vehicle.status),
              ),
              _Detail(
                icon: AppIcons.fuel,
                label: 'Fuel',
                value: vehicle.fuelType != null ? fuelTypeLabel(vehicle.fuelType!) : '-',
              ),
          if (vehicle.vehicleType.toUpperCase() == 'CAR' ||
              vehicle.vehicleType.toUpperCase() == 'BUS' ||
              vehicle.vehicleType.toUpperCase() == 'TEMPO_TRAVELLER')
            _Detail(
              icon: Icons.airline_seat_recline_normal,
              label: 'Seating Capacity',
              value: vehicle.seatingCapacity != null
                  ? '${vehicle.seatingCapacity}-Seater'
                  : '-',
            ),
          if (vehicle.vehicleType.toUpperCase() == 'TRUCK')
            _Detail(
              icon: AppIcons.truck,
              label: 'Truck Type',
              value: vehicle.truckType != null ? enumLabel(vehicle.truckType!) : '-',
            ),
          if (vehicle.vehicleType.toUpperCase() == 'CONTAINER') ...
            [
              _Detail(
                icon: Icons.straighten,
                label: 'Container Length',
                value: vehicle.containerLength != null
                    ? vehicle.containerLength!
                          .replaceAll('_FT', ' ft')
                          .replaceAll('_', ' ')
                    : '-',
              ),
              _Detail(
                icon: Icons.account_tree_outlined,
                label: 'Axle Type',
                value: vehicle.axleType != null
                    ? enumLabel(vehicle.axleType!)
                    : '-',
              ),
              _Detail(
                icon: Icons.inventory_2_outlined,
                label: 'Body Type',
                value: vehicle.containerBodyType != null
                    ? enumLabel(vehicle.containerBodyType!)
                    : '-',
              ),
            ],
              _Detail(
                icon: AppIcons.gauge,
                label: 'Expected KML',
                value: vehicle.expectedKml != null
                    ? '${vehicle.expectedKml} km/l'
                    : '-',
              ),
              _Detail(
                icon: AppIcons.droplets,
                label: 'Tank Capacity',
                value: vehicle.tankCapacity != null
                    ? '${vehicle.tankCapacity} L'
                    : '-',
              ),
              _Detail(
                icon: AppIcons.wrench,
                label: 'Last Service',
                value: vehicle.lastServiceDate ?? '-',
              ),
            ],
          ),
          const SizedBox(height: 22),
          _SheetActionButton(
            onPressed: onDocuments,
            icon: const Icon(AppIcons.fileText),
            label: 'Documents',
          ),
          if (canWrite)
            _SheetActionButton(
              onPressed: onEdit,
              icon: const Icon(AppIcons.pencil),
              label: 'Edit',
            ),
          if (canDelete)
            _SheetActionButton(
              onPressed: onDelete,
              icon: const Icon(AppIcons.trash2),
              label: 'Delete',
              destructive: true,
            ),
        ],
      ),
    ),
  );
}

Color _vehicleStatusColor(String status) {
  switch (status) {
    case 'Active':
      return AppColors.success;
    case 'Maintenance':
      return AppColors.warning;
    case 'Idle':
      return AppColors.textSecondary;
    default:
      return AppColors.textMuted;
  }
}

class _DetailSection extends StatelessWidget {
  final List<Widget> children;

  const _DetailSection({required this.children});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.035),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Column(children: children),
  );
}

class _SheetActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget icon;
  final String label;
  final bool destructive;

  const _SheetActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(58),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        backgroundColor: destructive
            ? AppColors.error.withValues(alpha: 0.04)
            : Colors.white,
        foregroundColor: destructive ? AppColors.error : AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(
          color: destructive
              ? AppColors.error.withValues(alpha: 0.22)
              : AppColors.primary.withValues(alpha: 0.22),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      child: Row(
        children: [
          IconTheme(
            data: IconThemeData(
              color: destructive ? AppColors.error : AppColors.primary,
              size: 20,
            ),
            child: icon,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: destructive ? AppColors.error : AppColors.primary,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
          Icon(
            AppIcons.chevronRight,
            color: destructive ? AppColors.error : AppColors.primary,
          ),
        ],
      ),
    ),
  );
}

class _Detail extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? statusColor;

  const _Detail({
    required this.icon,
    required this.label,
    required this.value,
  }) : statusColor = null;

  const _Detail.status({
    required this.icon,
    required this.label,
    required this.value,
    required Color color,
  }) : statusColor = color;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 380;
    final iconSize = compact ? 38.0 : 42.0;
    final horizontalPadding = compact ? 14.0 : 18.0;
    final labelFontSize = compact ? 13.5 : 14.5;
    final valueFontSize = compact ? 13.5 : 14.5;

    return Container(
      constraints: BoxConstraints(minHeight: compact ? 62 : 68),
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: compact ? 10 : 12,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: AppColors.primary, size: compact ? 19 : 21),
          ),
          SizedBox(width: compact ? 12 : 16),
          Expanded(
            flex: 6,
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: labelFontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          statusColor == null
              ? Expanded(
                  flex: 4,
                  child: Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: valueFontSize,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                )
              : _DetailStatusPill(
                  label: value,
                  color: statusColor!,
                  compact: compact,
                ),
        ],
      ),
    );
  }
}

class _DetailStatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool compact;

  const _DetailStatusPill({
    required this.label,
    required this.color,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 9 : 11,
      vertical: compact ? 7 : 8,
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 8 : 9,
          height: compact ? 8 : 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: compact ? 6 : 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: compact ? 13.5 : 14.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}
