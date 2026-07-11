import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/notifications/providers/notification_provider.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_spinner.dart';
import '../data/vehicle_models.dart';
import '../providers/vehicles_provider.dart';
import '../../../shared/widgets/delete_confirmation_dialog.dart';
import '../widgets/vehicle_card.dart';
import '../widgets/vehicle_documents_sheet.dart';
import '../widgets/vehicle_filter_sheet.dart';
import '../widgets/vehicle_form_sheet.dart';
import '../../../shared/widgets/list_pagination_bar.dart';

class VehiclesScreen extends ConsumerStatefulWidget {
  const VehiclesScreen({super.key});

  @override
  ConsumerState<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends ConsumerState<VehiclesScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(vehiclesListProvider);
    final user = ref.watch(authProvider).valueOrNull;
    final canWrite = user?.isAdmin == true || user?.isStaff == true;
    final canDelete = user?.isAdmin == true;
    final loadedState = async.valueOrNull;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unreadCount =
        ref.watch(notificationListProvider).valueOrNull?.unreadCount ?? 0;

    return Scaffold(
      // Blue-tinted rather than neutral grey, so the page still reads as
      // part of the same gradient world as the hero above it.
      backgroundColor: isDark ? AppColors.darkPageBg : AppColors.glassPageBg,
      drawer: const AppDrawer(currentPath: '/vehicles'),
      body: Column(
        children: [
          // Glass hero: same gradient/frosted language as the dashboard and
          // drawer. Search, filter, and live fleet stats live here since
          // there's a colorful gradient behind them for the blur to read.
          _VehiclesHero(
            controller: _searchCtrl,
            onSearch: _onSearch,
            onFilter: loadedState == null
                ? null
                : () => _showFilters(loadedState),
            onClearFilters:
                ref.read(vehiclesListProvider.notifier).clearFilters,
            hasFilters: loadedState?.hasFilters ?? false,
            stats: loadedState?.stats,
            unreadCount: unreadCount,
          ),
          // The body now carries the glass language too: soft pastel blobs
          // sit fixed behind the scroll content, and the cards/pagination
          // bar above them are translucent + blurred, so they genuinely
          // frost as the list scrolls rather than sitting on flat white.
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Stack(
                    children: [
                      Positioned(
                        top: -40,
                        right: -60,
                        child: _BodyBlob(
                          size: 220,
                          color: AppColors.primary.withValues(alpha: 0.12),
                        ),
                      ),
                      Positioned(
                        top: 280,
                        left: -70,
                        child: _BodyBlob(
                          size: 200,
                          color: const Color(0xFF9333EA).withValues(alpha: 0.09),
                        ),
                      ),
                      Positioned(
                        bottom: 120,
                        right: -50,
                        child: _BodyBlob(
                          size: 190,
                          color: const Color(0xFF16A34A).withValues(alpha: 0.09),
                        ),
                      ),
                    ],
                  ),
                ),
                async.when(
                  loading: () =>
                      const LoadingSpinner(message: 'Loading vehicles...'),
                  error: (e, _) => ErrorState(
                    message: e.toString().replaceFirst('Exception: ', ''),
                    onRetry: () => ref.invalidate(vehiclesListProvider),
                  ),
                  data: (state) => Column(
                    children: [
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () => ref
                              .read(vehiclesListProvider.notifier)
                              .refresh(),
                          child: state.vehicles.isEmpty
                              ? LayoutBuilder(
                                  // Empty state must still be scrollable, otherwise
                                  // pull-to-refresh is unavailable exactly when the
                                  // user most wants to re-check for data.
                                  builder: (context, constraints) =>
                                      SingleChildScrollView(
                                        physics:
                                            const AlwaysScrollableScrollPhysics(),
                                        child: SizedBox(
                                          height: constraints.maxHeight,
                                          child: const Center(
                                            child: _GlassEmptyState(),
                                          ),
                                        ),
                                      ),
                                )
                              // Soft fade at the very top of the scroll
                              // area: a card scrolled partway off simply
                              // dissolves into the seam instead of being
                              // hard-clipped into an odd, disconnected
                              // fragment right under the hero.
                              : ShaderMask(
                                  shaderCallback: (rect) => const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.black],
                                    stops: [0.0, 0.06],
                                  ).createShader(rect),
                                  blendMode: BlendMode.dstIn,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.only(
                                      top: 6,
                                      bottom: 90,
                                    ),
                                    itemCount: state.vehicles.length,
                                    itemBuilder: (context, index) {
                                      final vehicle = state.vehicles[index];
                                      return VehicleCard(
                                        vehicle: vehicle,
                                        canWrite: canWrite,
                                        canDelete: canDelete,
                                        onTap: () => _showDetails(
                                          vehicle,
                                          canWrite,
                                          canDelete,
                                        ),
                                        onEdit: canWrite
                                            ? () => _showForm(vehicle)
                                            : null,
                                        onDelete: canDelete
                                            ? () => _delete(vehicle)
                                            : null,
                                        onDocuments: () =>
                                            _showDocuments(vehicle, canWrite),
                                      );
                                    },
                                  ),
                                ),
                        ),
                      ),
                      ListPaginationBar(
                        page: state.page,
                        totalPages: state.totalPages,
                        total: state.total,
                        pageSize: state.pageSize,
                        itemLabel: 'vehicles',
                        style: PaginationBarStyle.frosted,
                        endPadding: 86,
                        onPageChange: ref
                            .read(vehiclesListProvider.notifier)
                            .changePage,
                        onPageSizeChange: ref
                            .read(vehiclesListProvider.notifier)
                            .changePageSize,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // Hidden until the list actually loaded: if vehicles failed to load
      // (network/server down), inviting a create that will fail too is
      // misleading — the error state's Retry is the right affordance there.
      floatingActionButton: canWrite && async.hasValue
          ? _GradientFab(onPressed: () => _showForm(null))
          : null,
    );
  }

  void _onSearch(String value) {
    final query = value.trim();
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () {
        final current = ref.read(vehiclesListProvider).valueOrNull;
        if (current?.search == query) return;
        ref.read(vehiclesListProvider.notifier).search(query);
      },
    );
  }

  Future<void> _showFilters(VehiclesState state) async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => VehicleFilterSheet(
        type: state.type,
        status: state.status,
        ownerType: state.ownerType,
        ownerName: state.ownerName,
        fuelType: state.fuelType,
        fcStatus: state.fcStatus,
        insuranceStatus: state.insuranceStatus,
      ),
    );
    if (result != null) {
      ref
          .read(vehiclesListProvider.notifier)
          .applyFilters(
            state.filters.copyWith(
              type: result['type'],
              status: result['status'],
              ownerType: result['ownerType'],
              ownerName: result['ownerName'],
              fuelType: result['fuelType'],
              fcStatus: result['fcStatus'],
              insuranceStatus: result['insuranceStatus'],
            ),
          );
    }
  }

  void _showForm(FleetVehicle? vehicle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: VehicleFormSheet(
          vehicle: vehicle,
          onSubmit: (payload) async {
            final notifier = ref.read(vehiclesListProvider.notifier);
            if (vehicle == null) {
              await notifier.createVehicle(payload);
            } else {
              await notifier.updateVehicle(payload);
            }
          },
        ),
      ),
    );
  }

  void _showDocuments(FleetVehicle vehicle, bool canManage) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.88,
        child: VehicleDocumentsSheet(
          vehicle: vehicle,
          canManage: canManage,
          repository: ref.read(vehicleRepositoryProvider),
          onChanged: () => ref
              .read(vehiclesListProvider.notifier)
              .refresh(showLoading: false),
        ),
      ),
    );
  }

  void _showDetails(FleetVehicle vehicle, bool canWrite, bool canDelete) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: _VehicleDetails(
          vehicle: vehicle,
          canWrite: canWrite,
          canDelete: canDelete,
          onEdit: () {
            Navigator.pop(context);
            _showForm(vehicle);
          },
          onDelete: () {
            Navigator.pop(context);
            _delete(vehicle);
          },
          onDocuments: () {
            Navigator.pop(context);
            _showDocuments(vehicle, canWrite);
          },
        ),
      ),
    );
  }

  Future<void> _delete(FleetVehicle vehicle) async {
    // The dialog performs the delete itself: it stays open with a spinner while
    // the call runs, blocks dismissal, and shows any error inline (see
    // DeleteConfirmationDialog.onConfirm). It pops only on success.
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeleteConfirmationDialog(
        title: 'Delete Vehicle',
        targetName: vehicle.vehicleNumber.toUpperCase(),
        warningText: 'This action cannot be undone.',
        warningSubtext: 'All vehicle data will be permanently removed.',
        onConfirm: () =>
            ref.read(vehiclesListProvider.notifier).deleteVehicle(vehicle.id),
      ),
    );
  }
}

/// Gradient hero header shared visual language with the dashboard/drawer/
/// login screens: frosted menu button, glass search + filter row, and —
/// once data has loaded — a horizontal strip of frosted stat chips.
class _VehiclesHero extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  final VoidCallback? onFilter;
  final VoidCallback? onClearFilters;
  final bool hasFilters;
  final VehicleStats? stats;
  final int unreadCount;

  const _VehiclesHero({
    required this.controller,
    required this.onSearch,
    required this.onFilter,
    required this.onClearFilters,
    required this.hasFilters,
    required this.stats,
    required this.unreadCount,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.sidebarBg,
              Color(0xFF16305C),
              AppColors.primary,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -60,
              right: -40,
              child: _HeroGlow(size: 170, opacity: 0.10),
            ),
            Positioned(
              bottom: -60,
              left: -40,
              child: _HeroGlow(size: 150, opacity: 0.08),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _GlassIconButton(
                          icon: AppIcons.arrowLeft,
                          onTap: () => context.go('/dashboard'),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Vehicles',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _GlassIconButton(
                          icon: AppIcons.bell,
                          badgeCount: unreadCount,
                          onTap: () => context.push('/notifications'),
                        ),
                        const SizedBox(width: 8),
                        Builder(
                          builder: (ctx) => _GlassIconButton(
                            icon: AppIcons.menu,
                            onTap: () => Scaffold.of(ctx).openDrawer(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _GlassSearchField(
                            controller: controller,
                            onChanged: onSearch,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _GlassFilterButton(
                          onTap: onFilter,
                          onClear: onClearFilters,
                          active: hasFilters,
                        ),
                      ],
                    ),
                    if (stats != null) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 68,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _HeroStatChip(
                              label: 'Total fleet',
                              value: stats!.total,
                              dotColor: Colors.white,
                            ),
                            const SizedBox(width: 10),
                            _HeroStatChip(
                              label: 'Active',
                              value: stats!.active,
                              dotColor: const Color(0xFF4ADE80),
                            ),
                            const SizedBox(width: 10),
                            _HeroStatChip(
                              label: 'In service',
                              value: stats!.maintenance,
                              dotColor: const Color(0xFFFACC15),
                            ),
                            const SizedBox(width: 10),
                            _HeroStatChip(
                              label: 'Idle',
                              value: stats!.idle,
                              dotColor: Colors.white70,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroGlow extends StatelessWidget {
  final double size;
  final double opacity;

  const _HeroGlow({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withValues(alpha: opacity),
            Colors.white.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final int badgeCount;

  const _GlassIconButton({required this.icon, this.onTap, this.badgeCount = 0});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Material(
              color: Colors.white.withValues(alpha: 0.14),
              child: InkWell(
                onTap: onTap,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
                  ),
                  child: Icon(icon, color: Colors.white, size: 19),
                ),
              ),
            ),
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
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
    );
  }
}

class _GlassSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _GlassSearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
          ),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              return TextField(
                controller: controller,
                onChanged: onChanged,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  isDense: true,
                  filled: false,
                  hintText: 'Search vehicle number',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 20,
                  ),
                  suffixIcon: value.text.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(
                            Icons.close,
                            color: Colors.white.withValues(alpha: 0.7),
                            size: 18,
                          ),
                          onPressed: () {
                            controller.clear();
                            onChanged('');
                          },
                        ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GlassFilterButton extends StatelessWidget {
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final bool active;

  const _GlassFilterButton({
    required this.onTap,
    required this.onClear,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      // The badge is positioned outside the button's own bounds (negative
      // offsets) so it can sit half-on/half-off the corner. Clip.none stops
      // this outer Stack from cutting that overflow off; the inner ClipRRect
      // still clips the glass button itself to its rounded corners.
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Material(
              color: Colors.white.withValues(alpha: 0.12),
              child: InkWell(
                onTap: onTap,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
                  ),
                  child: const Center(
                    child: Icon(Icons.tune, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (active)
          Positioned(
            // Tap zone is 24x24 for a real touch target; centering it on
            // the same point as the 14x14 visible dot keeps the enlarged
            // hit area invisible while the badge itself sits exactly on
            // the corner, half inside the button and half outside it.
            top: -12,
            right: -12,
            child: GestureDetector(
              onTap: onClear,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox(
                width: 24,
                height: 24,
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFFACC15),
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(
                        Icons.close,
                        size: 10,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HeroStatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color dotColor;

  const _HeroStatChip({
    required this.label,
    required this.value,
    required this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 108,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$value',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Brand-gradient FAB — same treatment as the login screen's CTA button,
/// so the "primary action" affordance is consistent across the app.
class _GradientFab extends StatelessWidget {
  final VoidCallback onPressed;

  const _GradientFab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, 22),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Ink(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(AppIcons.plus, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft pastel color blob fixed behind the scrolling list — gives the
/// translucent glass cards something colorful to blur, the same way the
/// hero's gradient does for its own frosted elements.
class _BodyBlob extends StatelessWidget {
  final double size;
  final Color color;

  const _BodyBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}

class _GlassEmptyState extends StatelessWidget {
  const _GlassEmptyState();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkCardBg.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? AppColors.darkBorder.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.7),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.directions_car_outlined,
                size: 30,
                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
              ),
              const SizedBox(height: 10),
              Text(
                'No vehicles found',
                style: TextStyle(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleDetails extends StatelessWidget {
  final FleetVehicle vehicle;
  final bool canWrite;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDocuments;
  const _VehicleDetails({
    required this.vehicle,
    required this.canWrite,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
    required this.onDocuments,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
    decoration: BoxDecoration(
      color: isDark ? AppColors.darkPageBg : AppColors.pageBg,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
    ),
    child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.fromLTRB(0, 10, 0, 18),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkTextMuted : AppColors.textMuted)
                    .withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              vehicle.vehicleNumber,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 24,
                height: 1.05,
                fontWeight: FontWeight.w900,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
              children: [
          _DetailSection(
            children: [
              _Detail(
                icon: Icons.inventory_2_outlined,
                label: 'Type',
                value: vehicleTypeLabel(vehicle.vehicleType),
              ),
              _Detail.status(
                icon: AppIcons.checkCircle,
                label: 'Status',
                value: vehicle.status,
                color: _vehicleStatusColor(vehicle.status, isDark: isDark),
              ),
              _Detail(
                icon: AppIcons.user,
                label: 'Owner Type',
                value: vehicle.ownerType != null
                    ? ownerTypeLabel(vehicle.ownerType!)
                    : '-',
              ),
              _Detail(
                icon: AppIcons.user,
                label: 'Owner Name',
                value: vehicle.ownerName ?? '-',
              ),
              _Detail(
                icon: AppIcons.fuel,
                label: 'Fuel',
                value: vehicle.fuelType != null ? fuelTypeLabel(vehicle.fuelType!) : '-',
              ),
          if (vehicle.vehicleType.toUpperCase() == 'CAR' ||
              vehicle.vehicleType.toUpperCase() == 'BUS' ||
              vehicle.vehicleType.toUpperCase() == 'TEMPO_TRAVELLER')
            _Detail(
              icon: Icons.airline_seat_recline_normal,
              label: 'Seating Capacity',
              value: vehicle.seatingCapacity != null
                  ? '${vehicle.seatingCapacity}-Seater'
                  : '-',
            ),
          if (vehicle.vehicleType.toUpperCase() == 'TRUCK')
            _Detail(
              icon: AppIcons.truck,
              label: 'Truck Type',
              value: vehicle.truckType != null ? enumLabel(vehicle.truckType!) : '-',
            ),
          if (vehicle.vehicleType.toUpperCase() == 'CONTAINER') ...
            [
              _Detail(
                icon: Icons.straighten,
                label: 'Container Length',
                value: vehicle.containerLength != null
                    ? vehicle.containerLength!
                          .replaceAll('_FT', ' ft')
                          .replaceAll('_', ' ')
                    : '-',
              ),
              _Detail(
                icon: Icons.account_tree_outlined,
                label: 'Axle Type',
                value: vehicle.axleType != null
                    ? enumLabel(vehicle.axleType!)
                    : '-',
              ),
              _Detail(
                icon: Icons.inventory_2_outlined,
                label: 'Body Type',
                value: vehicle.containerBodyType != null
                    ? enumLabel(vehicle.containerBodyType!)
                    : '-',
              ),
            ],
              _Detail(
                icon: AppIcons.gauge,
                label: 'Expected KML',
                value: vehicle.expectedKml != null
                    ? '${vehicle.expectedKml} km/l'
                    : '-',
              ),
              _Detail(
                icon: AppIcons.droplets,
                label: 'Tank Capacity',
                value: vehicle.tankCapacity != null
                    ? '${vehicle.tankCapacity} L'
                    : '-',
              ),
              _Detail(
                icon: AppIcons.wrench,
                label: 'Last Service',
                value: vehicle.lastServiceDate ?? '-',
              ),
              if (vehicle.fcStartDate != null || vehicle.fcEndDate != null)
                _Detail.status(
                  icon: AppIcons.checkCircle,
                  label: 'FC Validity',
                  value:
                      '${_formatVehicleDate(vehicle.fcStartDate)} – ${_formatVehicleDate(vehicle.fcEndDate)}',
                  color: _docExpiryColor(vehicle.fcStatus, isDark: isDark),
                ),
              if (vehicle.insuranceStartDate != null ||
                  vehicle.insuranceEndDate != null)
                _Detail.status(
                  icon: AppIcons.checkCircle,
                  label: 'Insurance Validity',
                  value:
                      '${_formatVehicleDate(vehicle.insuranceStartDate)} – ${_formatVehicleDate(vehicle.insuranceEndDate)}',
                  color: _docExpiryColor(
                    vehicle.insuranceStatus,
                    isDark: isDark,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          _SheetActionButton(
            onPressed: onDocuments,
            icon: const Icon(AppIcons.fileText),
            label: 'Documents',
          ),
          if (canWrite)
            _SheetActionButton(
              onPressed: onEdit,
              icon: const Icon(AppIcons.pencil),
              label: 'Edit',
            ),
          if (canDelete)
            _SheetActionButton(
              onPressed: onDelete,
              icon: const Icon(AppIcons.trash2),
              label: 'Delete',
              destructive: true,
            ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }
}

/// Formats a YYYY-MM-DD date string as "12 Jan 2026"; '-' when absent/invalid.
String _formatVehicleDate(String? value) {
  if (value == null || value.isEmpty) return '-';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return '-';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${parsed.day.toString().padLeft(2, '0')} ${months[parsed.month - 1]} ${parsed.year}';
}

Color _docExpiryColor(String? status, {bool isDark = false}) {
  switch (status) {
    case 'expired':
      return AppColors.error;
    case 'expiring_soon':
      return AppColors.warning;
    case 'active':
      return AppColors.success;
    default:
      return isDark ? AppColors.darkTextMuted : AppColors.textMuted;
  }
}

Color _vehicleStatusColor(String status, {bool isDark = false}) {
  switch (status) {
    case 'Active':
      return AppColors.success;
    case 'Maintenance':
      return AppColors.warning;
    case 'Idle':
      return isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    default:
      return isDark ? AppColors.darkTextMuted : AppColors.textMuted;
  }
}

class _DetailSection extends StatelessWidget {
  final List<Widget> children;

  const _DetailSection({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _SheetActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget icon;
  final String label;
  final bool destructive;

  const _SheetActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(58),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        backgroundColor: destructive
            ? AppColors.error.withValues(alpha: 0.04)
            : (isDark ? AppColors.darkCardBg : Colors.white),
        foregroundColor: destructive ? AppColors.error : AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(
          color: destructive
              ? AppColors.error.withValues(alpha: 0.22)
              : AppColors.primary.withValues(alpha: 0.22),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      child: Row(
        children: [
          IconTheme(
            data: IconThemeData(
              color: destructive ? AppColors.error : AppColors.primary,
              size: 20,
            ),
            child: icon,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: destructive ? AppColors.error : AppColors.primary,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
          Icon(
            AppIcons.chevronRight,
            color: destructive ? AppColors.error : AppColors.primary,
          ),
        ],
      ),
    ),
  );
  }
}

class _Detail extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? statusColor;

  const _Detail({
    required this.icon,
    required this.label,
    required this.value,
  }) : statusColor = null;

  const _Detail.status({
    required this.icon,
    required this.label,
    required this.value,
    required Color color,
  }) : statusColor = color;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 380;
    final horizontalPadding = compact ? 14.0 : 18.0;
    final labelFontSize = compact ? 13.5 : 14.5;
    final valueFontSize = compact ? 13.5 : 14.5;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(minHeight: compact ? 62 : 68),
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ),
      ),
      child: Row(
        children: [
          // Same 38x38 tinted icon avatar used for document rows in
          // VehicleDocumentsSheet, so both sheets read as one system.
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.tileVehiclesBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          SizedBox(width: compact ? 12 : 16),
          Expanded(
            flex: 6,
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
                fontSize: labelFontSize,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          statusColor == null
              ? Expanded(
                  flex: 4,
                  child: Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: valueFontSize,
                      fontWeight: FontWeight.w900,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                )
              : _DetailStatusPill(
                  label: value,
                  color: statusColor!,
                  compact: compact,
                ),
        ],
      ),
    );
  }
}

class _DetailStatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool compact;

  const _DetailStatusPill({
    required this.label,
    required this.color,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 9 : 11,
      vertical: compact ? 7 : 8,
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 8 : 9,
          height: compact ? 8 : 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: compact ? 6 : 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: compact ? 13.5 : 14.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}
