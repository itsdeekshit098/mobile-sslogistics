import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/list_pagination_bar.dart';
import '../../../shared/widgets/notification_bell_button.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/session_models.dart';
import '../providers/sessions_provider.dart';
import '../widgets/session_actions_sheet.dart';
import '../widgets/session_user_card.dart';

class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authProvider).valueOrNull;
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
          'Sessions',
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
      drawer: const AppDrawer(currentPath: '/sessions'),
      body: currentUser?.isSuperAdmin != true
          ? const Center(child: Text('You do not have access to this page.'))
          : _SessionsBody(currentUserId: currentUser!.id),
    );
  }
}

class _SessionsBody extends ConsumerWidget {
  final String currentUserId;
  const _SessionsBody({required this.currentUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sessionsProvider);
    final notifier = ref.read(sessionsProvider.notifier);

    return async.when(
      loading: () => const SkeletonListCards(infoLines: 1),
      error: (e, _) => ErrorState(
        message: e.toString().replaceFirst('Exception: ', ''),
        onRetry: () => ref.invalidate(sessionsProvider),
      ),
      data: (state) {
        if (state.users.isEmpty) {
          return const EmptyState(title: 'No users found');
        }
        return RefreshIndicator(
          onRefresh: notifier.refresh,
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  itemCount: state.users.length,
                  itemBuilder: (context, i) {
                    final user = state.users[i];
                    final isSelf = user.id == currentUserId;
                    return SessionUserCard(
                      key: ValueKey(user.id),
                      user: user,
                      isSelf: isSelf,
                      onActions: () => _showActions(context, notifier, user, isSelf),
                    );
                  },
                ),
              ),
              ListPaginationBar(
                page: state.page,
                totalPages: state.totalPages,
                total: state.total,
                pageSize: state.perPage,
                itemLabel: 'users',
                onPageChange: notifier.changePage,
                onPageSizeChange: notifier.changePageSize,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showActions(
    BuildContext context,
    SessionsNotifier notifier,
    SessionUser user,
    bool isSelf,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SessionActionsSheet(
        user: user,
        isSelf: isSelf,
        onRevoke: () => notifier.revokeSessions(user.id),
        onToggleBan: () => user.isBanned ? notifier.unbanUser(user.id) : notifier.banUser(user.id),
        onResetPassword: (password) => notifier.resetPassword(userId: user.id, newPassword: password),
      ),
    );
  }
}
