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
  final bool isMobileReady;   // false = coming soon in mobile app
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
    allowedRoles: ['admin', 'staff'],
  ),
  DashboardTileData(
    title: 'Drivers',
    description: 'Driver profiles and assignments',
    icon: AppIcons.users,
    iconColor: AppColors.tileDriversIcon,
    iconBgColor: AppColors.tileDriversBg,
    route: '/drivers',
    allowedRoles: ['admin', 'staff'],
  ),
  DashboardTileData(
    title: 'Clients',
    description: 'Client accounts and contracts',
    icon: AppIcons.building2,
    iconColor: AppColors.tileClientsIcon,
    iconBgColor: AppColors.tileClientsBg,
    isWebComingSoon: true,
    allowedRoles: ['admin', 'staff'],
  ),
  DashboardTileData(
    title: 'Diesel Records',
    description: 'Fuel fill tracking and mileage analytics',
    icon: AppIcons.fuel,
    iconColor: AppColors.tileDieselIcon,
    iconBgColor: AppColors.tileDieselBg,
    route: '/diesel-records',
    isMobileReady: true,  // ← only fully implemented mobile feature
    allowedRoles: ['admin', 'staff', 'driver'],
  ),
  DashboardTileData(
    title: 'Repair Records',
    description: 'Maintenance and repair history',
    icon: AppIcons.wrench,
    iconColor: AppColors.tileRepairIcon,
    iconBgColor: AppColors.tileRepairBg,
    route: '/repair-records',
    allowedRoles: ['admin', 'staff'],
  ),
  DashboardTileData(
    title: 'Technicians',
    description: 'Workshop staff and specialisations',
    icon: AppIcons.userCog,
    iconColor: AppColors.tileTechIcon,
    iconBgColor: AppColors.tileTechBg,
    route: '/technicians',
    allowedRoles: ['admin', 'staff'],
  ),
  DashboardTileData(
    title: 'External Trips',
    description: 'Third-party and outstation trips',
    icon: AppIcons.navigation,
    iconColor: AppColors.tileExternalIcon,
    iconBgColor: AppColors.tileExternalBg,
    route: '/external-trips',
    allowedRoles: ['admin', 'staff'],
  ),
  DashboardTileData(
    title: 'Trip Sheets',
    description: 'Daily trip logs and reports',
    icon: AppIcons.fileText,
    iconColor: AppColors.tileTripSheetsIcon,
    iconBgColor: AppColors.tileTripSheetsBg,
    isWebComingSoon: true,
    allowedRoles: ['admin', 'staff'],
  ),
  DashboardTileData(
    title: 'Reports',
    description: 'Analytics and performance reports',
    icon: AppIcons.barChart3,
    iconColor: AppColors.tileReportsIcon,
    iconBgColor: AppColors.tileReportsBg,
    isWebComingSoon: true,
    allowedRoles: ['admin', 'staff'],
  ),
  DashboardTileData(
    title: 'Activity Log',
    description: 'Audit trail of all operations',
    icon: AppIcons.activity,
    iconColor: AppColors.tileActivityIcon,
    iconBgColor: AppColors.tileActivityBg,
    route: '/activity-log',
    allowedRoles: ['admin', 'staff'],
  ),
  DashboardTileData(
    title: 'Warranty',
    description: 'Parts and vehicle warranty tracking',
    icon: AppIcons.shieldCheck,
    iconColor: AppColors.tileWarrantyIcon,
    iconBgColor: AppColors.tileWarrantyBg,
    route: '/warranty',
    allowedRoles: ['admin', 'staff'],
  ),
  DashboardTileData(
    title: 'Sessions',
    description: 'Active user session management',
    icon: AppIcons.shield,
    iconColor: AppColors.tileSessionsIcon,
    iconBgColor: AppColors.tileSessionsBg,
    route: '/sessions',
    allowedRoles: ['admin'],
  ),
];

class DashboardTile extends StatelessWidget {
  final DashboardTileData tile;
  final VoidCallback onTap;

  const DashboardTile({super.key, required this.tile, required this.onTap});

  // Disabled if not in web OR not yet built for mobile
  bool get _isDisabled => tile.isWebComingSoon || !tile.isMobileReady;

  // Web-not-built vs Mobile-not-built need different badge labels
  String get _badgeLabel => tile.isWebComingSoon ? 'Coming Soon' : 'Mobile Soon';

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: _isDisabled ? 0.50 : 1.0,
      child: Card(
        elevation: _isDisabled ? 0 : 2,
        shadowColor: Colors.black26,
        surfaceTintColor: Colors.transparent,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: _isDisabled ? AppColors.border : AppColors.border,
            width: 0.8,
          ),
        ),
        child: InkWell(
          onTap: _isDisabled ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                        color: _isDisabled
                            ? AppColors.border
                            : tile.iconBgColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        tile.icon,
                        color: _isDisabled
                            ? AppColors.textMuted
                            : tile.iconColor,
                        size: 22,
                      ),
                    ),
                    if (_isDisabled)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.pageBg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          _badgeLabel,
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      Icon(
                        AppIcons.arrowRight,
                        size: 16,
                        color: tile.iconColor,
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
                        ? AppColors.textMuted
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tile.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
