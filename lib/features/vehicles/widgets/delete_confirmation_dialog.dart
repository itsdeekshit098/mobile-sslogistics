import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';

class DeleteConfirmationDialog extends StatelessWidget {
  final String title;
  final String targetName;
  final String warningText;
  final String warningSubtext;
  final String confirmLabel;

  const DeleteConfirmationDialog({
    super.key,
    required this.title,
    required this.targetName,
    required this.warningText,
    required this.warningSubtext,
    this.confirmLabel = 'Delete',
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dialogWidth = (size.width - 44).clamp(280.0, 360.0);
    final compact = size.width < 380;
    final veryCompact = size.width < 340;
    final horizontalPadding = compact ? 18.0 : 22.0;
    final iconOuterSize = veryCompact ? 66.0 : compact ? 72.0 : 78.0;
    final iconInnerSize = veryCompact ? 50.0 : compact ? 54.0 : 58.0;
    final titleSize = veryCompact ? 22.0 : compact ? 24.0 : 26.0;
    final bodySize = veryCompact ? 13.5 : compact ? 14.5 : 15.5;
    final warningSize = veryCompact ? 12.5 : compact ? 13.0 : 13.5;
    final buttonHeight = veryCompact ? 48.0 : 52.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 22,
        vertical: 22,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            compact ? 20 : 22,
            horizontalPadding,
            compact ? 18 : 22,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCardBg : Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: iconOuterSize,
                height: iconOuterSize,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.07),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: iconInnerSize,
                    height: iconInnerSize,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.13),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      AppIcons.trash2,
                      color: AppColors.error,
                      size: 29,
                    ),
                  ),
                ),
              ),
              SizedBox(height: compact ? 16 : 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                  fontSize: titleSize,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                    fontSize: bodySize,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    const TextSpan(text: 'Are you sure you want to delete\n'),
                    TextSpan(
                      text: targetName,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const TextSpan(text: '?'),
                  ],
                ),
              ),
              SizedBox(height: compact ? 16 : 18),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 12 : 14,
                  vertical: compact ? 12 : 13,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCardBg : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.14),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.primary,
                      size: compact ? 24 : 26,
                    ),
                    SizedBox(width: compact ? 10 : 12),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: warningText),
                            TextSpan(text: '\n$warningSubtext'),
                          ],
                        ),
                        style: TextStyle(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                          fontSize: warningSize,
                          height: 1.34,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: compact ? 16 : 18),
              compact
                  ? _StackedActions(
                      confirmLabel: confirmLabel,
                      buttonHeight: buttonHeight,
                    )
                  : _InlineActions(
                      confirmLabel: confirmLabel,
                      buttonHeight: buttonHeight,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineActions extends StatelessWidget {
  final String confirmLabel;
  final double buttonHeight;

  const _InlineActions({required this.confirmLabel, required this.buttonHeight});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: _CancelButton(height: buttonHeight)),
      const SizedBox(width: 12),
      Expanded(child: _DeleteButton(confirmLabel: confirmLabel, height: buttonHeight)),
    ],
  );
}

class _StackedActions extends StatelessWidget {
  final String confirmLabel;
  final double buttonHeight;

  const _StackedActions({required this.confirmLabel, required this.buttonHeight});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _DeleteButton(confirmLabel: confirmLabel, height: buttonHeight),
      const SizedBox(height: 10),
      _CancelButton(height: buttonHeight),
    ],
  );
}

class _CancelButton extends StatelessWidget {
  final double height;

  const _CancelButton({required this.height});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return OutlinedButton(
      onPressed: () => Navigator.pop(context, false),
      style: OutlinedButton.styleFrom(
        minimumSize: Size.fromHeight(height),
        foregroundColor:
            isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
        textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
      ),
      child: const Text('Cancel'),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  final String confirmLabel;
  final double height;

  const _DeleteButton({required this.confirmLabel, required this.height});

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    onPressed: () => Navigator.pop(context, true),
    icon: const Icon(AppIcons.trash2, size: 18),
    label: Text(confirmLabel),
    style: ElevatedButton.styleFrom(
      minimumSize: Size.fromHeight(height),
      backgroundColor: AppColors.error,
      foregroundColor: Colors.white,
      elevation: 8,
      shadowColor: AppColors.error.withValues(alpha: 0.22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
    ),
  );
}
