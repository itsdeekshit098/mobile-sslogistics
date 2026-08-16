import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../shared/data/bank_account_models.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/debounced_search_field.dart';
import '../../../shared/widgets/delete_confirmation_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/list_pagination_bar.dart';
import '../../../shared/widgets/notification_bell_button.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/bank_accounts_provider.dart';
import '../widgets/bank_account_card.dart';
import '../widgets/bank_account_form_sheet.dart';

/// Our own bank accounts — recorded so a loan can say which account its EMI
/// mandate debits from. Create-only on mobile, mirroring the loan form's
/// inline "+ Add new account" flow; editing happens on web for now.
class BankAccountsScreen extends ConsumerWidget {
  const BankAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bankAccountsListProvider);
    final user = ref.watch(authProvider).valueOrNull;
    final canManage = user?.isAdmin == true;
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
          'Bank Accounts',
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
      drawer: const AppDrawer(currentPath: '/bank-accounts'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: DebouncedSearchField(
              hintText: 'Search by bank, nickname or number',
              onDebouncedChanged: (q) => ref.read(bankAccountsListProvider.notifier).search(q),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const SkeletonListCards(infoLines: 1),
              error: (e, _) => ErrorState(
                message: e.toString().replaceFirst('Exception: ', ''),
                onRetry: () => ref.invalidate(bankAccountsListProvider),
              ),
              data: (state) {
                if (state.items.isEmpty) {
                  return EmptyState(
                    title: 'No bank accounts yet',
                    subtitle: 'Add the accounts loans auto-debit from.',
                    actionLabel: canManage ? 'Add' : null,
                    onAction: canManage ? () => _showForm(context, ref) : null,
                  );
                }
                return Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => ref.read(bankAccountsListProvider.notifier).refresh(),
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 4, bottom: 8),
                          itemCount: state.items.length,
                          itemBuilder: (context, i) {
                            final account = state.items[i];
                            return BankAccountCard(
                              key: ValueKey(account.id),
                              account: account,
                              canManage: canManage,
                              onTap: () {},
                              onDelete: () => _delete(context, ref, account),
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
                      itemLabel: 'accounts',
                      endPadding: 86,
                      onPageChange: ref.read(bankAccountsListProvider.notifier).changePage,
                      onPageSizeChange: ref.read(bankAccountsListProvider.notifier).changePageSize,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: canManage && async.hasValue
          ? FloatingActionButton(
              onPressed: () => _showForm(context, ref),
              backgroundColor: AppColors.tileBankIcon,
              foregroundColor: Colors.white,
              child: const Icon(AppIcons.plus),
            )
          : null,
    );
  }

  void _showForm(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        child: BankAccountFormSheet(
          onSubmit: ({
            required holderEntityId,
            required bankName,
            required accountNumber,
            required accountType,
            ifsc,
            branch,
            nickname,
            notes,
          }) =>
              ref.read(bankAccountsListProvider.notifier).createAccount(
                    holderEntityId: holderEntityId,
                    bankName: bankName,
                    accountNumber: accountNumber,
                    accountType: accountType,
                    ifsc: ifsc,
                    branch: branch,
                    nickname: nickname,
                    notes: notes,
                  ),
        ),
      ),
    );
  }

  void _delete(BuildContext context, WidgetRef ref, BankAccount account) {
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeleteConfirmationDialog(
        title: 'Delete Bank Account',
        targetName: account.displayLabel,
        warningText: 'This action cannot be undone.',
        warningSubtext: 'Accounts referenced by loans must be reassigned first.',
        onConfirm: () => ref.read(bankAccountsListProvider.notifier).deleteAccount(account.id),
      ),
    );
  }
}
