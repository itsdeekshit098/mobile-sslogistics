import 'package:flutter/material.dart';
import 'package:mobile_sslogistics/core/constants/app_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/diesel_provider.dart';

class DieselPaginationBar extends StatelessWidget {
  final DieselListState state;
  final void Function(int page) onPageChange;

  const DieselPaginationBar({
    super.key,
    required this.state,
    required this.onPageChange,
  });

  @override
  Widget build(BuildContext context) {
    final isFirst = state.page <= 1;
    final isLast = state.page >= state.totalPages;

    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 8, 96, 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.pageBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              _PaginationBtn(
                icon: AppIcons.chevronLeft,
                onTap: isFirst ? null : () => onPageChange(state.page - 1),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Page ${state.page} / ${state.totalPages}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${state.total} records',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 7),
                    _PageProgress(
                      page: state.page,
                      totalPages: state.totalPages,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _PaginationBtn(
                icon: AppIcons.chevronRight,
                onTap: isLast ? null : () => onPageChange(state.page + 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageProgress extends StatelessWidget {
  final int page;
  final int totalPages;

  const _PageProgress({required this.page, required this.totalPages});

  @override
  Widget build(BuildContext context) {
    final factor = totalPages <= 1 ? 1.0 : page / totalPages;
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        minHeight: 4,
        value: factor.clamp(0.0, 1.0),
        backgroundColor: AppColors.border,
        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
      ),
    );
  }
}

class _PaginationBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _PaginationBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: enabled
              ? Colors.white
              : AppColors.border.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled
                ? AppColors.primary.withValues(alpha: 0.35)
                : AppColors.border,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? AppColors.primary : AppColors.textMuted,
        ),
      ),
    );
  }
}
