import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_sslogistics/core/constants/app_icons.dart';

import '../../core/constants/app_colors.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../shared/models/app_user.dart';
import '../../shared/widgets/sign_out_confirmation_dialog.dart';

class _NavItem {
  final String title;
  final IconData icon;
  final String path;
  final bool adminOnly;
  final bool driverHidden; // hidden entirely for driver role
  final bool enabled; // implemented on mobile — otherwise "coming soon"

  const _NavItem({
    required this.title,
    required this.icon,
    required this.path,
    this.adminOnly = false,
    this.driverHidden = false,
    this.enabled = false,
  });
}

// Enabled (mobile-ready) modules first, remaining modules below.
const _navItems = [
  _NavItem(
    title: 'Dashboard',
    icon: AppIcons.layoutDashboard,
    path: '/dashboard',
    enabled: true,
  ),
  _NavItem(
    title: 'Diesel Records',
    icon: AppIcons.fuel,
    path: '/diesel-records',
    enabled: false,
  ),
  _NavItem(
    title: 'Vehicles',
    icon: AppIcons.truck,
    path: '/vehicles',
    driverHidden: true,
    enabled: true,
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
      backgroundColor: Colors.transparent,
      width: 272,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.sidebarBg,
                Color(0xFF16305C),
                AppColors.sidebarBg,
              ],
            ),
          ),
          child: Stack(
            children: [
              // Decorative translucent glows for the glass effect.
              Positioned(
                top: -50,
                right: -60,
                child: _Glow(size: 160, opacity: 0.08),
              ),
              Positioned(
                bottom: 120,
                left: -50,
                child: _Glow(size: 130, opacity: 0.06),
              ),
              SafeArea(
                child: Column(
                  children: [
                    _buildHeader(context),
                    _GlassDivider(),
                    Expanded(child: _buildNavList(context, user)),
                    _GlassDivider(),
                    _buildFooter(context, user),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: Image.asset('assets/images/s-logo.png', fit: BoxFit.contain),
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

    final enabledItems = visibleItems.where((i) => i.enabled).toList();
    final lockedItems = visibleItems.where((i) => !i.enabled).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 10),
      children: [
        ...enabledItems.map(
          (item) => _NavTile(
            item: item,
            isActive: currentPath.startsWith(item.path),
            isLocked: false,
            onTap: () {
              Navigator.pop(context);
              context.go(item.path);
            },
          ),
        ),
        if (lockedItems.isNotEmpty) ...[
          const SizedBox(height: 12),
          const _SectionLabel(text: 'More modules'),
          const SizedBox(height: 4),
          ...lockedItems.map(
            (item) => _NavTile(
              item: item,
              isActive: currentPath.startsWith(item.path),
              isLocked: true,
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${item.title} coming soon to mobile'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFooter(BuildContext context, AppUser? user) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.14)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.22),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        user?.initials ?? '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
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
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      SignOutConfirmationDialog.show(context);
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
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                    ),
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

class _Glow extends StatelessWidget {
  final double size;
  final double opacity;

  const _Glow({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
      ),
    );
  }
}

class _GlassDivider extends StatelessWidget {
  const _GlassDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: Colors.white.withOpacity(0.08));
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withOpacity(0.38),
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
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
    final fgColor = isActive
        ? Colors.white
        : isLocked
        ? AppColors.sidebarTextMuted
        : AppColors.sidebarText;

    final tile = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withOpacity(0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isActive
            ? Border.all(color: Colors.white.withOpacity(0.20))
            : null,
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
            Icon(AppIcons.lock, size: 13, color: AppColors.sidebarTextMuted),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: isActive
          ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(10),
                  child: tile,
                ),
              ),
            )
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: tile,
            ),
    );
  }
}
