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
import '../../auth/providers/auth_provider.dart';
import '../data/owner_models.dart';
import '../providers/owners_provider.dart';
import '../widgets/owner_card.dart';
import '../widgets/owner_filter_sheet.dart';
import '../widgets/owner_form_sheet.dart';

class OwnersScreen extends ConsumerWidget {
  const OwnersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ownersListProvider);
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
          'Vehicle Owners',
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
      drawer: const AppDrawer(currentPath: '/vehicle-owners'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: DebouncedSearchField(
                    hintText: 'Search owner name',
                    onDebouncedChanged: (q) => ref.read(ownersListProvider.notifier).search(q),
                  ),
                ),
                const SizedBox(width: 10),
                _FilterButton(
                  activeCount: state?.ownerTypeFilter != null ? 1 : 0,
                  onTap: () => _showFilterSheet(context, ref, state?.ownerTypeFilter),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorState(
                message: e.toString().replaceFirst('Exception: ', ''),
                onRetry: () => ref.invalidate(ownersListProvider),
              ),
              data: (state) {
                if (state.owners.isEmpty) {
                  return EmptyState(
                    title: 'No owners found',
                    subtitle: state.search.isEmpty
                        ? 'No vehicle owners have been added yet.'
                        : 'No owners match your search.',
                    actionLabel: canWrite ? 'Add Owner' : null,
                    onAction: canWrite ? () => _showForm(context, ref, null) : null,
                  );
                }
                return Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => ref.read(ownersListProvider.notifier).refresh(),
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 4, bottom: 8),
                          itemCount: state.owners.length,
                          itemBuilder: (context, i) {
                            final owner = state.owners[i];
                            return OwnerCard(
                              key: ValueKey(owner.id),
                              owner: owner,
                              canManage: canManage,
                              onTap: canWrite ? () => _showForm(context, ref, owner) : () {},
                              onEdit: () => _showForm(context, ref, owner),
                              onDelete: () => _delete(context, ref, owner),
                            );
                          },
                        ),
                      ),
                    ),
                    ListPaginationBar(
                      page: state.page,
                      totalPages: state.totalPages,
                      total: state.total,
                      pageSize: state.pageSize,
                      itemLabel: 'owners',
                      endPadding: 86,
                      onPageChange: ref.read(ownersListProvider.notifier).changePage,
                      onPageSizeChange: ref.read(ownersListProvider.notifier).changePageSize,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: canWrite && async.hasValue
          ? FloatingActionButton(
              onPressed: () => _showForm(context, ref, null),
              backgroundColor: AppColors.tileOwnersIcon,
              foregroundColor: Colors.white,
              child: const Icon(AppIcons.plus),
            )
          : null,
    );
  }

  Future<void> _showFilterSheet(BuildContext context, WidgetRef ref, String? ownerType) async {
    final result = await showModalBottomSheet<OwnerFilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OwnerFilterSheet(ownerType: ownerType),
    );
    if (result != null) {
      ref.read(ownersListProvider.notifier).setOwnerTypeFilter(result.ownerType);
    }
  }

  void _showForm(BuildContext context, WidgetRef ref, VehicleOwner? owner) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.55,
        child: OwnerFormSheet(
          owner: owner,
          onSubmit: (create, update) async {
            final notifier = ref.read(ownersListProvider.notifier);
            if (create != null) {
              await notifier.createOwner(create);
            } else if (update != null) {
              await notifier.updateOwner(update);
            }
          },
        ),
      ),
    );
  }

  void _delete(BuildContext context, WidgetRef ref, VehicleOwner owner) {
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeleteConfirmationDialog(
        title: 'Delete Owner',
        targetName: owner.name,
        warningText: 'This action cannot be undone.',
        warningSubtext: 'Owners referenced by vehicles must be reassigned first.',
        onConfirm: () => ref.read(ownersListProvider.notifier).deleteOwner(owner.id),
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

