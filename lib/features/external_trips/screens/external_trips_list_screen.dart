import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile_sslogistics/core/constants/app_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/delete_confirmation_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_spinner.dart';
import '../../../shared/widgets/notification_bell_button.dart';
import '../data/external_trip_models.dart';
import '../providers/external_trip_provider.dart';
import '../widgets/external_trip_card.dart';
import '../widgets/external_trip_detail_sheet.dart';
import '../widgets/external_trip_filter_bar.dart';
import '../widgets/external_trip_form_sheet.dart';

final _summaryFmt = NumberFormat('#,##0', 'en_IN');

class ExternalTripsListScreen extends ConsumerStatefulWidget {
  /// Pre-filters by vehicle when arriving from a deep link.
  final int? initialVehicleId;

  const ExternalTripsListScreen({super.key, this.initialVehicleId});

  @override
  ConsumerState<ExternalTripsListScreen> createState() =>
      _ExternalTripsListScreenState();
}

class _ExternalTripsListScreenState
    extends ConsumerState<ExternalTripsListScreen> {
  @override
  void initState() {
    super.initState();
    final vehicleId = widget.initialVehicleId;
    if (vehicleId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(externalTripListProvider.notifier)
            .applyFilters(vehicleId: vehicleId);
      });
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    // Trigger the next page well before the user hits the bottom so the
    // scroll never visibly stalls.
    if (notification.metrics.pixels >
        notification.metrics.maxScrollExtent - 400) {
      ref.read(externalTripListProvider.notifier).loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull;
    final listAsync = ref.watch(externalTripListProvider);

    // API contract: admin+staff can create, only admin can edit/delete.
    final canCreate = (user?.isAdmin ?? false) || (user?.isStaff ?? false);
    final canManage = user?.isAdmin ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkPageBg : AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkCardBg : Colors.white,
        elevation: 0,
        surfaceTintColor: isDark ? AppColors.darkCardBg : Colors.white,
        leading: IconButton(
          icon: Icon(
            AppIcons.arrowLeft,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
          onPressed: () => context.go('/dashboard'),
          tooltip: 'Back',
        ),
        title: Text(
          'External Trips',
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
              icon: Icon(
                AppIcons.menu,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
              tooltip: 'Open menu',
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(currentPath: '/external-trips'),
      body: Column(
        children: [
          const ExternalTripFilterBar(),
          Expanded(
            child: listAsync.when(
              loading: () => const LoadingSpinner(message: 'Loading trips...'),
              error: (e, _) => ErrorState(
                message: e.toString().replaceFirst('Exception: ', ''),
                onRetry: () => ref.invalidate(externalTripListProvider),
              ),
              data: (state) => RefreshIndicator(
                color: AppColors.tileExternalIcon,
                onRefresh: () =>
                    ref.read(externalTripListProvider.notifier).refresh(),
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScrollNotification,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      if (state.summary != null)
                        SliverToBoxAdapter(
                          child: _SummaryStrip(summary: state.summary!),
                        ),
                      if (state.trips.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: EmptyState(
                            title: 'No external trips',
                            subtitle: state.hasFilters
                                ? 'No trips match the current filters.'
                                : 'Trips you record will show up here.',
                            onAction: canCreate
                                ? () => _showCreateSheet(context)
                                : null,
                            actionLabel: canCreate ? 'New Trip' : null,
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.only(top: 4, bottom: 80),
                          sliver: SliverList.builder(
                            itemCount: state.trips.length +
                                (state.isLoadingMore ? 1 : 0),
                            itemBuilder: (context, i) {
                              if (i == state.trips.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: AppColors.tileExternalIcon,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              final trip = state.trips[i];
                              return ExternalTripCard(
                                trip: trip,
                                canManage: canManage,
                                onTap: () => _showDetailSheet(
                                  context,
                                  trip,
                                  canManage: canManage,
                                ),
                                onEdit: () => _showEditSheet(context, trip),
                                onDelete: () =>
                                    _showDeleteDialog(context, trip),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              onPressed: () => _showCreateSheet(context),
              backgroundColor: AppColors.tileExternalIcon,
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
        child: ExternalTripFormSheet(),
      ),
    );
  }

  void _showEditSheet(BuildContext context, ExternalTrip trip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.93,
        child: ExternalTripFormSheet(trip: trip),
      ),
    );
  }

  void _showDetailSheet(
    BuildContext context,
    ExternalTrip trip, {
    required bool canManage,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        child: ExternalTripDetailSheet(
          trip: trip,
          canManage: canManage,
          onEdit: canManage
              ? () {
                  Navigator.pop(context);
                  _showEditSheet(context, trip);
                }
              : null,
          onDelete: canManage
              ? () {
                  Navigator.pop(context);
                  _showDeleteDialog(context, trip);
                }
              : null,
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, ExternalTrip trip) {
    showDialog(
      context: context,
      builder: (_) => DeleteConfirmationDialog(
        title: 'Delete Trip',
        targetName: '${trip.vehicleNumber} - ${formatTripDate(trip.startDate)}',
        details: {
          'Vehicle': trip.vehicleNumber,
          'Type': trip.tripTypeLabel,
          'Date': formatTripDate(trip.startDate),
          'Received': formatMoney(trip.amountReceived),
        },
        warningText: 'This action cannot be undone.',
        warningSubtext: 'The trip record will be permanently removed.',
        onConfirm: () =>
            ref.read(externalTripListProvider.notifier).deleteTrip(trip.id),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  final ExternalTripSummary summary;

  const _SummaryStrip({required this.summary});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profitColor =
        summary.totalProfit >= 0 ? AppColors.success : AppColors.error;
    final primaryColor =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Row(
        children: [
          _SummaryCard(
            label: 'Trips',
            value: '${summary.count}',
            color: AppColors.tileExternalIcon,
          ),
          const SizedBox(width: 8),
          _SummaryCard(
            label: 'Cost',
            value: '₹${_summaryFmt.format(summary.totalCost)}',
            color: primaryColor,
          ),
          const SizedBox(width: 8),
          _SummaryCard(
            label: 'Received',
            value: '₹${_summaryFmt.format(summary.totalReceived)}',
            color: primaryColor,
          ),
          const SizedBox(width: 8),
          _SummaryCard(
            label: 'Profit',
            value:
                '${summary.totalProfit >= 0 ? '+' : '−'}₹${_summaryFmt.format(summary.totalProfit.abs())}',
            color: profitColor,
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCardBg : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
