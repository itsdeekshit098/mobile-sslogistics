import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_sslogistics/core/constants/app_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/delete_confirmation_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_spinner.dart';
import '../../../shared/widgets/notification_bell_button.dart';
import '../../external_trips/data/external_trip_models.dart' show ExternalTripPrefill;
import '../../external_trips/widgets/external_trip_form_sheet.dart';
import '../data/trip_booking_models.dart';
import '../providers/trip_booking_provider.dart';
import '../widgets/trip_booking_card.dart';
import '../widgets/trip_booking_detail_sheet.dart';
import '../widgets/trip_booking_filter_bar.dart';
import '../widgets/trip_booking_form_sheet.dart';

class TripBookingsListScreen extends ConsumerStatefulWidget {
  const TripBookingsListScreen({super.key});

  @override
  ConsumerState<TripBookingsListScreen> createState() => _TripBookingsListScreenState();
}

class _TripBookingsListScreenState extends ConsumerState<TripBookingsListScreen> {
  bool _onScrollNotification(ScrollNotification notification) {
    // Trigger the next page well before the user hits the bottom so the
    // scroll never visibly stalls.
    if (notification.metrics.pixels > notification.metrics.maxScrollExtent - 400) {
      ref.read(tripBookingListProvider.notifier).loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull;
    final listAsync = ref.watch(tripBookingListProvider);

    // API contract: admin+staff can create/complete, only admin can edit/cancel.
    final canCreate = (user?.isAdmin ?? false) || (user?.isStaff ?? false);
    final canComplete = canCreate;
    final canManage = user?.isAdmin ?? false;

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(AppIcons.arrowLeft, color: AppColors.textPrimary),
          onPressed: () => context.go('/dashboard'),
          tooltip: 'Back',
        ),
        title: const Text(
          'Trip Bookings',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          const NotificationBellButton(color: AppColors.textPrimary),
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(AppIcons.menu, color: AppColors.textPrimary),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
              tooltip: 'Open menu',
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(currentPath: '/trip-bookings'),
      body: Column(
        children: [
          const TripBookingFilterBar(),
          Expanded(
            child: listAsync.when(
              loading: () => const LoadingSpinner(message: 'Loading bookings...'),
              error: (e, _) => ErrorState(
                message: e.toString().replaceFirst('Exception: ', ''),
                onRetry: () => ref.invalidate(tripBookingListProvider),
              ),
              data: (state) => RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () => ref.read(tripBookingListProvider.notifier).refresh(),
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScrollNotification,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      if (state.summary != null)
                        SliverToBoxAdapter(child: _SummaryStrip(summary: state.summary!)),
                      if (state.bookings.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: EmptyState(
                            title: 'No trip bookings found',
                            subtitle: state.hasFilters
                                ? 'Try adjusting your filters.'
                                : "Record a customer's advance booking so it's not forgotten.",
                            onAction: canCreate ? () => _showCreateSheet(context) : null,
                            actionLabel: canCreate ? 'New Booking' : null,
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.only(top: 4, bottom: 80),
                          sliver: SliverList.builder(
                            itemCount: state.bookings.length + (state.isLoadingMore ? 1 : 0),
                            itemBuilder: (context, i) {
                              if (i == state.bookings.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              final booking = state.bookings[i];
                              return TripBookingCard(
                                booking: booking,
                                canComplete: canComplete,
                                canManage: canManage,
                                onTap: () => _showDetailSheet(
                                  context,
                                  booking,
                                  canComplete: canComplete,
                                  canManage: canManage,
                                ),
                                onComplete: () => _showCompleteSheet(context, booking),
                                onEdit: () => _showEditSheet(context, booking),
                                onCancel: () => _showCancelDialog(context, booking),
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
              backgroundColor: AppColors.primary,
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
        child: TripBookingFormSheet(),
      ),
    );
  }

  void _showEditSheet(BuildContext context, TripBooking booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.93,
        child: TripBookingFormSheet(booking: booking),
      ),
    );
  }

  void _showDetailSheet(
    BuildContext context,
    TripBooking booking, {
    required bool canComplete,
    required bool canManage,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        child: TripBookingDetailSheet(
          booking: booking,
          canComplete: canComplete,
          canManage: canManage,
          onComplete: canComplete
              ? () {
                  Navigator.pop(context);
                  _showCompleteSheet(context, booking);
                }
              : null,
          onEdit: canManage
              ? () {
                  Navigator.pop(context);
                  _showEditSheet(context, booking);
                }
              : null,
          onCancel: canManage
              ? () {
                  Navigator.pop(context);
                  _showCancelDialog(context, booking);
                }
              : null,
        ),
      ),
    );
  }

  /// Opens the (shared) external trip creation form pre-filled from the
  /// booking, with `booking_id` wired through so the server completes the
  /// booking atomically once the trip is submitted.
  void _showCompleteSheet(BuildContext context, TripBooking booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.93,
        child: ExternalTripFormSheet(
          bookingId: booking.id,
          prefill: ExternalTripPrefill(
            customerName: booking.customerName,
            customerPhone: booking.customerPhone,
            fromLocation: booking.fromLocation,
            toLocation: booking.toLocation,
            startDate: booking.startDate,
            endDate: booking.endDate,
            vehicleId: booking.vehicleId,
            vehicleNumber: booking.vehicleNumber,
            driverId: booking.driverId,
            driverName: booking.driverName,
            driverPhone: booking.driverPhone,
            quotedAmount: booking.quotedAmount,
            advanceAmount: booking.advanceAmount,
          ),
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context, TripBooking booking) {
    showDialog(
      context: context,
      builder: (_) => DeleteConfirmationDialog(
        title: 'Cancel Booking',
        targetName: booking.customerName,
        confirmLabel: 'Cancel Booking',
        details: {
          'Route': '${booking.fromLocation} → ${booking.toLocation}',
          'Start Date': formatBookingDate(booking.startDate),
        },
        warningText: 'This action cannot be undone.',
        warningSubtext: 'The booking will be marked as cancelled.',
        onConfirm: () => ref.read(tripBookingListProvider.notifier).cancelBooking(booking.id),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  final TripBookingSummary summary;

  const _SummaryStrip({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Row(
        children: [
          _SummaryCard(label: 'Upcoming', value: '${summary.upcomingCount}', color: AppColors.primary),
          const SizedBox(width: 8),
          _SummaryCard(label: 'Overdue', value: '${summary.overdueCount}', color: AppColors.error),
          const SizedBox(width: 8),
          _SummaryCard(label: 'Completed', value: '${summary.completedCount}', color: AppColors.success),
          const SizedBox(width: 8),
          _SummaryCard(label: 'Cancelled', value: '${summary.cancelledCount}', color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({required this.label, required this.value, required this.color});

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
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
