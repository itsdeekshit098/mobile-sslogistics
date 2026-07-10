import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/debounced_search_field.dart';
import '../../../shared/widgets/delete_confirmation_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/list_pagination_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/driver_models.dart';
import '../providers/drivers_provider.dart';
import '../widgets/driver_card.dart';
import '../widgets/driver_filter_sheet.dart';
import '../widgets/driver_form_sheet.dart';

class DriversScreen extends ConsumerWidget {
  const DriversScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(driversListProvider);
    final user = ref.watch(authProvider).valueOrNull;
    final canWrite = user?.isAdmin == true || user?.isStaff == true;
    final canManage = user?.isAdmin == true;
    final state = async.valueOrNull;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkPageBg : AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkCardBg : Colors.white,
        elevation: 0,
        surfaceTintColor: isDark ? AppColors.darkCardBg : Colors.white,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Icon(AppIcons.menu, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(
          'Drivers',
          style: TextStyle(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      drawer: const AppDrawer(currentPath: '/drivers'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: DebouncedSearchField(
                    hintText: 'Search name, phone, place, DL number',
                    onDebouncedChanged: (q) => ref.read(driversListProvider.notifier).search(q),
                  ),
                ),
                const SizedBox(width: 10),
                _FilterButton(
                  activeCount: (state?.includeInactive ?? false) ? 1 : 0,
                  onTap: () => _showFilterSheet(context, ref, state?.includeInactive ?? false),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorState(
                message: e.toString().replaceFirst('Exception: ', ''),
                onRetry: () => ref.invalidate(driversListProvider),
              ),
              data: (state) {
                if (state.drivers.isEmpty) {
                  return EmptyState(
                    title: 'No drivers found',
                    subtitle: state.search.isEmpty
                        ? 'No drivers have been added yet.'
                        : 'No drivers match your search.',
                    actionLabel: canWrite ? 'Add Driver' : null,
                    onAction: canWrite ? () => _showForm(context, ref, null) : null,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(driversListProvider.notifier).refresh(),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 4, bottom: 8),
                          itemCount: state.drivers.length,
                          itemBuilder: (context, i) {
                            final driver = state.drivers[i];
                            return DriverCard(
                              key: ValueKey(driver.id),
                              driver: driver,
                              canManage: canManage,
                              onTap: canWrite ? () => _showForm(context, ref, driver) : () {},
                              onEdit: () => _showForm(context, ref, driver),
                              onToggleActive: () => ref.read(driversListProvider.notifier).toggleActive(driver),
                              onDelete: () => _delete(context, ref, driver),
                            );
                          },
                        ),
                      ),
                      ListPaginationBar(
                        page: state.page,
                        totalPages: state.totalPages,
                        total: state.total,
                        pageSize: state.pageSize,
                        itemLabel: 'drivers',
                        onPageChange: ref.read(driversListProvider.notifier).changePage,
                        onPageSizeChange: ref.read(driversListProvider.notifier).changePageSize,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: canWrite && async.hasValue
          ? FloatingActionButton(
              onPressed: () => _showForm(context, ref, null),
              backgroundColor: AppColors.tileDriversIcon,
              foregroundColor: Colors.white,
              child: const Icon(AppIcons.plus),
            )
          : null,
    );
  }

  Future<void> _showFilterSheet(BuildContext context, WidgetRef ref, bool includeInactive) async {
    final result = await showModalBottomSheet<DriverFilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DriverFilterSheet(includeInactive: includeInactive),
    );
    if (result != null) {
      ref.read(driversListProvider.notifier).toggleIncludeInactive(result.includeInactive);
    }
  }

  void _showForm(BuildContext context, WidgetRef ref, Driver? driver) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: DriverFormSheet(
          driver: driver,
          onSubmit: (create, update) async {
            final notifier = ref.read(driversListProvider.notifier);
            if (create != null) {
              await notifier.createDriver(create);
            } else if (update != null) {
              await notifier.updateDriver(update);
            }
          },
        ),
      ),
    );
  }

  void _delete(BuildContext context, WidgetRef ref, Driver driver) {
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeleteConfirmationDialog(
        title: 'Delete Driver',
        targetName: driver.name,
        warningText: 'This action cannot be undone.',
        warningSubtext: 'Drivers referenced by external trips cannot be deleted.',
        onConfirm: () => ref.read(driversListProvider.notifier).deleteDriver(driver.id),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final int activeCount;
  final VoidCallback onTap;

  const _FilterButton({required this.activeCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 46,
        width: 46,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCardBg : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: activeCount > 0 ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.border),
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Icon(
                Icons.filter_list_rounded,
                color: activeCount > 0 ? AppColors.primary : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
              ),
            ),
            if (activeCount > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    '$activeCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
