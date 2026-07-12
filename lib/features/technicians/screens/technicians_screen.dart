import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/debounced_search_field.dart';
import '../../../shared/widgets/delete_confirmation_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/list_pagination_bar.dart';
import '../../../shared/widgets/notification_bell_button.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/technician_models.dart';
import '../providers/technicians_provider.dart';
import '../widgets/technician_card.dart';
import '../widgets/technician_filter_sheet.dart';
import '../widgets/technician_form_sheet.dart';

class TechniciansScreen extends ConsumerWidget {
  const TechniciansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(techniciansListProvider);
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
        leading: IconButton(
          icon: Icon(AppIcons.arrowLeft, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
          onPressed: () => context.go('/dashboard'),
          tooltip: 'Back',
        ),
        title: Text(
          'Technicians',
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
              icon: Icon(AppIcons.menu, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
              tooltip: 'Open menu',
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(currentPath: '/technicians'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: DebouncedSearchField(
                    hintText: 'Search name, phone, location',
                    onDebouncedChanged: (q) => ref.read(techniciansListProvider.notifier).search(q),
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
              loading: () => const SkeletonListCards(),
              error: (e, _) => ErrorState(
                message: e.toString().replaceFirst('Exception: ', ''),
                onRetry: () => ref.invalidate(techniciansListProvider),
              ),
              data: (state) {
                if (state.technicians.isEmpty) {
                  return EmptyState(
                    title: 'No technicians found',
                    subtitle: state.search.isEmpty
                        ? 'No technicians have been added yet.'
                        : 'No technicians match your search.',
                    actionLabel: canWrite ? 'Add Technician' : null,
                    onAction: canWrite ? () => _showForm(context, ref, null) : null,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(techniciansListProvider.notifier).refresh(),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 4, bottom: 8),
                          itemCount: state.technicians.length,
                          itemBuilder: (context, i) {
                            final technician = state.technicians[i];
                            return TechnicianCard(
                              key: ValueKey(technician.id),
                              technician: technician,
                              canManage: canManage,
                              onTap: canWrite ? () => _showForm(context, ref, technician) : () {},
                              onEdit: () => _showForm(context, ref, technician),
                              onToggleActive: () =>
                                  ref.read(techniciansListProvider.notifier).toggleActive(technician),
                              onDelete: () => _delete(context, ref, technician),
                            );
                          },
                        ),
                      ),
                      ListPaginationBar(
                        page: state.page,
                        totalPages: state.totalPages,
                        total: state.total,
                        pageSize: state.pageSize,
                        itemLabel: 'technicians',
                        endPadding: 86,
                        onPageChange: ref.read(techniciansListProvider.notifier).changePage,
                        onPageSizeChange: ref.read(techniciansListProvider.notifier).changePageSize,
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
              backgroundColor: AppColors.tileTechIcon,
              foregroundColor: Colors.white,
              child: const Icon(AppIcons.plus),
            )
          : null,
    );
  }

  Future<void> _showFilterSheet(BuildContext context, WidgetRef ref, bool includeInactive) async {
    final result = await showModalBottomSheet<TechnicianFilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TechnicianFilterSheet(includeInactive: includeInactive),
    );
    if (result != null) {
      ref.read(techniciansListProvider.notifier).toggleIncludeInactive(result.includeInactive);
    }
  }

  void _showForm(BuildContext context, WidgetRef ref, Technician? technician) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        child: TechnicianFormSheet(
          technician: technician,
          onSubmit: (create, update) async {
            final notifier = ref.read(techniciansListProvider.notifier);
            if (create != null) {
              await notifier.createTechnician(create);
            } else if (update != null) {
              await notifier.updateTechnician(update);
            }
          },
        ),
      ),
    );
  }

  void _delete(BuildContext context, WidgetRef ref, Technician technician) {
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeleteConfirmationDialog(
        title: 'Delete Technician',
        targetName: technician.name,
        warningText: 'This action cannot be undone.',
        warningSubtext: 'Technicians referenced by repair records cannot be deleted.',
        onConfirm: () => ref.read(techniciansListProvider.notifier).deleteTechnician(technician.id),
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
