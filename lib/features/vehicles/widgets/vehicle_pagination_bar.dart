import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';

class VehiclePaginationBar extends StatelessWidget {
  final int page;
  final int totalPages;
  final int total;
  final ValueChanged<int> onPageChange;
  final ValueChanged<int> onPageSizeChange;
  final int pageSize;

  const VehiclePaginationBar({
    super.key,
    required this.page,
    required this.totalPages,
    required this.total,
    required this.onPageChange,
    required this.onPageSizeChange,
    required this.pageSize,
  });

  @override
  Widget build(BuildContext context) {
    final isFirst = page <= 1;
    final isLast = page >= totalPages;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // The frosted background lives on the outermost Container so its color
    // extends all the way to the physical bottom edge of the screen; SafeArea
    // only insets the *content* away from the home-indicator area. Doing it
    // the other way round (SafeArea outside) leaves an undecorated gap below
    // the bar, which is what was showing as a plain strip under the pager.
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkCardBg.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.55),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? AppColors.darkBorder.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 86, 10),
              child: Row(
          children: [
            _NavButton(
              icon: AppIcons.chevronLeft,
              onTap: isFirst ? null : () => onPageChange(page - 1),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Page $page / $totalPages',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$total vehicles',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _showPageSize(context),
              child: Container(
                height: 40,
                width: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkCardBg.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder.withValues(alpha: 0.7)
                        : Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                child: Text(
                  '$pageSize',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _NavButton(
              icon: AppIcons.chevronRight,
              onTap: isLast ? null : () => onPageChange(page + 1),
            ),
          ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPageSize(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCardBg : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Row(
              children: [10, 20, 50, 100].map((size) {
                final selected = size == pageSize;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onPageSizeChange(size);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selected
                            ? AppColors.primary
                            : (isDark
                                ? AppColors.darkPageBg
                                : AppColors.pageBg),
                        foregroundColor: selected
                            ? Colors.white
                            : (isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary),
                        elevation: 0,
                      ),
                      child: Text('$size'),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _NavButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.08)
              : (isDark ? AppColors.darkBorder : AppColors.border)
                  .withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled
              ? AppColors.primary
              : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
        ),
      ),
    );
  }
}
