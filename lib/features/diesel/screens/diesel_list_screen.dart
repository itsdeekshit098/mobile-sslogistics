import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_sslogistics/core/constants/app_icons.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../../../shared/widgets/notification_bell_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../providers/diesel_provider.dart';
import '../widgets/diesel_card.dart';
import '../widgets/diesel_filter_bar.dart';
import '../../../shared/widgets/list_pagination_bar.dart';
import '../widgets/create_diesel_sheet.dart';
import '../widgets/diesel_detail_sheet.dart';
import '../widgets/edit_diesel_sheet.dart';
import '../../../shared/widgets/delete_confirmation_dialog.dart';
import '../data/diesel_models.dart';

class DieselListScreen extends ConsumerStatefulWidget {
  /// Pre-selects a vehicle (e.g. arriving from a notification's deep
  /// link) instead of requiring the user to pick one from the filter bar.
  final int? initialVehicleId;

  const DieselListScreen({super.key, this.initialVehicleId});

  @override
  ConsumerState<DieselListScreen> createState() => _DieselListScreenState();
}

class _DieselListScreenState extends ConsumerState<DieselListScreen> {
  @override
  void initState() {
    super.initState();
    final vehicleId = widget.initialVehicleId;
    if (vehicleId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(dieselListProvider.notifier).filterByVehicle(vehicleId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull;
    final listAsync = ref.watch(dieselListProvider);
    final selectedVehicleId = listAsync.valueOrNull?.selectedVehicleId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkPageBg : AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkCardBg : Colors.white,
        elevation: 0,
        surfaceTintColor: isDark ? AppColors.darkCardBg : Colors.white,
        leading: IconButton(
          icon: Icon(
            AppIcons.arrowLeft,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
          onPressed: () => context.go('/dashboard'),
          tooltip: 'Back',
        ),
        title: Text(
          'Diesel Records',
          style: TextStyle(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          NotificationBellButton(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
          Builder(
            builder: (ctx) => IconButton(
              icon: Icon(
                AppIcons.menu,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
              tooltip: 'Open menu',
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(currentPath: '/diesel-records'),
      body: Column(
        children: [
          const DieselFilterBar(),
          Expanded(
            child: listAsync.when(
              loading: () =>
                  const SkeletonListCards(shape: SkeletonCardShape.band, infoLines: 2),
              error: (e, _) => ErrorState(
                message: e.toString().replaceFirst('Exception: ', ''),
                onRetry: () => ref.invalidate(dieselListProvider),
              ),
              data: (state) {
                if (state.selectedVehicleId == null) {
                  return const _NoVehicleSelectedState();
                }

                if (state.records.isEmpty) {
                  return const _NoRecordsForVehicleState();
                }

                return RefreshIndicator(
                  color: AppColors.tileDieselIcon,
                  onRefresh: () async => ref.invalidate(dieselListProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: state.records.length,
                    itemBuilder: (context, i) {
                      final record = state.records[i];
                      return DieselCard(
                        record: record,
                        canEdit: user?.canEdit ?? false,
                        canDelete: user?.canDelete ?? false,
                        onTap: () => _showDetailSheet(
                          context,
                          ref,
                          record,
                          canEdit: user?.canEdit ?? false,
                          canDelete: user?.canDelete ?? false,
                        ),
                        onEdit: () => _showEditSheet(context, record),
                        onDelete: () => _showDeleteDialog(context, ref, record),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          listAsync.whenOrNull(
                data: (state) => state.selectedVehicleId == null
                    ? const SizedBox.shrink()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Divider(
                            height: 1,
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.border,
                          ),
                          ListPaginationBar(
                            page: state.page,
                            totalPages: state.totalPages,
                            total: state.total,
                            pageSize: state.pageSize,
                            itemLabel: 'records',
                            endPadding: 96,
                            onPageChange: (page) => ref
                                .read(dieselListProvider.notifier)
                                .changePage(page),
                            onPageSizeChange: (size) => ref
                                .read(dieselListProvider.notifier)
                                .changePageSize(size),
                          ),
                        ],
                      ),
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      floatingActionButton:
          (user?.canCreate ?? false) && selectedVehicleId != null
          ? FloatingActionButton(
              onPressed: () => _showCreateSheet(context),
              backgroundColor: AppColors.tileDieselIcon,
              foregroundColor: Colors.white,
              child: const Icon(AppIcons.plus),
            )
          : null,
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.93,
        child: const CreateDieselSheet(),
      ),
    );
  }

  void _showEditSheet(BuildContext context, DieselRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.90,
        child: EditDieselSheet(record: record),
      ),
    );
  }

  void _showDetailSheet(
    BuildContext context,
    WidgetRef ref,
    DieselRecord record, {
    required bool canEdit,
    required bool canDelete,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.94,
        child: DieselDetailSheet(
          record: record,
          canEdit: canEdit,
          canDelete: canDelete,
          onEdit: canEdit
              ? () {
                  Navigator.pop(context);
                  _showEditSheet(context, record);
                }
              : null,
          onDelete: canDelete
              ? () {
                  Navigator.pop(context);
                  _showDeleteDialog(context, ref, record);
                }
              : null,
        ),
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    DieselRecord record,
  ) {
    final fillDate = DateTime.tryParse(record.fillDate)?.toLocal();
    final dateStr = fillDate != null
        ? DateFormat('dd MMM yyyy').format(fillDate)
        : record.fillDate;

    showDialog(
      context: context,
      builder: (_) => DeleteConfirmationDialog(
        title: 'Delete Record',
        targetName: '$dateStr - ${record.vehiclePlate}',
        details: {
          'Date': dateStr,
          'Vehicle': record.vehiclePlate,
          'Driver': record.driverName,
          'Fuel': '${record.fuelLitres.toStringAsFixed(1)} L',
        },
        warningText: 'This action cannot be undone.',
        warningSubtext: 'The diesel record will be permanently removed.',
        onConfirm: () =>
            ref.read(dieselListProvider.notifier).deleteRecord(record.id),
      ),
    );
  }
}

class _NoVehicleSelectedState extends StatelessWidget {
  const _NoVehicleSelectedState();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: AppIcons.fuel,
      title: 'No vehicle selected',
      subtitle: 'Select a vehicle to view its diesel records and mileage.',
    );
  }
}

class _NoRecordsForVehicleState extends StatelessWidget {
  const _NoRecordsForVehicleState();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: AppIcons.fuel,
      title: 'No diesel records',
      subtitle: 'No diesel entries found for the selected vehicle.',
    );
  }
}
