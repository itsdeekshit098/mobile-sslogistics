import 'package:flutter/material.dart';
import 'package:mobile_sslogistics/core/constants/app_icons.dart';
import '../../../core/constants/app_colors.dart';

class DashboardTileData {
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String? route; // null = coming soon
  final bool isWebComingSoon; // greyed out — not in web yet
  final bool isMobileReady; // false = coming soon in mobile app
  final List<String> allowedRoles;

  const DashboardTileData({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    this.route,
    this.isWebComingSoon = false,
    this.isMobileReady = false,
    required this.allowedRoles,
  });
}

const allTiles = [
  DashboardTileData(
    title: 'Vehicles',
    description: 'Fleet vehicle registry and status',
    icon: AppIcons.truck,
    iconColor: AppColors.tileVehiclesIcon,
    iconBgColor: AppColors.tileVehiclesBg,
    route: '/vehicles',
    isMobileReady: true,
    allowedRoles: ['admin', 'staff', 'superadmin'],
  ),
  DashboardTileData(
    title: 'Trip Sheets',
    description: 'Daily trip logs and reports',
    icon: AppIcons.fileText,
    iconColor: AppColors.tileTripSheetsIcon,
    iconBgColor: AppColors.tileTripSheetsBg,
    isWebComingSoon: true,
    allowedRoles: ['admin', 'staff', 'superadmin'],
  ),
  DashboardTileData(
    title: 'Diesel Records',
    description: 'Fuel fill tracking and mileage analytics',
    icon: AppIcons.fuel,
    iconColor: AppColors.tileDieselIcon,
    iconBgColor: AppColors.tileDieselBg,
    route: '/diesel-records',
    isMobileReady: true,
    allowedRoles: ['admin', 'staff', 'driver', 'superadmin'],
  ),
  DashboardTileData(
    title: 'Repair Records',
    description: 'Maintenance and repair history',
    icon: AppIcons.wrench,
    iconColor: AppColors.tileRepairIcon,
    iconBgColor: AppColors.tileRepairBg,
    route: '/repair-records',
    isMobileReady: true,
    allowedRoles: ['admin', 'staff', 'superadmin'],
  ),
  DashboardTileData(
    title: 'Warranty',
    description: 'Parts and vehicle warranty tracking',
    icon: AppIcons.shieldCheck,
    iconColor: AppColors.tileWarrantyIcon,
    iconBgColor: AppColors.tileWarrantyBg,
    route: '/warranty',
    isMobileReady: true,
    // Staff excluded on web too — admin/superadmin only.
    allowedRoles: ['admin', 'superadmin'],
  ),
  DashboardTileData(
    title: 'Technicians',
    description: 'Workshop staff and specialisations',
    icon: AppIcons.userCog,
    iconColor: AppColors.tileTechIcon,
    iconBgColor: AppColors.tileTechBg,
    route: '/technicians',
    isMobileReady: true,
    allowedRoles: ['admin', 'staff', 'superadmin'],
  ),
  DashboardTileData(
    title: 'Drivers',
    description: 'Driver profiles and assignments',
    icon: AppIcons.users,
    iconColor: AppColors.tileDriversIcon,
    iconBgColor: AppColors.tileDriversBg,
    route: '/drivers',
    isMobileReady: true,
    allowedRoles: ['admin', 'staff', 'superadmin'],
  ),
  DashboardTileData(
    title: 'Vehicle Owners',
    description: 'Owner registry for the fleet',
    icon: AppIcons.badge,
    iconColor: AppColors.tileOwnersIcon,
    iconBgColor: AppColors.tileOwnersBg,
    route: '/vehicle-owners',
    isMobileReady: true,
    allowedRoles: ['admin', 'staff', 'superadmin'],
  ),
  DashboardTileData(
    title: 'External Trips',
    description: 'Third-party and outstation trips',
    icon: AppIcons.navigation,
    iconColor: AppColors.tileExternalIcon,
    iconBgColor: AppColors.tileExternalBg,
    route: '/external-trips',
    isMobileReady: true,
    allowedRoles: ['admin', 'staff', 'superadmin'],
  ),
  DashboardTileData(
    title: 'Trip Bookings',
    description: 'Advance phone bookings for external trips',
    icon: AppIcons.clock,
    iconColor: AppColors.tileBookingsIcon,
    iconBgColor: AppColors.tileBookingsBg,
    route: '/trip-bookings',
    isMobileReady: true,
    allowedRoles: ['admin', 'staff', 'superadmin'],
  ),
  DashboardTileData(
    title: 'Clients',
    description: 'Client accounts and contracts',
    icon: AppIcons.building2,
    iconColor: AppColors.tileClientsIcon,
    iconBgColor: AppColors.tileClientsBg,
    isWebComingSoon: true,
    allowedRoles: ['admin', 'staff', 'superadmin'],
  ),
  DashboardTileData(
    title: 'Reports',
    description: 'Analytics and performance reports',
    icon: AppIcons.barChart3,
    iconColor: AppColors.tileReportsIcon,
    iconBgColor: AppColors.tileReportsBg,
    isWebComingSoon: true,
    allowedRoles: ['admin', 'staff', 'superadmin'],
  ),
  DashboardTileData(
    title: 'Activity Log',
    description: 'Audit trail of all operations',
    icon: AppIcons.activity,
    iconColor: AppColors.tileActivityIcon,
    iconBgColor: AppColors.tileActivityBg,
    route: '/activity-log',
    isMobileReady: true,
    allowedRoles: ['admin', 'staff', 'superadmin'],
  ),
  DashboardTileData(
    title: 'Sessions',
    description: 'Active user session management',
    icon: AppIcons.shield,
    iconColor: AppColors.tileSessionsIcon,
    iconBgColor: AppColors.tileSessionsBg,
    route: '/sessions',
    isMobileReady: true,
    // Superadmin-exclusive on web too — even 'admin' is locked out.
    allowedRoles: ['superadmin'],
  ),
  DashboardTileData(
    title: 'Settings',
    description: 'Maintenance mode and app version control',
    icon: AppIcons.settings,
    iconColor: AppColors.tileSettingsIcon,
    iconBgColor: AppColors.tileSettingsBg,
    route: '/settings',
    isMobileReady: true,
    allowedRoles: ['superadmin'],
  ),
];

class DashboardTile extends StatelessWidget {
  final DashboardTileData tile;
  final VoidCallback onTap;

  const DashboardTile({super.key, required this.tile, required this.onTap});

  // Disabled if not in web OR not yet built for mobile
  bool get _isDisabled => tile.isWebComingSoon || !tile.isMobileReady;

  // Web-not-built vs Mobile-not-built need different badge labels
  String get _badgeLabel =>
      tile.isWebComingSoon ? 'Coming Soon' : 'Mobile Soon';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isDark ? AppColors.darkCardBg : Colors.white,
        boxShadow: _isDisabled
            ? []
            : [
                BoxShadow(
                  color: tile.iconColor.withValues(alpha: 0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
                const BoxShadow(
                  color: Color(0x0A0F172A),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
        border: Border.all(color: borderColor, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Opacity(
          opacity: _isDisabled ? 0.55 : 1.0,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isDisabled ? null : onTap,
              splashColor: tile.iconColor.withValues(alpha: 0.08),
              highlightColor: tile.iconColor.withValues(alpha: 0.04),
              child: Stack(
                children: [
                  // Accent gradient strip along the top edge.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _isDisabled ? borderColor : tile.iconColor,
                            _isDisabled
                                ? borderColor
                                : tile.iconColor.withValues(alpha: 0.25),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: _isDisabled
                                    ? null
                                    : LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          tile.iconBgColor,
                                          tile.iconBgColor.withValues(alpha: 0.55),
                                        ],
                                      ),
                                color: _isDisabled ? borderColor : null,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                tile.icon,
                                color: _isDisabled
                                    ? (isDark
                                          ? AppColors.darkTextMuted
                                          : AppColors.textMuted)
                                    : tile.iconColor,
                                size: 22,
                              ),
                            ),
                            if (_isDisabled)
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.darkPageBg
                                        : AppColors.pageBg,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        AppIcons.lock,
                                        size: 9,
                                        color: isDark
                                            ? AppColors.darkTextMuted
                                            : AppColors.textMuted,
                                      ),
                                      const SizedBox(width: 3),
                                      Flexible(
                                        child: Text(
                                          _badgeLabel,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: isDark
                                                ? AppColors.darkTextMuted
                                                : AppColors.textMuted,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: tile.iconBgColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  AppIcons.arrowRight,
                                  size: 13,
                                  color: tile.iconColor,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          tile.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _isDisabled
                                ? (isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.textMuted)
                                : (isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.textPrimary),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tile.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
