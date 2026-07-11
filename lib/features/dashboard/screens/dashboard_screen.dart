import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_sslogistics/core/constants/app_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/notifications/providers/notification_provider.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/app_splash.dart';
import '../widgets/dashboard_tile.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.valueOrNull;
    if (user == null) {
      return authState.isLoading ? const AppSplash() : const SizedBox.shrink();
    }

    final notificationsAsync = ref.watch(notificationListProvider);
    final unreadCount = notificationsAsync.valueOrNull?.unreadCount ?? 0;
    final notificationsLoading =
        notificationsAsync.isLoading && !notificationsAsync.hasValue;

    final roleTiles = allTiles.where((t) => t.allowedRoles.contains(user.role));
    bool isDisabled(DashboardTileData t) => t.isWebComingSoon || !t.isMobileReady;
    final visibleTiles = [
      ...roleTiles.where((t) => !isDisabled(t)),
      ...roleTiles.where(isDisabled),
    ];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkPageBg : AppColors.pageBg,
      drawer: AppDrawer(currentPath: '/dashboard'),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _DashboardHero(
              greeting: _greeting,
              user: user,
              unreadCount: unreadCount,
              notificationsLoading: notificationsLoading,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Quick Access',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate((context, index) {
                final tile = visibleTiles[index];
                return _AnimatedTileEntry(
                  index: index,
                  child: DashboardTile(
                    tile: tile,
                    onTap: () => _onTileTap(context, tile),
                  ),
                );
              }, childCount: visibleTiles.length),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onTileTap(BuildContext context, DashboardTileData tile) {
    if (!tile.isMobileReady) {
      return; // tile is already visually disabled, but guard anyway
    }
    if (tile.route != null) context.go(tile.route!);
  }
}

/// Gradient hero header with glassmorphism accents: frosted menu/avatar
/// buttons and a translucent role pill floating over a deep navy →
/// brand-blue gradient.
class _DashboardHero extends StatelessWidget {
  final String greeting;
  final AppUser user;
  final int unreadCount;
  final bool notificationsLoading;

  const _DashboardHero({
    required this.greeting,
    required this.user,
    this.unreadCount = 0,
    this.notificationsLoading = false,
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
            colors: [AppColors.sidebarBg, Color(0xFF16305C), AppColors.primary],
          ),
        ),
        child: Stack(
          children: [
            // Decorative translucent circles for depth.
            Positioned(
              top: -60,
              right: -40,
              child: _GlowCircle(size: 180, opacity: 0.10),
            ),
            Positioned(
              bottom: -50,
              left: -30,
              child: _GlowCircle(size: 140, opacity: 0.08),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Builder(
                          builder: (ctx) => _GlassIconButton(
                            icon: AppIcons.menu,
                            onTap: () => Scaffold.of(ctx).openDrawer(),
                          ),
                        ),
                        Row(
                          children: [
                            _GlassIconButton(
                              icon: AppIcons.bell,
                              badgeCount: unreadCount,
                              dimmed: notificationsLoading,
                              onTap: notificationsLoading
                                  ? null
                                  : () => context.push('/notifications'),
                            ),
                            const SizedBox(width: 10),
                            _GlassAvatar(initials: user.initials),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text(
                      greeting,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    _GlassPill(text: user.role.toString().toUpperCase()),
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

class _GlowCircle extends StatelessWidget {
  final double size;
  final double opacity;

  const _GlowCircle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final int badgeCount;
  final bool dimmed;

  const _GlassIconButton({
    required this.icon,
    this.onTap,
    this.badgeCount = 0,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedOpacity(
          opacity: dimmed ? 0.45 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: ClipRRect(
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

class _GlassAvatar extends StatelessWidget {
  final String initials;

  const _GlassAvatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white.withValues(alpha: 0.16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  final String text;

  const _GlassPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps a grid tile with a staggered fade + rise entrance animation.
class _AnimatedTileEntry extends StatelessWidget {
  final int index;
  final Widget child;

  const _AnimatedTileEntry({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final stagger = index * 45 > 400 ? 400 : index * 45;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + stagger),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 18),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
