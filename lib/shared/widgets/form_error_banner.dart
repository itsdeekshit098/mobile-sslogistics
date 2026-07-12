import 'package:flutter/material.dart';
import 'package:mobile_sslogistics/core/constants/app_icons.dart';

import '../../core/constants/app_colors.dart';

/// Pinned above a form's scrollable body (not inside it) so it stays
/// visible no matter where the user has scrolled to, unlike the
/// field-level red borders alone.
class FormErrorBanner extends StatelessWidget {
  final int count;
  const FormErrorBanner({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: isDark ? AppColors.darkWarningBg : AppColors.warningBg,
      child: Row(
        children: [
          const Icon(AppIcons.alertTriangle, size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Text(
            count == 1 ? '1 field needs attention' : '$count fields need attention',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}
