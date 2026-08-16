import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../shared/data/entity_models.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/debounced_search_field.dart';
import '../../../shared/widgets/delete_confirmation_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/list_pagination_bar.dart';
import '../../../shared/widgets/notification_bell_button.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/owners_provider.dart';
import '../widgets/owner_card.dart';
import '../widgets/owner_filter_sheet.dart';
import '../widgets/owner_form_sheet.dart';

/// "Firms & Owners" — the family's proprietorships, the people behind them,
/// and external parties whose vehicles are hired in. Renamed from "Vehicle
/// Owners" when the underlying table was absorbed into `entities`; the route
/// stays `/vehicle-owners` so nothing that links here breaks.
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
          'Firms & Owners',
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
                    hintText: 'Search name or phone',
                    onDebouncedChanged: (q) => ref.read(ownersListProvider.notifier).search(q),
                  ),
                ),
                const SizedBox(width: 10),
                _FilterButton(
                  activeCount: (state?.filters.isActive ?? false) ? 1 : 0,
                  onTap: () => _showFilterSheet(context, ref, state?.filters ?? const OwnerFilters()),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const SkeletonListCards(infoLines: 1),
              error: (e, _) => ErrorState(
                message: e.toString().replaceFirst('Exception: ', ''),
                onRetry: () => ref.invalidate(ownersListProvider),
              ),
              data: (state) {
                if (state.items.isEmpty) {
                  return EmptyState(
                    title: 'No entities found',
                    subtitle: state.hasFilters
                        ? 'No entities match your filters.'
                        : 'Add a proprietorship, a family member, or an external party.',
                    actionLabel: canWrite ? 'Add' : null,
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
                          itemCount: state.items.length,
                          itemBuilder: (context, i) {
                            final entity = state.items[i];
                            return OwnerCard(
                              key: ValueKey(entity.id),
                              entity: entity,
                              canManage: canManage,
                              onTap: canWrite ? () => _showForm(context, ref, entity) : () {},
                              onEdit: () => _showForm(context, ref, entity),
                              onDelete: () => _delete(context, ref, entity),
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
                      itemLabel: 'entities',
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

  Future<void> _showFilterSheet(BuildContext context, WidgetRef ref, OwnerFilters current) async {
    final result = await showModalBottomSheet<OwnerFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OwnerFilterSheet(initial: current),
    );
    if (result != null) {
      ref.read(ownersListProvider.notifier).setFilters(result);
    }
  }

  void _showForm(BuildContext context, WidgetRef ref, Entity? entity) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        child: OwnerFormSheet(
          entity: entity,
          onSubmit: ({
            required name,
            required entityKind,
            required relationship,
            proprietorEntityId,
            required clearProprietor,
            phone,
            email,
            pan,
            gstNumber,
            address,
            notes,
          }) {
            final notifier = ref.read(ownersListProvider.notifier);
            if (entity == null) {
              return notifier.createEntity(
                name: name,
                entityKind: entityKind,
                relationship: relationship,
                proprietorEntityId: proprietorEntityId,
                phone: phone,
                email: email,
                pan: pan,
                gstNumber: gstNumber,
                address: address,
                notes: notes,
              );
            }
            return notifier.updateEntity(
              id: entity.id,
              name: name,
              entityKind: entityKind,
              relationship: relationship,
              proprietorEntityId: proprietorEntityId,
              clearProprietor: clearProprietor,
              phone: phone,
              email: email,
              pan: pan,
              gstNumber: gstNumber,
              address: address,
              notes: notes,
            );
          },
        ),
      ),
    );
  }

  void _delete(BuildContext context, WidgetRef ref, Entity entity) {
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeleteConfirmationDialog(
        title: 'Delete Entity',
        targetName: entity.name,
        warningText: 'This action cannot be undone.',
        warningSubtext: 'Entities referenced by vehicles or loans must be reassigned first.',
        onConfirm: () => ref.read(ownersListProvider.notifier).deleteEntity(entity.id),
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
