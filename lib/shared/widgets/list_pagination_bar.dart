import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_icons.dart';

/// Simple page/pageSize control bar for list screens with server-side
/// pagination (drivers, technicians, ...). Vehicles keeps its own frosted
/// `VehiclePaginationBar` since it lives inside a glass-styled screen; this
/// is the plain-Material equivalent for AppBar-based screens.
class ListPaginationBar extends StatelessWidget {
  final int page;
  final int totalPages;
  final int total;
  final int pageSize;
  final String itemLabel;
  final ValueChanged<int> onPageChange;
  final ValueChanged<int> onPageSizeChange;

  const ListPaginationBar({
    super.key,
    required this.page,
    required this.totalPages,
    required this.total,
    required this.pageSize,
    required this.onPageChange,
    required this.onPageSizeChange,
    this.itemLabel = 'items',
  });

  @override
  Widget build(BuildContext context) {
    final isFirst = page <= 1;
    final isLast = page >= totalPages;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : Colors.white,
        border: Border(
          top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
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
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$total $itemLabel',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
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
                    color: isDark ? AppColors.darkPageBg : AppColors.pageBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                  ),
                  child: Text(
                    '$pageSize',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
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
                            : (isDark ? AppColors.darkPageBg : AppColors.pageBg),
                        foregroundColor: selected
                            ? Colors.white
                            : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
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
              : (isDark ? AppColors.darkBorder : AppColors.border).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? AppColors.primary : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
        ),
      ),
    );
  }
}
