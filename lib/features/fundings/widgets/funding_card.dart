import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../shared/utils/money_format.dart';
import '../data/funding_models.dart';

class FundingCard extends StatelessWidget {
  final Funding funding;
  final VoidCallback onTap;

  const FundingCard({super.key, required this.funding, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final computed = funding.computed;
    final interestDue = computed.interestDue > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        funding.counterpartyName != '—'
                            ? funding.counterpartyName
                            : 'Funding #${funding.id}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: funding.status == 'OPEN'
                            ? AppColors.successBg
                            : const Color(0x14000000),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        funding.status == 'OPEN' ? 'Open' : 'Settled',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: funding.status == 'OPEN' ? AppColors.success : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                if (funding.borrower != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(AppIcons.building2, size: 13,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                      const SizedBox(width: 5),
                      Text(
                        funding.borrower!.name,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Principal',
                              style: TextStyle(fontSize: 10.5,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted)),
                          Text(
                            formatRupees(computed.principalOutstanding),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(funding.direction == 'LENT' ? 'Interest Recv.' : 'Interest Due',
                            style: TextStyle(fontSize: 10.5,
                                color: interestDue
                                    ? AppColors.warning
                                    : (isDark ? AppColors.darkTextMuted : AppColors.textMuted))),
                        Text(
                          formatRupeesPrecise(computed.interestDue),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: interestDue ? AppColors.warning : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
