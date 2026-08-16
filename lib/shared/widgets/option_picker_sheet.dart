import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_icons.dart';

/// Picker for a short, fixed set of options — statuses, loan directions,
/// interest modes. No search box, because a list you can see all of doesn't
/// need one.
///
/// Promoted from the private `_OptionPickerSheet` duplicated across the form
/// sheets. `DropdownButtonFormField` is deliberately not used here: it ignores
/// the dark theme, which is why every form in this app rolled its own.
class OptionPickerSheet<T> extends StatelessWidget {
  final String title;
  final List<T> options;
  final T? selected;
  final String Function(T option) labelBuilder;
  final String Function(T option)? subtitleBuilder;
  final String? clearLabel;

  const OptionPickerSheet({
    super.key,
    required this.title,
    required this.options,
    required this.selected,
    required this.labelBuilder,
    this.subtitleBuilder,
    this.clearLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return Material(
      color: isDark ? AppColors.darkCardBg : Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(AppIcons.x, size: 20),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (clearLabel != null)
                    ListTile(
                      leading: Icon(AppIcons.x, color: secondaryColor),
                      title: Text(clearLabel!, style: TextStyle(color: secondaryColor)),
                      onTap: () => Navigator.pop(context, const _ClearOption()),
                    ),
                  ...options.map((option) {
                    final isSelected = option == selected;
                    final subtitle = subtitleBuilder?.call(option);
                    return ListTile(
                      title: Text(
                        labelBuilder(option),
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? AppColors.primary
                              : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                        ),
                      ),
                      subtitle: (subtitle == null || subtitle.isEmpty) ? null : Text(subtitle),
                      trailing: isSelected
                          ? const Icon(Icons.check_rounded, color: AppColors.primary)
                          : null,
                      onTap: () => Navigator.pop(context, option),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _ClearOption {
  const _ClearOption();
}

/// Opens an [OptionPickerSheet] and resolves to the chosen option, or null if
/// dismissed or cleared.
Future<T?> showOptionPicker<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required T? selected,
  required String Function(T option) labelBuilder,
  String Function(T option)? subtitleBuilder,
  String? clearLabel,
}) async {
  final result = await showModalBottomSheet<Object?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => OptionPickerSheet<T>(
      title: title,
      options: options,
      selected: selected,
      labelBuilder: labelBuilder,
      subtitleBuilder: subtitleBuilder,
      clearLabel: clearLabel,
    ),
  );

  // Both "cleared" and "dismissed" resolve to null; a caller that needs to tell
  // them apart should use SearchPickerSheet's ClearPick sentinel instead.
  if (result is _ClearOption) return null;
  return result as T?;
}
