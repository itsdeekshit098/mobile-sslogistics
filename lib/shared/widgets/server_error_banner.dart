import 'package:flutter/material.dart';
import 'package:mobile_sslogistics/core/constants/app_icons.dart';

import '../../core/constants/app_colors.dart';

/// Pinned above a form's scrollable body — used for server-rejected
/// submissions (e.g. a validation error returned by the API) inside a modal
/// bottom sheet. A SnackBar anchors to the screen underneath and renders
/// hidden behind an open modal bottom sheet, so errors from a sheet's
/// submit handler must be shown in-sheet instead.
class ServerErrorBanner extends StatelessWidget {
  final String message;
  const ServerErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: isDark ? AppColors.darkErrorBg : AppColors.errorBg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(AppIcons.alertTriangle, size: 16, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
