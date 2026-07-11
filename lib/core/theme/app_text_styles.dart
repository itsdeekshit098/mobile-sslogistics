import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'theme_extensions.dart';

/// The handful of `TextStyle`s repeated verbatim across list screens/cards
/// (section titles, card titles, captions). Existing screens inline their
/// own `TextStyle(...)`; this isn't a retroactive sweep — adopt it going
/// forward in new/touched widgets rather than rewriting styles app-wide.
class AppTextStyles {
  static TextStyle sectionTitle(BuildContext context) => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: context.isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
      );

  static TextStyle cardTitle(BuildContext context) => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: context.isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
      );

  static TextStyle caption(BuildContext context) => TextStyle(
        fontSize: 11,
        color: context.isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
      );
}
