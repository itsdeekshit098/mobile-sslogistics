import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_sslogistics/core/constants/app_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/notifications/providers/notification_provider.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../data/repair_models.dart';
import '../providers/repair_provider.dart';
import '../widgets/create_repair_sheet.dart';
import '../widgets/delete_repair_dialog.dart';
import '../widgets/edit_repair_sheet.dart';
import '../widgets/repair_card.dart';
import '../widgets/repair_detail_sheet.dart';
import '../widgets/repair_filter_bar.dart';
import '../widgets/repair_summary_chips.dart';

class RepairListScreen extends ConsumerStatefulWidget {
  /// Pre-selects a vehicle (e.g. arriving from a notification's deep link).
  final int? initialVehicleId;

  const RepairListScreen({super.key, this.initialVehicleId});

  @override
  ConsumerState<RepairListScreen> createState() => _RepairListScreenState();
}

class _RepairListScreenState extends ConsumerState<RepairListScreen> {
  @override
  void initState() {
    super.initState();
    final vehicleId = widget.initialVehicleId;
    if (vehicleId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(repairListProvider.notifier).setFilters(
              RepairFilters(vehicleId: vehicleId),
            );
      });
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.pixels >= notification.metrics.maxScrollExtent * 0.8) {
      ref.read(repairListProvider.notifier).loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull;
    final listAsync = ref.watch(repairListProvider);
    final unreadCount = ref.watch(notificationListProvider).valueOrNull?.unreadCount ?? 0;

    final canCreate = (user?.isAdmin ?? false) || (user?.isStaff ?? false);
    final canEdit = user?.isAdmin ?? false;
    final canDelete = user?.isAdmin ?? false;

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(AppIcons.menu, color: AppColors.textPrimary),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text(
          'Repair Records',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(AppIcons.bell, color: AppColors.textPrimary),
                  onPressed: () => context.push('/notifications'),
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 16),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(currentPath: '/repair-records'),
      body: Column(
        children: [
          const RepairFilterBar(),
          Expanded(
            child: listAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorState(
                message: e.toString().replaceFirst('Exception: ', ''),
                onRetry: () => ref.invalidate(repairListProvider),
              ),
              data: (state) {
                if (state.records.isEmpty) {
                  return EmptyState(
                    title: 'No repair records',
                    subtitle: state.filters.isEmpty
                        ? 'No repair records have been added yet.'
                        : 'No records match the current filters.',
                    actionLabel: canCreate ? 'Add Repair Record' : null,
                    onAction: canCreate ? () => _showCreateSheet(context) : null,
                  );
                }

                final showVehicleColumn = state.filters.vehicleId == null;

                return RefreshIndicator(
                  color: AppColors.tileRepairIcon,
                  onRefresh: () => ref.read(repairListProvider.notifier).refresh(),
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _onScrollNotification,
                    child: CustomScrollView(
                      slivers: [
                        if (state.summary != null)
                          SliverToBoxAdapter(
                            child: RepairSummaryChips(summary: state.summary!),
                          ),
                        SliverPadding(
                          padding: const EdgeInsets.only(top: 4, bottom: 8),
                          sliver: SliverList.builder(
                            itemCount: state.records.length,
                            itemBuilder: (context, i) {
                              final record = state.records[i];
                              return RepairCard(
                                key: ValueKey(record.id),
                                record: record,
                                showVehicle: showVehicleColumn,
                                canEdit: canEdit,
                                canDelete: canDelete,
                                onTap: () => _showDetailSheet(
                                  context,
                                  ref,
                                  record,
                                  canEdit: canEdit,
                                  canDelete: canDelete,
                                ),
                                onEdit: () => _showEditSheet(context, record),
                                onDelete: () => _showDeleteDialog(context, ref, record),
                              );
                            },
                          ),
                        ),
                        if (state.isLoadingMore)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.4),
                                ),
                              ),
                            ),
                          ),
                        const SliverToBoxAdapter(child: SizedBox(height: 72)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              onPressed: () => _showCreateSheet(context),
              backgroundColor: AppColors.tileRepairIcon,
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
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.93,
        child: CreateRepairSheet(),
      ),
    );
  }

  void _showEditSheet(BuildContext context, RepairRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.93,
        child: EditRepairSheet(record: record),
      ),
    );
  }

  void _showDetailSheet(
    BuildContext context,
    WidgetRef ref,
    RepairRecord record, {
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
        child: RepairDetailSheet(
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

  void _showDeleteDialog(BuildContext context, WidgetRef ref, RepairRecord record) {
    final date = DateTime.tryParse(record.repairDate)?.toLocal();
    final dateStr = date != null
        ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
        : record.repairDate;

    showDialog(
      context: context,
      builder: (_) => DeleteRepairDialog(
        vehicleNumber: record.vehicleNumber,
        date: dateStr,
        category: record.categoryLabel,
        cost: record.cost,
        onConfirm: () async {
          try {
            await ref.read(repairListProvider.notifier).deleteRecord(record.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Repair record deleted'), backgroundColor: AppColors.success),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(e.toString().replaceFirst('Exception: ', '')),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }
        },
      ),
    );
  }
}
