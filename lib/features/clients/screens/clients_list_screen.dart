import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../shared/utils/money_format.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/debounced_search_field.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/list_pagination_bar.dart';
import '../../../shared/widgets/notification_bell_button.dart';
import '../../../shared/widgets/selectable_chip.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../../../shared/widgets/summary_strip.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/client_models.dart';
import '../providers/client_provider.dart';
import '../widgets/client_card.dart';
import '../widgets/client_form_sheet.dart';

class ClientsListScreen extends ConsumerWidget {
  const ClientsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(clientListProvider);
    final user = ref.watch(authProvider).valueOrNull;
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
          icon: Icon(AppIcons.arrowLeft,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
          onPressed: () => context.go('/dashboard'),
        ),
        title: Text(
          'Clients',
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
              icon: Icon(AppIcons.menu,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(currentPath: '/clients'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: DebouncedSearchField(
                    hintText: 'Search by name, location or GST...',
                    onDebouncedChanged: (q) => ref.read(clientListProvider.notifier).search(q),
                  ),
                ),
                const SizedBox(width: 10),
                _DuesToggle(
                  active: state?.filters.hasDues ?? false,
                  onTap: () => ref.read(clientListProvider.notifier).applyFilters(
                        (state?.filters ?? ClientFilters.none)
                            .copyWith(hasDues: !(state?.filters.hasDues ?? false)),
                      ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                SelectableChip(
                  label: 'All',
                  selected: state?.filters.partyKind == null,
                  onTap: () => ref.read(clientListProvider.notifier).applyFilters(
                        (state?.filters ?? ClientFilters.none).copyWith(clearPartyKind: true),
                      ),
                ),
                const SizedBox(width: 8),
                SelectableChip(
                  label: 'Companies',
                  selected: state?.filters.partyKind == 'COMPANY',
                  onTap: () => ref.read(clientListProvider.notifier).applyFilters(
                        (state?.filters ?? ClientFilters.none).copyWith(partyKind: 'COMPANY'),
                      ),
                ),
                const SizedBox(width: 8),
                SelectableChip(
                  label: 'Individuals',
                  selected: state?.filters.partyKind == 'INDIVIDUAL',
                  onTap: () => ref.read(clientListProvider.notifier).applyFilters(
                        (state?.filters ?? ClientFilters.none).copyWith(partyKind: 'INDIVIDUAL'),
                      ),
                ),
              ],
            ),
          ),
          if (state?.extras != null) SummaryStrip(stats: _summaryStats(state!.extras!)),
          Expanded(
            child: async.when(
              loading: () =>
                  const SkeletonListCards(shape: SkeletonCardShape.plain, infoLines: 2),
              error: (e, _) => ErrorState(
                message: e.toString().replaceFirst('Exception: ', ''),
                onRetry: () => ref.invalidate(clientListProvider),
              ),
              data: (state) {
                if (state.items.isEmpty) {
                  return EmptyState(
                    title: 'No clients found',
                    subtitle: state.hasFilters
                        ? 'Try adjusting your search or filter.'
                        : 'Add the companies your vehicles run for to start tracking what they owe.',
                    actionLabel: canManage ? 'Add Client' : null,
                    onAction: canManage ? () => _showForm(context, ref) : null,
                    icon: AppIcons.building2,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(clientListProvider.notifier).refresh(),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 4, bottom: 8),
                          itemCount: state.items.length,
                          itemBuilder: (context, i) {
                            final client = state.items[i];
                            return ClientCard(
                              key: ValueKey(client.id),
                              client: client,
                              onTap: () => context.push('/clients/detail?id=${client.id}'),
                            );
                          },
                        ),
                      ),
                      ListPaginationBar(
                        page: state.page,
                        totalPages: state.totalPages,
                        total: state.total,
                        pageSize: state.pageSize,
                        itemLabel: 'clients',
                        endPadding: 86,
                        onPageChange: ref.read(clientListProvider.notifier).changePage,
                        onPageSizeChange: ref.read(clientListProvider.notifier).changePageSize,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: canManage && async.hasValue
          ? FloatingActionButton(
              onPressed: () => _showForm(context, ref),
              backgroundColor: AppColors.tileClientsIcon,
              foregroundColor: Colors.white,
              child: const Icon(AppIcons.plus),
            )
          : null,
    );
  }

  List<SummaryStat> _summaryStats(ClientSummary summary) => [
        SummaryStat(label: 'Clients', value: '${summary.totalClients}'),
        SummaryStat(
          label: 'Outstanding',
          value: formatRupees(summary.totalOutstanding),
          color: summary.totalOutstanding > 0 ? AppColors.error : AppColors.success,
        ),
        SummaryStat(label: 'With Dues', value: '${summary.clientsWithDues}'),
        SummaryStat(label: 'Advance', value: formatRupees(summary.totalAdvance)),
      ];

  void _showForm(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        child: ClientFormSheet(
          onSubmit: ({
            name,
            required clientType,
            required partyKind,
            entityId,
            receivingAccountId,
            location,
            address,
            gstNumber,
            notes,
            openingBalance,
            openingDate,
          }) =>
              ref.read(clientListProvider.notifier).createClient(
                    name: name,
                    clientType: clientType,
                    partyKind: partyKind,
                    entityId: entityId,
                    receivingAccountId: receivingAccountId,
                    location: location,
                    address: address,
                    gstNumber: gstNumber,
                    notes: notes,
                    openingBalance: openingBalance,
                    openingDate: openingDate,
                  ),
        ),
      ),
    );
  }
}

class _DuesToggle extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _DuesToggle({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withValues(alpha: 0.1) : (isDark ? AppColors.darkCardBg : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.border)),
        ),
        child: Text(
          'Owes money',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: active ? AppColors.primary : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}
