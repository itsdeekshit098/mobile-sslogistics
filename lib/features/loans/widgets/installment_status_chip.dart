import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../data/loan_models.dart';

/// Color for an installment/loan status — shared by the schedule tiles, the
/// EMI calendar and the loan card, so "overdue" reads as the same red
/// everywhere it appears. Mirrors the web's `installmentStatusClass`.
(Color fg, Color bg) installmentStatusColors(String status) {
  switch (status) {
    case 'PAID':
      return (AppColors.success, AppColors.successBg);
    case 'PARTIAL':
      return (AppColors.warning, AppColors.warningBg);
    case 'OVERDUE':
    case 'BOUNCED':
      return (AppColors.error, AppColors.errorBg);
    case 'WAIVED':
      return (AppColors.textMuted, const Color(0x14000000));
    case 'PENDING':
    default:
      return (AppColors.primary, const Color(0x142563EB));
  }
}

class InstallmentStatusChip extends StatelessWidget {
  final String status;

  const InstallmentStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = installmentStatusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        installmentStatusLabel(status),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class LoanStatusChip extends StatelessWidget {
  final String status;

  const LoanStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (status) {
      'ACTIVE' => (AppColors.success, AppColors.successBg),
      'CLOSED' => (AppColors.textMuted, const Color(0x14000000)),
      'FORECLOSED' => (AppColors.primary, const Color(0x142563EB)),
      'DEFAULTED' => (AppColors.error, AppColors.errorBg),
      _ => (AppColors.textMuted, const Color(0x14000000)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        loanStatusLabel(status),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
