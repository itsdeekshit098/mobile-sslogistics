import 'package:flutter/material.dart';

class AppColors {
  // ── Brand / Primary ──────────────────────────────────────────────────────
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1D4ED8);

  // ── Sidebar / Drawer ──────────────────────────────────────────────────────
  static const Color sidebarBg = Color(0xFF12203D);
  static const Color sidebarActive = Color(0xFF2563EB);
  static const Color sidebarHover = Color(0xFF263762);
  static const Color sidebarText = Color(0xFFCBD5E1); // slate-300
  static const Color sidebarTextMuted = Color(0xFF64748B); // slate-500

  // ── Dashboard tile accent colors (icon / bg) ──────────────────────────────
  static const Color tileVehiclesIcon = Color(0xFF2563EB);
  static const Color tileVehiclesBg = Color(0xFFEFF6FF);

  static const Color tileDriversIcon = Color(0xFF16A34A);
  static const Color tileDriversBg = Color(0xFFF0FDF4);

  static const Color tileClientsIcon = Color(0xFF9333EA);
  static const Color tileClientsBg = Color(0xFFFAF5FF);

  static const Color tileDieselIcon = Color(0xFFEA580C);
  static const Color tileDieselBg = Color(0xFFFFF7ED);

  static const Color tileRepairIcon = Color(0xFFDC2626);
  static const Color tileRepairBg = Color(0xFFFEF2F2);

  static const Color tileTechIcon = Color(0xFF059669);
  static const Color tileTechBg = Color(0xFFECFDF5);

  static const Color tileExternalIcon = Color(0xFF0284C7);
  static const Color tileExternalBg = Color(0xFFF0F9FF);

  static const Color tileTripSheetsIcon = Color(0xFF4F46E5);
  static const Color tileTripSheetsBg = Color(0xFFEEF2FF);

  static const Color tileReportsIcon = Color(0xFF0891B2);
  static const Color tileReportsBg = Color(0xFFECFEFF);

  static const Color tileActivityIcon = Color(0xFF0D9488);
  static const Color tileActivityBg = Color(0xFFF0FDFA);

  static const Color tileWarrantyIcon = Color(0xFFE11D48);
  static const Color tileWarrantyBg = Color(0xFFFFF1F2);

  static const Color tileSessionsIcon = Color(0xFF0D9488);
  static const Color tileSessionsBg = Color(0xFFF0FDFA);

  static const Color tileOwnersIcon = Color(0xFF7C3AED);
  static const Color tileOwnersBg = Color(0xFFF5F3FF);

  static const Color tileSettingsIcon = Color(0xFF64748B);
  static const Color tileSettingsBg = Color(0xFFF1F5F9);

  // ── Semantic / Status ─────────────────────────────────────────────────────
  static const Color success = Color(0xFF16A34A);
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFCA8A04);
  static const Color warningBg = Color(0xFFFEF9C3);
  static const Color error = Color(0xFFDC2626);
  static const Color errorBg = Color(0xFFFEE2E2);

  // ── Light neutral ────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F172A);   // slate-900
  static const Color textSecondary = Color(0xFF475569); // slate-600
  static const Color textMuted = Color(0xFF94A3B8);     // slate-400
  static const Color border = Color(0xFFE2E8F0);        // slate-200
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color pageBg = Color(0xFFF8FAFC);        // slate-50

  // Subtly blue-tinted page background — used directly beneath a glass
  // gradient hero so the handoff from dark glass to light content isn't a
  // hard cut (a plain neutral grey there reads as two different apps).
  static const Color glassPageBg = Color(0xFFEEF2FA);

  // ── Dark neutral ─────────────────────────────────────────────────────────
  static const Color darkCardBg = Color(0xFF1E293B);    // slate-800
  static const Color darkPageBg = Color(0xFF0F172A);    // slate-900
  static const Color darkBorder = Color(0xFF334155);    // slate-700
  static const Color darkTextPrimary = Color(0xFFF1F5F9);   // slate-100
  static const Color darkTextSecondary = Color(0xFF94A3B8); // slate-400
  static const Color darkTextMuted = Color(0xFF64748B);     // slate-500
  static const Color darkErrorBg = Color(0xFF450A0A);       // red-950
}
