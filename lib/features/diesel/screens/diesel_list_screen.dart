import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_sslogistics/core/constants/app_icons.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/notifications/providers/notification_provider.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/loading_spinner.dart';
import '../../../shared/widgets/error_state.dart';
import '../providers/diesel_provider.dart';
import '../widgets/diesel_card.dart';
import '../widgets/diesel_filter_bar.dart';
import '../widgets/diesel_pagination_bar.dart';
import '../widgets/create_diesel_sheet.dart';
import '../widgets/diesel_detail_sheet.dart';
import '../widgets/edit_diesel_sheet.dart';
import '../widgets/delete_confirm_dialog.dart';
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
    final unreadCount =
        ref.watch(notificationListProvider).valueOrNull?.unreadCount ?? 0;

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
          'Diesel Records',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
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
                  const LoadingSpinner(message: 'Loading records...'),
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
                          const Divider(height: 1, color: AppColors.border),
                          DieselPaginationBar(
                            state: state,
                            onPageChange: (page) => ref
                                .read(dieselListProvider.notifier)
                                .changePage(page),
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
      builder: (_) => DeleteConfirmDialog(
        vehiclePlate: record.vehiclePlate,
        date: dateStr,
        driverName: record.driverName,
        fuelLitres: record.fuelLitres,
        onConfirm: () async {
          try {
            await ref.read(dieselListProvider.notifier).deleteRecord(record.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Record deleted'),
                  backgroundColor: AppColors.success,
                ),
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

class _NoVehicleSelectedState extends StatelessWidget {
  const _NoVehicleSelectedState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 56, 32, 80),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            _DieselEmptyIllustration(),
            SizedBox(height: 34),
            Text(
              'No vehicle selected',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 14),
            Text(
              'Select a vehicle to view its\ndiesel records and mileage.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.55,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoRecordsForVehicleState extends StatelessWidget {
  const _NoRecordsForVehicleState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 40, 32, 80),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            _DieselEmptyIllustration(),
            SizedBox(height: 30),
            Text(
              'No diesel records',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 14),
            Text(
              'No diesel entries found for\nthe selected vehicle.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.55,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DieselEmptyIllustration extends StatelessWidget {
  const _DieselEmptyIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 24,
            child: Container(
              width: 230,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.tileVehiclesBg.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(90),
              ),
            ),
          ),
          Positioned(top: 42, left: 46, child: _Cloud(width: 58, height: 18)),
          Positioned(top: 20, right: 72, child: _Cloud(width: 46, height: 15)),
          Positioned(top: 74, right: 38, child: _Cloud(width: 42, height: 13)),
          Positioned(
            bottom: 34,
            left: 50,
            child: _Tree(color: AppColors.success.withValues(alpha: 0.35)),
          ),
          Positioned(
            bottom: 36,
            right: 42,
            child: _Tree(color: AppColors.success.withValues(alpha: 0.32)),
          ),
          Positioned(
            top: 76,
            child: Container(
              width: 116,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF7C8DA5), width: 6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Padding(
                padding: EdgeInsets.fromLTRB(24, 36, 16, 12),
                child: Column(
                  children: [
                    _ChecklistLine(),
                    SizedBox(height: 14),
                    _ChecklistLine(),
                    SizedBox(height: 14),
                    _ChecklistLine(),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 62,
            child: Container(
              width: 58,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF7C8DA5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 54,
            bottom: 44,
            child: SizedBox(
              width: 106,
              height: 70,
              child: Stack(
                children: [
                  Positioned(
                    right: 0,
                    top: 13,
                    child: Container(
                      width: 70,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF9BA9BA),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 28,
                    child: Container(
                      width: 44,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFF344255),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(10),
                          bottomLeft: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 24,
                    top: 32,
                    child: Container(
                      width: 20,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const Positioned(left: 30, bottom: 0, child: _Wheel()),
                  const Positioned(right: 32, bottom: 0, child: _Wheel()),
                  const Positioned(right: 8, bottom: 0, child: _Wheel()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Cloud extends StatelessWidget {
  final double width;
  final double height;

  const _Cloud({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.tileVehiclesBg,
        borderRadius: BorderRadius.circular(height),
      ),
    );
  }
}

class _Tree extends StatelessWidget {
  final Color color;

  const _Tree({required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 22,
          height: 38,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        Container(width: 2, height: 26, color: AppColors.textMuted),
      ],
    );
  }
}

class _ChecklistLine extends StatelessWidget {
  const _ChecklistLine();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_rounded, size: 17, color: AppColors.success),
        const SizedBox(width: 9),
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    );
  }
}

class _Wheel extends StatelessWidget {
  const _Wheel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
    );
  }
}
