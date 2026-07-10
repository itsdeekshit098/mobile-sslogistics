import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile_sslogistics/core/constants/app_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/notifications/providers/notification_provider.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_spinner.dart';
import '../data/external_trip_models.dart';
import '../providers/external_trip_provider.dart';
import '../widgets/delete_external_trip_dialog.dart';
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
    final unreadCount =
        ref.watch(notificationListProvider).valueOrNull?.unreadCount ?? 0;

    // API contract: admin+staff can create, only admin can edit/delete.
    final canCreate = (user?.isAdmin ?? false) || (user?.isStaff ?? false);
    final canManage = user?.isAdmin ?? false;

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
          'External Trips',
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
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
      builder: (_) => DeleteExternalTripDialog(
        trip: trip,
        onConfirm: () async {
          try {
            await ref
                .read(externalTripListProvider.notifier)
                .deleteTrip(trip.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Trip deleted'),
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

class _SummaryStrip extends StatelessWidget {
  final ExternalTripSummary summary;

  const _SummaryStrip({required this.summary});

  @override
  Widget build(BuildContext context) {
    final profitColor =
        summary.totalProfit >= 0 ? AppColors.success : AppColors.error;
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
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: 8),
          _SummaryCard(
            label: 'Received',
            value: '₹${_summaryFmt.format(summary.totalReceived)}',
            color: AppColors.textPrimary,
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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
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
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
