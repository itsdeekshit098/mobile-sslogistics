import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// One labelled line inside a [DetailSectionCard]. A null [label] spans the
/// full width — for a note or an address that reads better without a gutter.
class DetailRowData {
  final String? label;
  final String value;
  final Color? valueColor;
  final bool strikethrough;

  const DetailRowData(
    this.label,
    this.value, {
    this.valueColor,
    this.strikethrough = false,
  });
}

/// Titled block of label/value rows — the summary card on a detail screen.
///
/// Promoted from the private `_DetailGroup` in `trip_booking_detail_sheet.dart`,
/// which the three finance detail screens would otherwise each re-declare.
class DetailSectionCard extends StatelessWidget {
  final String title;
  final List<DetailRowData> rows;

  /// Optional action in the header, e.g. an Edit button.
  final Widget? trailing;

  const DetailSectionCard({
    super.key,
    required this.title,
    required this.rows,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkPageBg : AppColors.pageBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          ...rows.map(
            (r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (r.label != null)
                    SizedBox(
                      width: 110,
                      child: Text(
                        r.label!,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      r.value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        decoration: r.strikethrough ? TextDecoration.lineThrough : null,
                        color: r.valueColor ??
                            (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
