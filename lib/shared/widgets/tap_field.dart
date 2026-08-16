import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_icons.dart';

/// Bordered, tappable pseudo-input that opens a picker or a date dialog.
///
/// Promoted from the private `_TapField` duplicated in every form sheet.
/// Matches [InputDecorationTheme]'s 8px radius so it lines up with the real
/// `TextFormField`s beside it.
///
/// Shows a clear-X when [onClear] is given, otherwise a chevron — so a field
/// that currently holds a value looks different from an empty one at a glance.
/// [hasError] paints the border red, since a tap field has no
/// `FormFieldState` to do it automatically.
class TapField extends StatelessWidget {
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  /// Renders [value] in the muted colour — for placeholder text like
  /// "Select lender".
  final bool muted;
  final bool hasError;
  final bool enabled;

  const TapField({
    super.key,
    required this.value,
    required this.icon,
    required this.onTap,
    this.onClear,
    this.muted = false,
    this.hasError = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.textMuted;
    final borderColor = hasError
        ? AppColors.error
        : (isDark ? AppColors.darkBorder : AppColors.border);

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: hasError ? 1.4 : 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, size: 15, color: mutedColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: muted
                        ? mutedColor
                        : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                  ),
                ),
              ),
              if (onClear != null && enabled)
                GestureDetector(
                  onTap: onClear,
                  child: Icon(AppIcons.x, size: 16, color: mutedColor),
                )
              else
                Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: mutedColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// Field label above a [TapField] or `TextFormField`. A label ending in ` *`
/// gets its asterisk painted red — same convention as the existing form
/// sheets' private `_Section`.
class FieldLabel extends StatelessWidget {
  final String label;

  const FieldLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final required = label.endsWith(' *');
    final text = required ? label.substring(0, label.length - 2) : label;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          text: text,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
          children: required
              ? const [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w800),
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

/// A [FieldLabel] stacked over its input, with optional inline error text.
class FormSection extends StatelessWidget {
  final String label;
  final Widget child;
  final String? errorText;

  const FormSection({
    super.key,
    required this.label,
    required this.child,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        child,
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text(
              errorText!,
              style: const TextStyle(fontSize: 11.5, color: AppColors.error),
            ),
          ),
      ],
    );
  }
}
