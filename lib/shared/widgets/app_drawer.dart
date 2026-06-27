import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_sslogistics/core/constants/app_icons.dart';

import '../../core/constants/app_colors.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../shared/models/app_user.dart';

class _NavItem {
  final String title;
  final IconData icon;
  final String path;
  final bool adminOnly;
  final bool driverHidden; // hidden entirely for driver role

  const _NavItem({
    required this.title,
    required this.icon,
    required this.path,
    this.adminOnly = false,
    this.driverHidden = false,
  });
}

const _navItems = [
  _NavItem(
    title: 'Dashboard',
    icon: AppIcons.layoutDashboard,
    path: '/dashboard',
  ),
  _NavItem(
    title: 'Diesel Records',
    icon: AppIcons.fuel,
    path: '/diesel-records',
  ),
  _NavItem(
    title: 'Vehicles',
    icon: AppIcons.truck,
    path: '/vehicles',
    driverHidden: true,
  ),
  _NavItem(
    title: 'Drivers',
    icon: AppIcons.users,
    path: '/drivers',
    driverHidden: true,
  ),
  _NavItem(
    title: 'Repair Records',
    icon: AppIcons.wrench,
    path: '/repair-records',
    driverHidden: true,
  ),
  _NavItem(
    title: 'Technicians',
    icon: AppIcons.userCog,
    path: '/technicians',
    driverHidden: true,
  ),
  _NavItem(
    title: 'External Trips',
    icon: AppIcons.navigation,
    path: '/external-trips',
    driverHidden: true,
  ),
  _NavItem(
    title: 'Activity Log',
    icon: AppIcons.activity,
    path: '/activity-log',
    driverHidden: true,
  ),
  _NavItem(
    title: 'Warranty',
    icon: AppIcons.shieldCheck,
    path: '/warranty',
    driverHidden: true,
  ),
  _NavItem(
    title: 'Sessions',
    icon: AppIcons.shield,
    path: '/sessions',
    adminOnly: true,
    driverHidden: true,
  ),
];

class AppDrawer extends ConsumerWidget {
  final String currentPath;

  const AppDrawer({super.key, required this.currentPath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;

    return Drawer(
      backgroundColor: AppColors.sidebarBg,
      width: 272,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            const Divider(color: Color(0xFF1E3A5F), height: 1),
            Expanded(child: _buildNavList(context, user)),
            const Divider(color: Color(0xFF1E3A5F), height: 1),
            _buildFooter(context, ref, user),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(AppIcons.truck, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'SS Logistics',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Operations Platform',
                style: TextStyle(color: AppColors.sidebarText, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavList(BuildContext context, AppUser? user) {
    final visibleItems = _navItems.where((item) {
      if (user == null) return false;
      if (item.adminOnly && !user.isAdmin) return false;
      if (item.driverHidden && user.isDriver) return false;
      return true;
    }).toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: visibleItems.length,
      itemBuilder: (context, i) => _NavTile(
        item: visibleItems[i],
        isActive: currentPath.startsWith(visibleItems[i].path),
        // Implemented mobile modules navigate directly; remaining modules stay locked.
        isLocked:
            visibleItems[i].path != '/dashboard' &&
            visibleItems[i].path != '/diesel-records' &&
            visibleItems[i].path != '/vehicles',
        onTap: () {
          Navigator.pop(context); // close drawer
          if (visibleItems[i].path == '/dashboard' ||
              visibleItems[i].path == '/diesel-records' ||
              visibleItems[i].path == '/vehicles') {
            context.go(visibleItems[i].path);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${visibleItems[i].title} coming soon to mobile'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildFooter(BuildContext context, WidgetRef ref, AppUser? user) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // User info
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary,
                child: Text(
                  user?.initials ?? '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.email ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      user?.role.toUpperCase() ?? '',
                      style: const TextStyle(
                        color: AppColors.sidebarText,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Sign out
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await ref.read(authProvider.notifier).logout();
              },
              icon: const Icon(
                AppIcons.logOut,
                size: 16,
                color: AppColors.sidebarText,
              ),
              label: const Text(
                'Sign out',
                style: TextStyle(color: AppColors.sidebarText),
              ),
              style: TextButton.styleFrom(alignment: Alignment.centerLeft),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final bool isLocked;
  final VoidCallback onTap;

  const _NavTile({
    required this.item,
    required this.isActive,
    required this.isLocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isActive ? AppColors.sidebarActive : Colors.transparent;
    final fgColor = isActive
        ? Colors.white
        : isLocked
        ? AppColors.sidebarTextMuted
        : AppColors.sidebarText;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(item.icon, size: 18, color: fgColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    color: fgColor,
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (isLocked)
                Icon(
                  AppIcons.lock,
                  size: 13,
                  color: AppColors.sidebarTextMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
