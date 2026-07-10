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
import '../data/warranty_models.dart';
import '../providers/warranty_provider.dart';
import '../widgets/warranty_card.dart';
import '../widgets/warranty_detail_sheet.dart';
import '../widgets/warranty_filter_sheet.dart';
import '../widgets/warranty_form_sheet.dart';

class WarrantyScreen extends ConsumerWidget {
  const WarrantyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(warrantyProvider);
    final user = ref.watch(authProvider).valueOrNull;
    final canEdit = user?.canEdit == true;
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
          'Warranty',
          style: TextStyle(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      drawer: const AppDrawer(currentPath: '/warranty'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: DebouncedSearchField(
                    hintText: 'Search part name',
                    onDebouncedChanged: (q) => ref.read(warrantyProvider.notifier).setSearch(q),
                  ),
                ),
                const SizedBox(width: 10),
                _FilterButton(
                  activeCount: state?.filters.activeCount ?? 0,
                  onTap: () => _showFilterSheet(context, ref, state?.filters ?? const WarrantyFilters()),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorState(
                message: e.toString().replaceFirst('Exception: ', ''),
                onRetry: () => ref.invalidate(warrantyProvider),
              ),
              data: (state) {
                if (state.items.isEmpty) {
                  return EmptyState(
                    title: 'No warranty records found',
                    subtitle: state.filters.hasActiveFilters || state.filters.search.isNotEmpty
                        ? 'No records match your filters.'
                        : 'No parts warranty has been added yet.',
                    actionLabel: canEdit ? 'Add Warranty' : null,
                    onAction: canEdit ? () => _showForm(context, ref, null) : null,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(warrantyProvider.notifier).refresh(),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 4, bottom: 8),
                          itemCount: state.items.length,
                          itemBuilder: (context, i) {
                            final item = state.items[i];
                            return WarrantyCard(
                              key: ValueKey(item.id),
                              item: item,
                              onTap: () => _showDetail(context, ref, item, canEdit),
                            );
                          },
                        ),
                      ),
                      ListPaginationBar(
                        page: state.page,
                        totalPages: state.totalPages,
                        total: state.total,
                        pageSize: state.pageSize,
                        itemLabel: 'records',
                        onPageChange: ref.read(warrantyProvider.notifier).changePage,
                        onPageSizeChange: ref.read(warrantyProvider.notifier).changePageSize,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: canEdit && async.hasValue
          ? FloatingActionButton(
              onPressed: () => _showForm(context, ref, null),
              backgroundColor: AppColors.tileWarrantyIcon,
              foregroundColor: Colors.white,
              child: const Icon(AppIcons.plus),
            )
          : null,
    );
  }

  Future<void> _showFilterSheet(BuildContext context, WidgetRef ref, WarrantyFilters current) async {
    final result = await showModalBottomSheet<WarrantyFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WarrantyFilterSheet(initial: current),
    );
    if (result != null) {
      ref.read(warrantyProvider.notifier).setFilters(result);
    }
  }

  void _showForm(BuildContext context, WidgetRef ref, WarrantyItem? item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        child: WarrantyFormSheet(
          item: item,
          onSubmit: (dto) => ref.read(warrantyProvider.notifier).createOrUpdate(dto),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, WidgetRef ref, WarrantyItem item, bool canEdit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.75,
        child: WarrantyDetailSheet(
          item: item,
          canEdit: canEdit,
          onEdit: () {
            Navigator.pop(context);
            _showForm(context, ref, item);
          },
          onDelete: () {
            Navigator.pop(context);
            _confirmDelete(context, ref, item);
          },
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, WarrantyItem item) {
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeleteConfirmationDialog(
        title: 'Delete Warranty Record',
        targetName: item.partName,
        warningText: 'This action cannot be undone.',
        warningSubtext: item.isLinkedToRepair
            ? 'This part is linked to a repair record.'
            : 'This will permanently remove the warranty record.',
        onConfirm: () => ref.read(warrantyProvider.notifier).deleteItem(item.id),
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
          border: Border.all(color: activeCount > 0 ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.border)),
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
